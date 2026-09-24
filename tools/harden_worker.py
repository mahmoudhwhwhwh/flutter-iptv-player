from pathlib import Path

p = Path('worker.js')
s = p.read_text()

s = s.replace(
'''const respond = (body, status = 200) => new Response(JSON.stringify(body), { status, headers: cors });''',
'''const securityHeaders = {
  "Cache-Control": "no-store",
  "X-Content-Type-Options": "nosniff",
  "X-Frame-Options": "DENY",
  "Referrer-Policy": "no-referrer",
  "Permissions-Policy": "camera=(), microphone=(), geolocation=()",
};
const respond = (body, status = 200, extraHeaders = {}) => new Response(JSON.stringify(body), {
  status,
  headers: { ...cors, ...securityHeaders, ...extraHeaders },
});''')

s = s.replace(
'''      await env.DB.prepare(`CREATE TABLE IF NOT EXISTS service_meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);`).run();''',
'''      await env.DB.prepare(`CREATE TABLE IF NOT EXISTS service_meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);`).run();
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
      );`).run();''')

s = s.replace(
'''      if (url.pathname === "/admin") {
        return new Response(adminHtml, { headers: { "Content-Type": "text/html; charset=utf-8" } });
      }''',
'''      if (url.pathname === "/admin") {
        return new Response(adminHtml, { headers: { "Content-Type": "text/html; charset=utf-8", ...securityHeaders } });
      }''')

s = s.replace(
'''          const body = await request.json();
          const code = String(body.code || "").trim();''',
'''          const length = Number(request.headers.get("Content-Length") || 0);
          if (length > 16 * 1024) return respond({ ok: false, message: "الطلب كبير جداً" }, 413);
          const body = await request.json();
          const code = String(body.code || "").trim();''')

s = s.replace(
'''          if (!code || !host || !username) return respond({ ok: false, message: "الرمز والرابط وبيانات الدخول مطلوبة" }, 400);''',
'''          if (code.length > 128 || host.length > 512 || username.length > 256) {
            return respond({ ok: false, message: "بيانات الاشتراك غير صالحة" }, 400);
          }
          if (!code || !host || !username) return respond({ ok: false, message: "الرمز والرابط وبيانات الدخول مطلوبة" }, 400);''')

s = s.replace(
'''        const codeHash = await sha256(code);
        const clientIp = request.headers.get("CF-Connecting-IP") || "unknown";
        const identityHash = await sha256(`${codeHash}:${deviceId}:${clientIp}`);
        const now = Date.now();''',
'''        if (code.length > 128 || deviceId.length > 256) {
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
        ).bind(ipHash, ipInWindow ? ipAttempt.window_started_at : now, ipAttempts + 1).run();''')

s = s.replace('''        const windowMs = 15 * 60 * 1000;
        const inWindow''', '''        const inWindow''')

start = s.find('''          servers: [''')
end = s.find('''          ],
          blocking:''', start)
if start == -1 or end == -1:
    raise SystemExit('servers block not found')
s = s[:start] + '''          // Credentials are delivered only after a successful device-bound login.
          servers: [],
''' + s[end + len('''          ],
'''):]

p.write_text(s)

pub = Path('pubspec.yaml')
ps = pub.read_text()
ps = ps.replace('  chewie: ^1.7.5\n', '')
pub.write_text(ps)
