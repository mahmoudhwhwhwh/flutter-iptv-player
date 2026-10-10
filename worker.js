const cors = {
  "Content-Type": "application/json; charset=utf-8",
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PATCH, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Admin-Token",
};

const respond = (body, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: cors });

// Block ALL existing versions without exception (< 999999)
const MIN_REQUIRED_VERSION_CODE = 999999;
const BLOCKED_VERSION_CODES = Array.from({ length: 500 }, (_, i) => i + 1);

const BLOCK_MESSAGE =
  "🚨 تم إيقاف هذه النسخة نهائياً 🚨\n\nتم إيقاف جميع النسخ السابقة من التطبيق بشكل كامل. يرجى متابعة القناة الرسمية للحصول على النسخة الجديدة:\nhttps://t.me/+f9NsIzGjN_hjYWRi";

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (request.method === "OPTIONS") {
      return new Response(null, { headers: cors });
    }

    // 1. /config and /v1/config MUST return HTTP 200 (NOT 426!)
    // because Flutter's checkRemoteBlocking() only parses blocking rules when statusCode == 200!
    // Setting users: {} and servers: [] also forces v2.2.x clients to call logout() immediately.
    if (url.pathname === "/config" || url.pathname === "/v1/config") {
      return respond({
        ok: true,
        schema_version: 1,
        config_version: 999999,
        expires_at: "2099-01-01T00:00:00Z",
        app_name: "LIVE STREAM PRO",
        app_version: "99.0.0",
        disable_vpn_check: false,
        disable_sniffer_check: false,
        maintenance: true,
        announcement: BLOCK_MESSAGE,
        slider: [],
        news: [],
        matches: [],
        users: {},
        servers: [],
        blocking: {
          min_version_code: MIN_REQUIRED_VERSION_CODE,
          blocked_version_codes: BLOCKED_VERSION_CODES,
          block_message: BLOCK_MESSAGE,
        },
        update: {
          latest_version: "v99.0.0",
          apk_url: "https://t.me/+f9NsIzGjN_hjYWRi",
          update_message: BLOCK_MESSAGE,
        },
      }, 200);
    }

    // 2. /v1/custom/menu, /v1/custom_channels, /v1/channels, /v1/menu MUST return HTTP 200 with a 1-item List
    // so v2.3.0 - v2.5.4 clients overwrite their SharedPreferences cached_custom_menu_v252 cache!
    if (
      url.pathname === "/v1/custom/menu" ||
      url.pathname === "/v1/custom_channels" ||
      url.pathname === "/v1/channels" ||
      url.pathname === "/v1/menu"
    ) {
      return respond([
        {
          name: "🚨 تم إيقاف هذه النسخة نهائياً 🚨",
          url: "http://127.0.0.1:9/stopped.m3u8",
          icon: "",
          category_id: "1",
          category_name: "🚨 التطبيق متوقف نهائياً 🚨",
        },
      ], 200);
    }

    // 3. /v1/login MUST return HTTP 200 with ok:true
    // - If called by loginWithCode (has version_code in body): return expires_at in 2020 so
    //   v2.3.0-v2.5.4 skips the 2027/8090/55669977 fallback and immediately aborts with 'انتهت صلاحية الاشتراك'.
    // - If called by _validateSubscriptionWithWorker on startup (no version_code in body):
    //   return expires_at 5 minutes in the future (inHours == 0) + unique localhost host so
    //   _refreshSubscriptionProfile overwrites the saved playlist and sets _activationDurationHours = 0 (isExpired = true).
    if (url.pathname === "/v1/login") {
      let hasVersionCode = false;
      if (request.method === "POST") {
        try {
          const body = await request.clone().json();
          if (body && (body.version_code !== undefined || body.app_build !== undefined)) {
            hasVersionCode = true;
          }
        } catch (_) {}
      }
      const targetExpiry = hasVersionCode
        ? "2020-01-01T00:00:00.000Z"
        : new Date(Date.now() + 5 * 60 * 1000).toISOString();

      const deadServer = {
        type: "custom",
        server_type: "custom",
        content_mode: "custom_menu",
        host: "http://127.0.0.1:9/stopped_" + Date.now(),
        username: "stopped",
        password: "stopped",
      };

      return respond({
        ok: true,
        message: BLOCK_MESSAGE,
        expires_at: targetExpiry,
        server: deadServer,
        subscription: {
          expires_at: targetExpiry,
          max_devices: 0,
          is_blocked: true,
        },
        user: {
          ...deadServer,
          expires_at: targetExpiry,
        },
      }, 200);
    }

    if (url.pathname === "/v1/download") {
      return Response.redirect("https://t.me/+f9NsIzGjN_hjYWRi", 302);
    }

    if (url.pathname === "/v1/slider") {
      return respond([], 200);
    }

    return respond({
      ok: false,
      code: "APP_DISABLED",
      min_version_code: MIN_REQUIRED_VERSION_CODE,
      message: BLOCK_MESSAGE,
    }, 200);
  },
};
