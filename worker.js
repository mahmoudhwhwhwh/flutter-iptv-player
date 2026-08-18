const cors = {
  "Content-Type": "application/json; charset=utf-8",
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
};
const respond = (body, status = 200) => new Response(JSON.stringify(body), { status, headers: cors });
async function sha256(value) {
  const data = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest("SHA-256", data);
  return [...new Uint8Array(digest)].map(byte => byte.toString(16).padStart(2, "0")).join("");
}
export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (request.method === "OPTIONS") return new Response(null, { headers: cors });
    if (!env.DB) return respond({ ok: false, message: "Database binding missing" }, 503);
    try {
      let versionCode = parseInt(url.searchParams.get("vc")) || 0;
      const sliderImages = [
        "https://iili.io/CP8fO4n.jpg",
        "https://iili.io/Ci2klNs.jpg",
        "https://iili.io/CecUqep.png",
        "https://iili.io/Cwm7byu.jpg",
        "https://iili.io/Cw3wXst.jpg"
      ];
      if (url.pathname === "/config" || url.pathname === "/v1/config") {
        return respond({
          app_name: "LIVE STREAM PREMIUM",
          app_version: "2.2.33",
          disable_vpn_check: true,
          disable_sniffer_check: true,
          slider: sliderImages,
          servers: [
            { "name": "Server 1", "host": "http://megatv.shop:2052", "username": "20299538378191", "password": "36172842922822" },
            { "name": "Server 2", "host": "http://2@cliccck52258.club:2082", "username": "khaledsliman", "password": "755246419856" },
            { "name": "Server 3", "host": "http://1@cliccck52258.club:2082", "username": "251878975765", "password": "924893245689" },
            { "name": "Server 4", "host": "http://marveliptv.life", "username": "01112727740kh", "password": "khiary7740" },
            { "name": "Server 5", "host": "http://4kpro2.com", "type": "stalker", "username": "00:1A:79:70:9D:14" },
            { "name": "Server 6", "host": "http://4kpro2.com", "type": "stalker", "username": "00:1A:79:70:9D:14" }
          ],
          blocking: { min_version_code: 233, block_message: "🚨 تم إيقاف هذا الإصدار القديم نهائياً.\nيرجى التحديث إلى الإصدار v2.2.33 للاستمرار في المشاهدة." },
          update: { latest_version: "v2.2.33", apk_url: "https://iptv-subscription-api.tvkora56.workers.dev/v1/download" }
        });
      }
      if (url.pathname === "/v1/download") {
        return Response.redirect("https://github.com/mahmoudhwhwhwh/flutter-iptv-player/releases/download/v2.2.33-stable/LIVE_STREAM_PREMIUM.apk", 302);
      }
      if (url.pathname === "/v1/login") {
        let code = "";
        let deviceId = "";
        if (request.method === "POST") {
          try {
            const body = await request.clone().json();
            code = typeof body?.code === "string" ? body.code.trim() : "";
            deviceId = typeof body?.device_id === "string" ? body.device_id.trim() : "";
            versionCode = versionCode || parseInt(body?.version_code) || 0;
          } catch (e) { code = ""; }
        } else {
          code = url.searchParams.get("code")?.trim() || "";
          deviceId = url.searchParams.get("device_id")?.trim() || url.searchParams.get("mac")?.trim() || "";
        }
        if (!code) return respond({ ok: false, message: "رمز الدخول مطلوب" }, 401);
        const codeHash = await sha256(code);
        const stmt = env.DB.prepare("SELECT server_type, content_mode, host, username, password, expires_at, max_devices, is_blocked FROM subscriptions WHERE code_hash = ? LIMIT 1");
        const subscription = await stmt.bind(codeHash).first();
        if (!subscription || subscription.is_blocked) return respond({ ok: false, message: "رمز الدخول غير صالح أو غير مصرح به" }, 401);
        return respond({ ok: true, user: { code: code, server_type: subscription.server_type ?? "xtream", content_mode: subscription.content_mode ?? "iptv", host: subscription.host, username: subscription.username, password: subscription.password, expires_at: subscription.expires_at } });
      }
      if (url.pathname === "/v1/slider") return respond(sliderImages);
      return respond({ ok: true, service: "LIVE STREAM PREMIUM API" });
    } catch (e) { return respond({ ok: false, message: "Server error: " + e.message }, 500); }
  }
};
