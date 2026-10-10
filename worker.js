const cors = {
  "Content-Type": "application/json; charset=utf-8",
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PATCH, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Admin-Token",
};

const securityHeaders = {
  "Cache-Control": "no-store",
  "X-Content-Type-Options": "nosniff",
  "X-Frame-Options": "DENY",
  "Referrer-Policy": "no-referrer",
  "Permissions-Policy": "camera=(), microphone=(), geolocation=()",
};
const respond = (body, status = 200, extraHeaders = {}) => new Response(JSON.stringify(body), {
  status,
  headers: { ...cors, ...securityHeaders, ...extraHeaders },
});

async function sha256(value) {
  const data = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest("SHA-256", data);
  return [...new Uint8Array(digest)].map(byte => byte.toString(16).padStart(2, "0")).join("");
}

async function adminOk(request, env) {
  const token = request.headers.get("Authorization")?.replace(/^Bearer\s+/i, "") ||
    request.headers.get("X-Admin-Token") || "";
  if (!token) return false;
  if (env.ADMIN_TOKEN) return token === env.ADMIN_TOKEN;
  return (await sha256(token)) === "708fc596de7dd824d23a7e36712ebfa3dd3f44079c013d5ffffbf48532b34f39";
}

const adminHtml = `<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>إدارة الاشتراكات</title><style>body{font-family:Arial;background:#08101f;color:#eef;padding:20px;max-width:1050px;margin:auto}.card{background:#111c32;border:1px solid #304364;border-radius:14px;padding:16px;margin:12px 0}input,select,button{padding:10px;margin:4px;border-radius:8px;border:1px solid #405579;background:#0b1426;color:#fff}button{background:#2563eb;cursor:pointer}.danger{background:#991b1b}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(180px,1fr))}.row{border-top:1px solid #304364;padding:12px 0;display:flex;justify-content:space-between;gap:8px;flex-wrap:wrap}.muted{color:#aab8d6}</style><h1>إدارة الاشتراكات</h1><p class="muted">أي اشتراك تضيفه هنا يعمل داخل التطبيق بدون إصدار جديد.</p><div class="card"><input id="t" type="password" placeholder="رمز الإدارة"><button onclick="login()">دخول</button><b id="m"></b></div><div id="app" hidden><div class="card"><h2>إضافة / تعديل</h2><div class="grid"><input id="c" placeholder="رمز التفعيل"><select id="y"><option value="xtream">Xtream</option><option value="stalker">MAC / Stalker</option></select><select id="z"><option value="all">كل المحتوى</option><option value="iptv">IPTV</option></select><input id="h" placeholder="رابط السيرفر"><input id="u" placeholder="المستخدم أو MAC"><input id="p" placeholder="كلمة المرور"><input id="e" type="datetime-local" placeholder="الانتهاء"><input id="d" type="number" min="1" value="1" placeholder="الأجهزة"></div><button onclick="save()">حفظ</button><button onclick="clr()">تفريغ</button></div><div class="card"><h2>الاشتراكات</h2><div id="l"></div></div></div><script>const $=x=>document.getElementById(x),H=()=>({Authorization:'Bearer '+$('t').value,'Content-Type':'application/json'}),A=async(u,o={})=>{o.headers=H();let r=await fetch(u,o),j=await r.json();if(!r.ok)throw Error(j.message||'فشل الطلب');return j};async function login(){try{$('app').hidden=false;draw(await A('/admin/api/subscriptions'));$('m').textContent=' تم الدخول'}catch(e){$('m').textContent=' '+e.message}}async function draw(j){$('l').innerHTML=(j.items||[]).map(x=>'<div class="row"><span><b>'+x.code_masked+'</b> · '+x.server_type+' · '+(x.expires_at||'بدون انتهاء')+'<br><small>'+x.host+'</small></span><span><button onclick="ed('+JSON.stringify(x).replace(/"/g,'&quot;')+')">تعديل</button><button class="danger" onclick="del(\''+x.id+'\')">حذف</button></span></div>').join('')||'لا توجد اشتراكات'}function ed(x){$('c').value=x.code||'';$('y').value=x.server_type;$('z').value=x.content_mode;$('h').value=x.host||'';$('u').value=x.username||'';$('p').value='';$('e').value=x.expires_at?x.expires_at.slice(0,16):'';$('d').value=x.max_devices||1}async function save(){try{await A('/admin/api/subscriptions',{method:'POST',body:JSON.stringify({code:$('c').value,server_type:$('y').value,content_mode:$('z').value,host:$('h').value,username:$('u').value,password:$('p').value,expires_at:$('e').value?new Date($('e').value).toISOString():null,max_devices:+$('d').value||1})});draw(await A('/admin/api/subscriptions'));$('m').textContent=' تم الحفظ'}catch(e){$('m').textContent=' '+e.message}}async function del(id){if(confirm('حذف الاشتراك؟')){await A('/admin/api/subscriptions/'+id,{method:'DELETE'});draw(await A('/admin/api/subscriptions'))}}function clr(){['c','h','u','p','e'].forEach(x=>$(x).value='')}</script>`;

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (request.method === "OPTIONS") return new Response(null, { headers: cors });
    if (!env.DB) return respond({ ok: false, message: "Database binding missing" }, 503);
    try {
      await env.DB.prepare(`CREATE TABLE IF NOT EXISTS subscriptions (
        code_hash TEXT PRIMARY KEY,
        server_type TEXT NOT NULL DEFAULT 'xtream',
        content_mode TEXT NOT NULL DEFAULT 'all',
        host TEXT NOT NULL,
        username TEXT NOT NULL,
        password TEXT NOT NULL DEFAULT '',
        expires_at TEXT,
        max_devices INTEGER NOT NULL DEFAULT 1,
        is_blocked INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      );`).run();
      try { await env.DB.prepare("ALTER TABLE subscriptions ADD COLUMN code_tail TEXT").run(); } catch (_) {}
      await env.DB.prepare(`CREATE TABLE IF NOT EXISTS service_meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);`).run();
      await env.DB.prepare(`CREATE TABLE IF NOT EXISTS login_attempts (
        identity_hash TEXT PRIMARY KEY,
        window_started_at INTEGER NOT NULL,
        attempts INTEGER NOT NULL DEFAULT 0
      );`).run();
      await env.DB.prepare(`CREATE TABLE IF NOT EXISTS login_ip_attempts (
        ip_hash TEXT PRIMARY KEY,
        window_started_at INTEGER NOT NULL,
        attempts INTEGER NOT NULL DEFAULT 0
      );`).run();
      await env.DB.prepare(`CREATE TABLE IF NOT EXISTS devices (
        code_hash TEXT NOT NULL,
        device_id TEXT NOT NULL,
        last_seen_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY(code_hash, device_id)
      );`).run();

      if (url.pathname === "/admin") {
        return new Response(adminHtml, { headers: { "Content-Type": "text/html; charset=utf-8", ...securityHeaders } });
      }
      if (url.pathname.startsWith("/admin/api/")) {
        if (!await adminOk(request, env)) return respond({ ok: false, message: "رمز لوحة الإدارة غير صحيح" }, 401);
        if (url.pathname === "/admin/api/subscriptions" && request.method === "GET") {
          const rows = await env.DB.prepare("SELECT code_hash, code_tail, server_type, content_mode, host, username, expires_at, max_devices, is_blocked, updated_at FROM subscriptions ORDER BY updated_at DESC").all();
          return respond({ ok: true, items: (rows.results || []).map(row => ({
            id: row.code_hash,
            code_masked: `••••${row.code_tail || String(row.code_hash).slice(-4)}`,
            server_type: row.server_type, content_mode: row.content_mode, host: row.host,
            username: row.username, expires_at: row.expires_at, max_devices: row.max_devices,
            is_blocked: Boolean(row.is_blocked), updated_at: row.updated_at
          })) });
        }
        if (url.pathname === "/admin/api/subscriptions" && request.method === "POST") {
          const length = Number(request.headers.get("Content-Length") || 0);
          if (length > 16 * 1024) return respond({ ok: false, message: "الطلب كبير جداً" }, 413);
          const body = await request.json();
          const code = String(body.code || "").trim();
          const type = String(body.server_type || "xtream").toLowerCase() === "stalker" ? "stalker" : "xtream";
          const host = String(body.host || "").trim().replace(/\/+$/, "");
          const username = String(body.username || "").trim();
          if (code.length > 128 || host.length > 512 || username.length > 256) {
            return respond({ ok: false, message: "بيانات الاشتراك غير صالحة" }, 400);
          }
          if (!code || !host || !username) return respond({ ok: false, message: "الرمز والرابط وبيانات الدخول مطلوبة" }, 400);
          const codeHash = await sha256(code);
          const old = await env.DB.prepare("SELECT password FROM subscriptions WHERE code_hash = ?").bind(codeHash).first();
          const password = String(body.password || old?.password || "");
          await env.DB.prepare(`INSERT INTO subscriptions
            (code_hash, code_tail, server_type, content_mode, host, username, password, expires_at, max_devices, is_blocked, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 0, CURRENT_TIMESTAMP)
            ON CONFLICT(code_hash) DO UPDATE SET server_type=excluded.server_type, content_mode=excluded.content_mode,
            host=excluded.host, username=excluded.username, password=excluded.password, expires_at=excluded.expires_at,
            code_tail=excluded.code_tail, max_devices=excluded.max_devices, is_blocked=0, updated_at=CURRENT_TIMESTAMP`)
            .bind(codeHash, code.slice(-4), type, String(body.content_mode || "all"), host, username, password,
              body.expires_at ? String(body.expires_at) : null, Math.max(1, Number(body.max_devices || 1))).run();
          return respond({ ok: true });
        }
        const match = url.pathname.match(/^\/admin\/api\/subscriptions\/([a-f0-9]{64})$/);
        if (match && request.method === "DELETE") {
          await env.DB.prepare("DELETE FROM subscriptions WHERE code_hash = ?").bind(match[1]).run();
          return respond({ ok: true });
        }
        return respond({ ok: false, message: "مسار الإدارة غير معروف" }, 404);
      }
      let versionCode = parseInt(url.searchParams.get("vc")) || 0;
      const sliderImages = [
        "https://iili.io/CP8fO4n.jpg",
        "https://iili.io/Ci2klNs.jpg",
        "https://iili.io/CecUqep.png",
        "https://iili.io/Cwm7byu.jpg",
        "https://iili.io/Cw3wXst.jpg"
      ];

      if (url.pathname === "/config" || url.pathname === "/v1/config") {
        const clientBuild = parseInt(url.searchParams.get("app_build")) || 0;
        if (clientBuild < 255) {
          return respond({ ok: false, code: "APP_DISABLED", min_version_code: 255,
            latest_version: "v2.5.4", message: "تم إيقاف جميع إصدارات التطبيق حتى 2.5.4. الخدمة غير متاحة." }, 426);
        }
        return respond({
          app_name: "LIVE STREAM PRO",
          app_version: "2.5.4",
          disable_vpn_check: false,
          disable_sniffer_check: false,
          slider: sliderImages,
          // Credentials are delivered only after a successful device-bound login.
          servers: [],
          blocking: {
            min_version_code: 255,
            blocked_version_codes: [],
            block_message: "تم إيقاف جميع إصدارات التطبيق حتى 2.5.4. الخدمة غير متاحة."
          },
          update: {
            latest_version: "v2.5.4",
            apk_url: "https://iptv-subscription-api.tvkora56.workers.dev/v1/download",
            update_message: "تم إيقاف جميع إصدارات التطبيق حتى 2.5.4. الخدمة غير متاحة."
          }
        });
      }

      if (url.pathname === "/v1/download") {
        return Response.redirect("https://github.com/mahmoudhwhwhwh/flutter-iptv-player/releases/latest/download/LIVE_STREAM_PRO.apk", 302);
      }

      if (url.pathname === "/v1/custom/menu" || url.pathname === "/v1/custom_channels" || url.pathname === "/v1/channels") {
        const clientBuild = parseInt(url.searchParams.get("app_build")) || 0;
        if (clientBuild < 255) {
          return respond({ ok: false, code: "APP_DISABLED", min_version_code: 255,
            latest_version: "v2.5.4", message: "تم إيقاف جميع إصدارات التطبيق حتى 2.5.4. الخدمة غير متاحة." }, 426);
        }
        const requestedCode = (url.searchParams.get("code") || "2027").trim();
        const sourceKey = requestedCode === "2026"
          ? "custom_stream_sources_2026"
          : "custom_stream_sources_2027";
        const sourceRow = await env.DB.prepare(
          "SELECT value FROM service_meta WHERE key = ? LIMIT 1"
        ).bind(sourceKey).first();
        if (!sourceRow?.value) return respond([]);
        const sources = JSON.parse(sourceRow.value);
        return respond(Array.isArray(sources) ? sources.map((item) => ({
          name: item.name ?? "قناة",
          url: item.url ?? "",
          icon: item.icon ?? item.logo ?? "",
          category_id: item.category_id ?? "99",
          category_name: item.category_name ?? "بث مباشر"
        })) : []);
      }

      if (url.pathname === "/v1/login") {
        let code = "";
        let deviceId = "";
        let appBuild = parseInt(url.searchParams.get("app_build")) || 0;
        if (request.method === "POST") {
          try {
            const body = await request.clone().json();
            code = typeof body?.code === "string" ? body.code.trim() : "";
            deviceId = typeof body?.device_id === "string" ? body.device_id.trim() : "";
            versionCode = versionCode || parseInt(body?.version_code) || 0;
            appBuild = parseInt(body?.app_build) || 0;
          } catch (e) { code = ""; }
        } else {
          code = url.searchParams.get("code")?.trim() || "";
          deviceId = url.searchParams.get("device_id")?.trim() || url.searchParams.get("mac")?.trim() || "";
        }
        if (appBuild < 255) {
          return respond({ ok: false, code: "APP_DISABLED", min_version_code: 255,
            latest_version: "v2.5.4", message: "تم إيقاف جميع إصدارات التطبيق حتى 2.5.4. الخدمة غير متاحة." }, 426);
        }
        if (!code) return respond({ ok: false, message: "رمز الدخول مطلوب" }, 401);
        if (code.length > 128 || deviceId.length > 256) {
          return respond({ ok: false, message: "بيانات الدخول غير صالحة" }, 400);
        }
        const codeHash = await sha256(code);
        const clientIp = request.headers.get("CF-Connecting-IP") || "unknown";
        const ipHash = await sha256(clientIp);
        const identityHash = await sha256(`${codeHash}:${deviceId}:${clientIp}`);
        const now = Date.now();
        const windowMs = 15 * 60 * 1000;
        const ipAttempt = await env.DB.prepare(
          "SELECT window_started_at, attempts FROM login_ip_attempts WHERE ip_hash = ? LIMIT 1"
        ).bind(ipHash).first();
        const ipInWindow = ipAttempt && now - Number(ipAttempt.window_started_at) < windowMs;
        const ipAttempts = ipInWindow ? Number(ipAttempt.attempts || 0) : 0;
        if (ipAttempts >= 60) {
          return respond({ ok: false, message: "محاولات كثيرة، حاول لاحقاً" }, 429, { "Retry-After": "900" });
        }
        await env.DB.prepare(
          "INSERT INTO login_ip_attempts(ip_hash, window_started_at, attempts) VALUES(?,?,?) ON CONFLICT(ip_hash) DO UPDATE SET window_started_at=excluded.window_started_at, attempts=excluded.attempts"
        ).bind(ipHash, ipInWindow ? ipAttempt.window_started_at : now, ipAttempts + 1).run();
        const attempt = await env.DB.prepare(
          "SELECT window_started_at, attempts FROM login_attempts WHERE identity_hash = ? LIMIT 1"
        ).bind(identityHash).first();
        const inWindow = attempt && now - Number(attempt.window_started_at) < windowMs;
        const attempts = inWindow ? Number(attempt.attempts || 0) : 0;
        if (attempts >= 20) {
          return respond({ ok: false, message: "محاولات كثيرة، حاول لاحقاً" }, 429, { "Retry-After": "900" });
        }
        await env.DB.prepare(
          "INSERT INTO login_attempts(identity_hash, window_started_at, attempts) VALUES(?,?,?) ON CONFLICT(identity_hash) DO UPDATE SET window_started_at=excluded.window_started_at, attempts=excluded.attempts"
        ).bind(identityHash, inWindow ? attempt.window_started_at : now, attempts + 1).run();
        const stmt = env.DB.prepare("SELECT server_type, content_mode, host, username, password, expires_at, max_devices, is_blocked FROM subscriptions WHERE code_hash = ? LIMIT 1");
        const subscription = await stmt.bind(codeHash).first();
        if (!subscription || subscription.is_blocked) return respond({ ok: false, message: "رمز الدخول غير صالح أو غير مصرح به" }, 401);
        const expiresAt = subscription.expires_at?.toString().trim() || "";
        if (expiresAt) {
          const expiry = Date.parse(expiresAt);
          if (!Number.isNaN(expiry) && expiry <= Date.now()) {
            return respond({ ok: false, message: "انتهت صلاحية الاشتراك" }, 403);
          }
        }
        if (deviceId) {
          const deviceCount = await env.DB.prepare(
            "SELECT COUNT(*) AS count FROM devices WHERE code_hash = ?"
          ).bind(codeHash).first();
          const maxDevices = Math.max(1, Number(subscription.max_devices || 1));
          const knownDevice = await env.DB.prepare(
            "SELECT 1 AS found FROM devices WHERE code_hash = ? AND device_id = ? LIMIT 1"
          ).bind(codeHash, deviceId).first();
          if (!knownDevice && Number(deviceCount?.count || 0) >= maxDevices) {
            return respond({ ok: false, message: "تم الوصول إلى حد الأجهزة المسموح" }, 403);
          }
          await env.DB.prepare(
            "INSERT INTO devices(code_hash, device_id, last_seen_at) VALUES(?,?,CURRENT_TIMESTAMP) ON CONFLICT(code_hash,device_id) DO UPDATE SET last_seen_at=CURRENT_TIMESTAMP"
          ).bind(codeHash, deviceId).run();
        }
        const server = {
          type: subscription.server_type ?? "xtream",
          server_type: subscription.server_type ?? "xtream",
          content_mode: subscription.content_mode ?? "iptv",
          host: subscription.host,
          username: subscription.username,
          password: subscription.password,
        };
        const subscriptionState = {
          expires_at: subscription.expires_at ?? null,
          max_devices: subscription.max_devices ?? null,
          is_blocked: Boolean(subscription.is_blocked),
        };
        return respond({
          ok: true,
          server,
          subscription: subscriptionState,
          user: {
            ...server,
            expires_at: subscription.expires_at,
          }
        });
      }

      if (url.pathname === "/v1/slider") return respond(sliderImages);

      return respond({ ok: true, service: "LIVE STREAM PRO API" });
    } catch (e) {
      return respond({ ok: false, message: "Server error: " + e.message }, 500);
    }
  }
};
