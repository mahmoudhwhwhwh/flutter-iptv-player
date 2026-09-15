export interface Env {
  DB: D1Database;
  ADMIN_SECRET: string;
}

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};

function json(data: any, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json', ...corsHeaders },
  });
}

function error(message: string, status = 400) {
  return json({ ok: false, error: message }, status);
}

// Simple authentication middleware
async function isAdmin(request: Request, env: Env): Promise<boolean> {
  const authHeader = request.headers.get('Authorization');
  if (!authHeader) return false;
  const token = authHeader.replace('Bearer ', '');
  return token === env.ADMIN_SECRET;
}

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    const url = new URL(request.url);
    const path = url.pathname;

    try {
      // ----------------------------------------------------
      // PUBLIC USER API (Flutter App)
      // ----------------------------------------------------

      // 1. App Configuration (Sliders, Version, Global Settings)
      if (path === '/v1/config' && request.method === 'GET') {
        const { results } = await env.DB.prepare("SELECT key, value FROM app_config").all();
        const config: Record<string, any> = {
          app_name: "LIVE STREAM PRO",
          version: "2.3.0",
        };
        for (const row of results) {
          try {
            config[row.key] = JSON.parse(row.value as string);
          } catch {
            config[row.key] = row.value;
          }
        }
        return json({ ok: true, data: config });
      }

      // 2. Client Authentication / Subscription Check
      if (path === '/v1/auth' && request.method === 'POST') {
        const body: any = await request.json();
        const { code, device_id, device_name } = body;

        if (!code || !device_id) return error("Missing code or device_id");

        // Simple hash check or direct match depending on implementation
        // For security, code should be hashed on client, but we allow plain for simplicity if requested
        const stmt = env.DB.prepare(`
          SELECT * FROM subscriptions 
          WHERE subscription_code = ? OR code_hash = ?
          LIMIT 1
        `);
        const sub: any = await stmt.bind(code, code).first();

        if (!sub) return error("Invalid subscription code", 401);

        // Check Status
        if (sub.status === 'suspended') return error("Subscription suspended", 403);
        if (sub.status === 'revoked') return error("Subscription revoked", 403);
        
        // Check Expiry
        const now = new Date();
        const expiry = new Date(sub.expires_at);
        if (now > expiry) {
          // Auto update status if expired
          await env.DB.prepare("UPDATE subscriptions SET status = 'expired' WHERE id = ?").bind(sub.id).run();
          return error("Subscription expired", 403);
        }

        // Device Binding Logic
        const { results: devices } = await env.DB.prepare("SELECT * FROM devices WHERE subscription_id = ?").bind(sub.id).all();
        const isKnownDevice = devices.some((d: any) => d.device_id === device_id);

        if (!isKnownDevice) {
          if (devices.length >= sub.max_devices) {
            return error("Device limit reached", 403);
          }
          // Register new device
          await env.DB.prepare(`
            INSERT INTO devices (subscription_id, device_id, device_name, ip_address) 
            VALUES (?, ?, ?, ?)
          `).bind(sub.id, device_id, device_name || 'Unknown', request.headers.get('CF-Connecting-IP') || '').run();
        } else {
          // Update last seen
          await env.DB.prepare("UPDATE devices SET last_seen = CURRENT_TIMESTAMP WHERE subscription_id = ? AND device_id = ?").bind(sub.id, device_id).run();
        }

        // Return connection details securely
        return json({
          ok: true,
          data: {
            username: sub.username,
            status: sub.status,
            expires_at: sub.expires_at,
            plan_name: sub.plan_name,
            server_type: sub.server_type,
            host: sub.host,
            iptv_username: sub.username_iptv,
            iptv_password: sub.password_iptv,
            features: sub.features ? JSON.parse(sub.features) : null,
          }
        });
      }


      // ----------------------------------------------------
      // ADMIN API
      // ----------------------------------------------------
      if (path.startsWith('/admin/')) {
        if (!await isAdmin(request, env)) {
          return error("Unauthorized", 401);
        }

        // --- DASHBOARD STATS ---
        if (path === '/admin/stats' && request.method === 'GET') {
          const stats = {
            total_subs: (await env.DB.prepare("SELECT COUNT(*) as c FROM subscriptions").first())?.c,
            active: (await env.DB.prepare("SELECT COUNT(*) as c FROM subscriptions WHERE status='active'").first())?.c,
            expired: (await env.DB.prepare("SELECT COUNT(*) as c FROM subscriptions WHERE status='expired'").first())?.c,
            suspended: (await env.DB.prepare("SELECT COUNT(*) as c FROM subscriptions WHERE status='suspended'").first())?.c,
            total_devices: (await env.DB.prepare("SELECT COUNT(*) as c FROM devices").first())?.c,
          };
          return json({ ok: true, data: stats });
        }

        // --- SUBSCRIPTIONS CRUD ---
        if (path === '/admin/subscriptions' && request.method === 'GET') {
          const { results } = await env.DB.prepare("SELECT id, username, subscription_code, plan_name, status, expires_at, created_at, max_devices FROM subscriptions ORDER BY created_at DESC").all();
          return json({ ok: true, data: results });
        }

        if (path === '/admin/subscriptions' && request.method === 'POST') {
          const body: any = await request.json();
          // Calculate expiry server-side
          const now = new Date();
          const expiry = new Date(now.getTime() + (body.duration_days * 24 * 60 * 60 * 1000));
          
          await env.DB.prepare(`
            INSERT INTO subscriptions (username, subscription_code, server_type, host, username_iptv, password_iptv, expires_at, max_devices, plan_name)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
          `).bind(
            body.username, body.code, body.server_type, body.host, body.username_iptv, body.password_iptv, expiry.toISOString(), body.max_devices || 1, body.plan_name
          ).run();

          await env.DB.prepare("INSERT INTO admin_logs (admin_user, action, target) VALUES (?, ?, ?)").bind('admin', 'CREATE_SUBSCRIPTION', body.username).run();
          
          return json({ ok: true, message: "Subscription created" });
        }

        // EXTEND/MODIFY
        if (path.match(/^\/admin\/subscriptions\/\d+$/) && request.method === 'PUT') {
          const id = path.split('/').pop();
          const body: any = await request.json();
          
          let updateQuery = "UPDATE subscriptions SET ";
          const params = [];
          
          if (body.add_days) {
            // Complex SQLite date math or do it in JS
            const current: any = await env.DB.prepare("SELECT expires_at FROM subscriptions WHERE id = ?").bind(id).first();
            const newExpiry = new Date(new Date(current.expires_at).getTime() + (body.add_days * 24 * 60 * 60 * 1000));
            updateQuery += "expires_at = ?, ";
            params.push(newExpiry.toISOString());
          }
          
          if (body.status) {
            updateQuery += "status = ?, ";
            params.push(body.status);
          }

          updateQuery = updateQuery.slice(0, -2) + " WHERE id = ?";
          params.push(id);
          
          await env.DB.prepare(updateQuery).bind(...params).run();
          await env.DB.prepare("INSERT INTO admin_logs (admin_user, action, target) VALUES (?, ?, ?)").bind('admin', 'UPDATE_SUBSCRIPTION', id).run();
          
          return json({ ok: true });
        }

        // RESET DEVICES
        if (path.match(/^\/admin\/subscriptions\/\d+\/reset-devices$/) && request.method === 'POST') {
          const id = path.split('/')[3];
          await env.DB.prepare("DELETE FROM devices WHERE subscription_id = ?").bind(id).run();
          await env.DB.prepare("INSERT INTO admin_logs (admin_user, action, target) VALUES (?, ?, ?)").bind('admin', 'RESET_DEVICES', id).run();
          return json({ ok: true, message: "Devices reset successfully" });
        }
      }

      return error("Not found", 404);

    } catch (e: any) {
      return error(e.message, 500);
    }
  },
};
