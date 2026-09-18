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
          app_version: "2.2.34",
          disable_vpn_check: true,
          disable_sniffer_check: true,
          slider: sliderImages,
          servers: [
            {
              "name": "مجاني دجلة 9",
              "host": "http://megatv.shop:2052",
              "username": "52705199363828",
              "password": "24129350577560",
              "users": {
                "mahmoud2027": {
                  "expiry_date": "2027-01-01T00:00:00Z",
                  "devices": ["UKQ1.240624.001"]
                }
              }
            },
            {
              "name": "Server 2",
              "host": "http://2@cliccck52258.club:2082",
              "username": "khaledsliman",
              "password": "755246419856",
              "users": {
                "02389": {
                  "expiry_date": "بلا بلا حدود",
                  "devices": ["UKQ1.240624.001"]
                }
              }
            },
            {
              "name": "Server 3",
              "host": "http://1@cliccck52258.club:2082",
              "username": "251878975765",
              "password": "924893245689",
              "users": {
                "s3_code1": {
                  "expiry_date": "2027-01-01T00:00:00Z",
                  "devices": ["UKQ1.240624.001"]
                }
              }
            },
            {
              "name": "Server 4",
              "host": "http://marveliptv.life",
              "username": "01112727740kh",
              "password": "khiary7740",
              "users": {
                "96827": {
                  "expiry_date": "بلا حدود ",
                  "devices": ["UKQ1.240624.001"]
                }
              }
            },
            {
              "name": "Server 5",
              "host": "http://4kpro2.com",
              "type": "stalker",
              "users": {
                "999499": {
                  "username": "00:1A:79:70:9D:14",
                  "expiry_date": "2026-08-03T00:00:00Z",
                  "devices": ["UKQ1.240624.001", "RKQ1.211119.001"],
                  "blocked": true
                }
              }
            },
            {
              "name": "Server 6",
              "host": "http://4kpro2.com",
              "type": "stalker",
              "users": {
                "s6_code1": {
                  "expiry_date": "2027-01-01T00:00:00Z",
                  "devices": ["UKQ1.240624.001"]
                }
              }
            },
            {
              "name": "Server 7",
              "host": "http://line.tvdsz.cc",
              "type": "stalker",
              "users": {
                "joker01": {
                  "expiry_date": "بلا حدود",
                  "devices": ["UKQ1.240624.001"]
                }
              }
            },
            {
              "name": "مجاني دجلة 1",
              "host": "http://31.220.41.178",
              "username": "marv90746918",
              "password": "khaled974635",
              "users": {
                "joker02": {
                  "expiry_date": "بلا حدود",
                  "devices": ["UKQ1.240624.001"]
                }
              }
            },
            {
              "name": "مجاني دجلة 2",
              "host": "http://app.upsdo.me:8080",
              "username": "PCJ7KCNU0AX6",
              "password": "36508313",
              "users": {
                "joker03": {
                  "expiry_date": "بلا حدود",
                  "devices": ["UKQ1.240624.001"]
                }
              }
            },
            {
              "name": "مجاني دجلة 3",
              "host": "http://185.191.126.127:8080",
              "username": "b0:99:d7:15:88:50",
              "password": "3090914536649669",
              "users": {
                "joker04": {
                  "expiry_date": "بلا حدود",
                  "devices": ["UKQ1.240624.001"]
                }
              }
            },
            {
              "name": "مجاني دجلة 4",
              "host": "http://dhoomtv.xyz",
              "username": "8zpo3GsVY7",
              "password": "beneficial2concern",
              "users": {
                "joker05": {
                  "expiry_date": "بلا حدود",
                  "devices": ["UKQ1.240624.001"]
                }
              }
            },
            {
              "name": "مجاني دجلة 5",
              "host": "http://filex.me:8080",
              "username": "@boss1751",
              "password": "rS27a9QKeT",
              "users": {
                "joker06": {
                  "expiry_date": "بلا حدود",
                  "devices": ["UKQ1.240624.001"]
                }
              }
            },
            {
              "name": "مجاني دجلة 6",
              "host": "http://cli2345.live:2082",
              "username": "162228198272",
              "password": "847259919147",
              "users": {
                "joker07": {
                  "expiry_date": "بلا حدود",
                  "devices": ["UKQ1.240624.001"]
                }
              }
            },
            {
              "name": "مجاني دجلة 7",
              "host": "http://alliptvapp.com:8080",
              "username": "575612159628",
              "password": "210763093616",
              "users": {
                "joker08": {
                  "expiry_date": "بلا حدود",
                  "devices": ["UKQ1.240624.001"]
                }
              }
            },
            {
              "name": "مجاني دجلة 8",
              "host": "http://atlaspro.live",
              "username": "3525480303377768",
              "password": "3525480303377768",
              "users": {
                "joker09": {
                  "expiry_date": "بلا حدود",
                  "devices": ["UKQ1.240624.001"]
                }
              }
            },
            {
              "name": "مجاني دجلة 10",
              "host": "http://luxipgold.xyz:8080",
              "username": "15034094901029",
              "password": "18800196589372",
              "users": {
                "joker10": {
                  "expiry_date": "بلا حدود",
                  "devices": ["UKQ1.240624.001"]
                }
              }
            },
            {
              "name": "دجلة مجاني 11",
              "host": "http://mypythonpremium.com:8789",
              "username": "wilderd",
              "password": "tFeWsYW",
              "users": {
                "joker11": {
                  "expiry_date": "بلا حدود",
                  "devices": ["UKQ1.240624.001"]
                }
              }
            },
            {
              "name": "مجاني دجلة  12",
              "host": "http://falcon-sa.xyz",
              "username": "wSGGTNJH",
              "password": "32CC849A",
              "users": {
                "joker12": {
                  "expiry_date": "بلا حدود",
                  "devices": ["UKQ1.240624.001"]
                }
              }
            }
          ],
          blocking: {
            min_version_code: 234,
            blocked_version_codes: [125, 130, 140, 144, 205, 211, 212, 233],
            block_message: "🚨 تم إيقاف هذا الإصدار القديم نهائياً.\nيرجى التحديث إلى الإصدار v2.2.34 للاستمرار."
          },
          update: {
            latest_version: "v2.2.34",
            apk_url: "https://iptv-subscription-api.tvkora56.workers.dev/v1/download",
            update_message: "نسخة جديدة متاحة (v2.2.34). يرجى التحديث الآن."
          }
        });
      }

      if (url.pathname === "/v1/download") {
        return Response.redirect("https://github.com/mahmoudhwhwhwh/flutter-iptv-player/releases/download/v2.2.34/LIVE_STREAM_PREMIUM.apk", 302);
      }

      if (url.pathname === "/v1/custom/menu" || url.pathname === "/v1/custom_channels" || url.pathname === "/v1/channels") {
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
        const expiresAt = subscription.expires_at?.toString().trim() || "";
        if (expiresAt) {
          const expiry = Date.parse(expiresAt);
          if (!Number.isNaN(expiry) && expiry <= Date.now()) {
            return respond({ ok: false, message: "انتهت صلاحية الاشتراك" }, 403);
          }
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
            code: code,
            ...server,
            expires_at: subscription.expires_at,
          }
        });
      }

      if (url.pathname === "/v1/slider") return respond(sliderImages);

      return respond({ ok: true, service: "LIVE STREAM PREMIUM API" });
    } catch (e) {
      return respond({ ok: false, message: "Server error: " + e.message }, 500);
    }
  }
};
