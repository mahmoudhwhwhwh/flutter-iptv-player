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
          app_version: "2.2.78",
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
              "host": "http://cliccck52258.club:2082",
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
            min_version_code: 275,
            blocked_version_codes: [125, 130, 140, 144, 205, 211, 212, 233, 234, 277],
            block_message: "🚨 تم إيقاف هذا الإصدار القديم نهائياً.\nيرجى التحديث إلى الإصدار v2.2.78 للاستمرار."
          },
          update: {
            latest_version: "v2.2.78",
            apk_url: "https://iptv-subscription-api.tvkora56.workers.dev/v1/download",
            update_message: "يتوفر الآن LIVE STREAM PREMIUM v2.2.78 الاستثنائي بميزات جديدة: مشغل داخلي متطور، واجهة إعدادات متميزة باللغة العربية، ودعم كامل لقنوات 2027 والاشتراكات الجديدة من Cloudflare مباشرة."
          }
        });
      }

      if (url.pathname === "/v1/download") {
        const apkUrl = "https://github.com/mahmoudhwhwhwh/flutter-iptv-player/releases/download/v2.2.78-final7/LIVE_STREAM_PREMIUM.apk";
        try {
          const response = await fetch(apkUrl, {
            headers: {
              "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            }
          });
          
          let finalResponse = response;
          if (response.status === 301 || response.status === 302) {
            const redirectUrl = response.headers.get("Location");
            if (redirectUrl) {
              finalResponse = await fetch(redirectUrl);
            }
          }

          const newHeaders = new Headers();
          // Copy content headers safely
          const headersToCopy = ["content-type", "content-length", "content-disposition", "cache-control"];
          for (const h of headersToCopy) {
            if (finalResponse.headers.has(h)) {
              newHeaders.set(h, finalResponse.headers.get(h));
            }
          }
          newHeaders.set("Access-Control-Allow-Origin", "*");
          if (!newHeaders.has("content-type")) {
            newHeaders.set("content-type", "application/vnd.android.package-archive");
          }
          if (!newHeaders.has("content-disposition")) {
            newHeaders.set("content-disposition", 'attachment; filename="LIVE_STREAM_PREMIUM.apk"');
          }

          return new Response(finalResponse.body, {
            status: finalResponse.status,
            headers: newHeaders,
          });
        } catch (err) {
          return Response.redirect(apkUrl, 302);
        }
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
        return respond({
          ok: true,
          user: {
            code: code,
            server_type: subscription.server_type ?? "xtream",
            content_mode: subscription.content_mode ?? "iptv",
            host: subscription.host,
            username: subscription.username,
            password: subscription.password,
            expires_at: subscription.expires_at
          }
        });
      }

      if (url.pathname === "/v1/menu" || url.pathname === "/menu") {
        return respond([{"name": "SPORTS 1 HD \u26a1", "icon": "https://iili.io/CKGvbzx.png", "url": "https://live-football-2mf.pages.dev/index_bein%20max1.m3u8", "category_name": "Match time", "category_id": "custom_pro_1", "user_agent": "", "referer": "", "keys": {}}, {"name": "\u062e\u0627\u0635\u0647 \u0628 \u0646\u0642\u0644 \u0645\u0628\u0627\u0631\u064a\u0627\u062a \u0628\u0631\u0634\u0644\u0648\u0646\u0629 \u26a1", "icon": "https://iili.io/CKGvbzx.png", "url": "https://a12.kora-plus.li/live/alwan1.m3u8?token=C0WWFtcRLW-TRLXuk8jDEtk_3mc&exp=1786221480", "category_name": "Match time", "category_id": "custom_pro_1", "user_agent": "", "referer": "", "keys": {}}, {"name": "SPORTS 2 HD \u26a1", "icon": "https://iili.io/CKGvbzx.png", "url": "https://live-football-2mf.pages.dev/index_bein%20max2.m3u8", "category_name": "Match time", "category_id": "custom_pro_1", "user_agent": "", "referer": "", "keys": {}}, {"name": "SPORTS 3 HD \u26a1", "icon": "https://iili.io/CKGvbzx.png", "url": "https://live-football-2mf.pages.dev/index_bein%20max3.m3u8", "category_name": "Match time", "category_id": "custom_pro_1", "user_agent": "", "referer": "", "keys": {}}, {"name": "SPORTS 4 HD \u26a1", "icon": "https://iili.io/CKGvbzx.png", "url": "https://live-football-2mf.pages.dev/index_bein%20max4.m3u8", "category_name": "Match time", "category_id": "custom_pro_1", "user_agent": "", "referer": "", "keys": {}}, {"name": "SPORTS 5 HD\u26a1 ", "icon": "https://iili.io/CKGvbzx.png", "url": "https://live-football-2mf.pages.dev/index_bein%20max5.m3u8", "category_name": "Match time", "category_id": "custom_pro_1", "user_agent": "", "referer": "", "keys": {}}, {"name": "SPORTS 6 HD\u26a1 ", "icon": "https://iili.io/CKGvbzx.png", "url": "https://live-football-2mf.pages.dev/index_bein%20max6.m3u8", "category_name": "Match time", "category_id": "custom_pro_1", "user_agent": "", "referer": "", "keys": {}}, {"name": "beIN Sports 1 HD pro  \u26a1", "icon": "https://iili.io/CK75BIe.png", "url": "https://live-football-2mf.pages.dev/index_bein%20max7.m3u8", "category_name": "\u0628\u064a\u0646 \u0633\u0628\u0648\u0631\u062a", "category_id": "custom_pro_2", "user_agent": "", "referer": "", "keys": {}}, {"name": "beIN Sports 2 HD pro  \u26a1", "icon": "https://iili.io/CK75iZu.png", "url": "https://live-football-2mf.pages.dev/index_bein%20max8.m3u8", "category_name": "\u0628\u064a\u0646 \u0633\u0628\u0648\u0631\u062a", "category_id": "custom_pro_2", "user_agent": "", "referer": "", "keys": {}}, {"name": "beIN Sports 3 HD pro \u26a1", "icon": "https://iili.io/CK77jSV.png", "url": "https://live-football-2mf.pages.dev/index_bein%20max9.m3u8", "category_name": "\u0628\u064a\u0646 \u0633\u0628\u0648\u0631\u062a", "category_id": "custom_pro_2", "user_agent": "", "referer": "", "keys": {}}, {"name": "beIN Sports 4 HD pro  \u26a1", "icon": "https://iili.io/CK7c6Ux.png", "url": "https://live-football-2mf.pages.dev/index_bein%20max10.m3u8", "category_name": "\u0628\u064a\u0646 \u0633\u0628\u0648\u0631\u062a", "category_id": "custom_pro_2", "user_agent": "", "referer": "", "keys": {}}, {"name": "beIN Sports 5 HD pro  \u26a1", "icon": "https://iili.io/CK7lc0b.png", "url": "https://live-football-2mf.pages.dev/index_bein%20max11.m3u8", "category_name": "\u0628\u064a\u0646 \u0633\u0628\u0648\u0631\u062a", "category_id": "custom_pro_2", "user_agent": "", "referer": "", "keys": {}}, {"name": "beIN Sports 6 HD pro  \u26a1", "icon": "https://iili.io/CK7l4LX.png", "url": "https://live-football-2mf.pages.dev/index_bein%20max12.m3u8", "category_name": "\u0628\u064a\u0646 \u0633\u0628\u0648\u0631\u062a", "category_id": "custom_pro_2", "user_agent": "", "referer": "", "keys": {}}, {"name": "LIVE STREAM NETWORK 1  \u26a1", "icon": "https://iili.io/CK5M0pR.png", "url": "http://45.67.56.78/Sport1/index.fmp4.m3u8", "category_name": "\u0642\u0646\u0648\u0627\u062a \u0627\u0644\u0628\u062b \u0627\u0644\u0645\u0628\u0627\u0634\u0631", "category_id": "custom_pro_3", "user_agent": "", "referer": "", "keys": {}}, {"name": "LIVE STREAM NETWORK 2  \u26a1", "icon": "https://iili.io/CK5M0pR.png", "url": "http://45.67.56.78/Sport2/index.fmp4.m3u8", "category_name": "\u0642\u0646\u0648\u0627\u062a \u0627\u0644\u0628\u062b \u0627\u0644\u0645\u0628\u0627\u0634\u0631", "category_id": "custom_pro_3", "user_agent": "", "referer": "", "keys": {}}, {"name": "LIVE STREAM NETWORK 3\u26a1", "icon": "https://iili.io/CK5M0pR.png", "url": "http://45.67.56.78/Sport3/index.fmp4.m3u8", "category_name": "\u0642\u0646\u0648\u0627\u062a \u0627\u0644\u0628\u062b \u0627\u0644\u0645\u0628\u0627\u0634\u0631", "category_id": "custom_pro_3", "user_agent": "", "referer": "", "keys": {}}, {"name": "LIVE STREAM NETWORK 4 \u26a1", "icon": "https://iili.io/CK5M0pR.png", "url": "http://45.67.56.78/Sport4/index.fmp4.m3u8", "category_name": "\u0642\u0646\u0648\u0627\u062a \u0627\u0644\u0628\u062b \u0627\u0644\u0645\u0628\u0627\u0634\u0631", "category_id": "custom_pro_3", "user_agent": "", "referer": "", "keys": {}}, {"name": "LIVE STREAM NETWORK 5 \u26a1", "icon": "https://iili.io/CK5M0pR.png", "url": "http://45.67.56.78/Sport6/index.fmp4.m3u8", "category_name": "\u0642\u0646\u0648\u0627\u062a \u0627\u0644\u0628\u062b \u0627\u0644\u0645\u0628\u0627\u0634\u0631", "category_id": "custom_pro_3", "user_agent": "", "referer": "", "keys": {}}, {"name": "LIVE STREAM NETWORK 6  \u26a1", "icon": "https://iili.io/CK5M0pR.png", "url": "http://45.67.56.78/Sport6/index.fmp4.m3u8", "category_name": "\u0642\u0646\u0648\u0627\u062a \u0627\u0644\u0628\u062b \u0627\u0644\u0645\u0628\u0627\u0634\u0631", "category_id": "custom_pro_3", "user_agent": "", "referer": "", "keys": {}}, {"name": "LIVE STREAM NETWORK 7  \u26a1", "icon": "https://iili.io/CK5M0pR.png", "url": "http://45.67.56.78/Sport7/index.fmp4.m3u8", "category_name": "\u0642\u0646\u0648\u0627\u062a \u0627\u0644\u0628\u062b \u0627\u0644\u0645\u0628\u0627\u0634\u0631", "category_id": "custom_pro_3", "user_agent": "", "referer": "", "keys": {}}, {"name": "Alkass Sports 1 \u26a1", "icon": "https://iili.io/CKMJBjf.png", "url": "https://liveeu-gcp.alkassdigital.net/alkass1-p/main.m3u8", "category_name": "\u0627\u0644\u0631\u064a\u0627\u0636\u0629 \u0627\u0644\u0639\u0631\u0628\u064a\u0629", "category_id": "custom_pro_4", "user_agent": "", "referer": "", "keys": {"47f0ab58f5a81c20b5b69dc494cbe102": "1e0719da653c2b4652f0b0bf84d96c74"}}, {"name": "Alkass Sports 2 \u26a1", "icon": "https://iili.io/CKMJBjf.png", "url": "https://liveeu-gcp.alkassdigital.net/alkass2-p/main.m3u8", "category_name": "\u0627\u0644\u0631\u064a\u0627\u0636\u0629 \u0627\u0644\u0639\u0631\u0628\u064a\u0629", "category_id": "custom_pro_4", "user_agent": "", "referer": "", "keys": {}}, {"name": "Alkass Sports 3 \u26a1", "icon": "https://iili.io/CKMJBjf.png", "url": "https://liveeu-gcp.alkassdigital.net/alkass3-p/main.m3u8", "category_name": "\u0627\u0644\u0631\u064a\u0627\u0636\u0629 \u0627\u0644\u0639\u0631\u0628\u064a\u0629", "category_id": "custom_pro_4", "user_agent": "", "referer": "", "keys": {}}, {"name": "Alkass Sports 4 \u26a1", "icon": "https://iili.io/CKMJBjf.png", "url": "https://liveeu-gcp.alkassdigital.net/alkass4-p/main.m3u8", "category_name": "\u0627\u0644\u0631\u064a\u0627\u0636\u0629 \u0627\u0644\u0639\u0631\u0628\u064a\u0629", "category_id": "custom_pro_4", "user_agent": "", "referer": "", "keys": {}}, {"name": "Alkass Sports 5 \u26a1", "icon": "https://iili.io/CKMJBjf.png", "url": "https://liveeu-gcp.alkassdigital.net/alkass5-p/main.m3u8", "category_name": "\u0627\u0644\u0631\u064a\u0627\u0636\u0629 \u0627\u0644\u0639\u0631\u0628\u064a\u0629", "category_id": "custom_pro_4", "user_agent": "", "referer": "", "keys": {}}, {"name": "Alkass Sports 6 \u26a1", "icon": "https://iili.io/CKMJBjf.png", "url": "https://liveeu-gcp.alkassdigital.net/alkass6-p/main.m3u8", "category_name": "\u0627\u0644\u0631\u064a\u0627\u0636\u0629 \u0627\u0644\u0639\u0631\u0628\u064a\u0629", "category_id": "custom_pro_4", "user_agent": "", "referer": "", "keys": {}}, {"name": "Starz Play Sports 1 \u26a1", "icon": "https://iili.io/Cf02bDP.jpg", "url": "https://live-football-2mf.pages.dev/index_starz%20play1.m3u8", "category_name": "\u0627\u0644\u0631\u064a\u0627\u0636\u0629 \u0627\u0644\u0639\u0631\u0628\u064a\u0629", "category_id": "custom_pro_4", "user_agent": "", "referer": "", "keys": {}}, {"name": "Starz Play Sports 2 \u26a1", "icon": "https://iili.io/Cf02bDP.jpg", "url": "https://live-football-2mf.pages.dev/index_starz%20play2.m3u8", "category_name": "\u0627\u0644\u0631\u064a\u0627\u0636\u0629 \u0627\u0644\u0639\u0631\u0628\u064a\u0629", "category_id": "custom_pro_4", "user_agent": "", "referer": "", "keys": {}}, {"name": "Starz Play Sports 3 \u26a1", "icon": "https://iili.io/Cf02bDP.jpg", "url": "https://live-football-2mf.pages.dev/index_starz%20play3.m3u8", "category_name": "\u0627\u0644\u0631\u064a\u0627\u0636\u0629 \u0627\u0644\u0639\u0631\u0628\u064a\u0629", "category_id": "custom_pro_4", "user_agent": "", "referer": "", "keys": {}}, {"name": "THMANYAH  SPORTS 1  \u26a1", "icon": "https://iili.io/CKGia0x.png", "url": "http://marveliptv.life/01112727740kh/khiary7740/474871", "category_name": "\u0627\u0644\u0631\u064a\u0627\u0636\u0629 \u0627\u0644\u0639\u0631\u0628\u064a\u0629", "category_id": "custom_pro_4", "user_agent": "", "referer": "", "keys": {}}, {"name": "THMANYAH  SPORTS 2  \u26a1", "icon": "https://iili.io/CKGia0x.png", "url": "http://marveliptv.life/01112727740kh/khiary7740/474867", "category_name": "\u0627\u0644\u0631\u064a\u0627\u0636\u0629 \u0627\u0644\u0639\u0631\u0628\u064a\u0629", "category_id": "custom_pro_4", "user_agent": "", "referer": "", "keys": {}}, {"name": "THMANYAH  SPORTS 3  \u26a1", "icon": "https://iili.io/CKGia0x.png", "url": "http://marveliptv.life/01112727740kh/khiary7740/474863", "category_name": "\u0627\u0644\u0631\u064a\u0627\u0636\u0629 \u0627\u0644\u0639\u0631\u0628\u064a\u0629", "category_id": "custom_pro_4", "user_agent": "", "referer": "", "keys": {}}, {"name": "Abu Dhabi Sport 1 \u26a1", "icon": "https://iili.io/CBe6i8X.jpg", "url": "https://live-football-2mf.pages.dev/index_AD%20sports1.m3u8", "category_name": "\u0627\u0644\u0631\u064a\u0627\u0636\u0629 \u0627\u0644\u0639\u0631\u0628\u064a\u0629", "category_id": "custom_pro_4", "user_agent": "", "referer": "", "keys": {}}, {"name": "Abu Dhabi Sport 2 \u26a1", "icon": "https://iili.io/CBe6i8X.jpg", "url": "https://live-football-2mf.pages.dev/index_AD%20sports2.m3u8", "category_name": "\u0627\u0644\u0631\u064a\u0627\u0636\u0629 \u0627\u0644\u0639\u0631\u0628\u064a\u0629", "category_id": "custom_pro_4", "user_agent": "", "referer": "", "keys": {}}, {"name": "Sharjah SPORTS HD\u26a1", "icon": "https://iili.io/CgrMtWX.jpg", "url": "http://marveliptv.life/01112727740kh/khiary7740/261524", "category_name": "\u0627\u0644\u0631\u064a\u0627\u0636\u0629 \u0627\u0644\u0639\u0631\u0628\u064a\u0629", "category_id": "custom_pro_4", "user_agent": "", "referer": "", "keys": {}}, {"name": "IRAQI SPORTS HD\u26a1", "icon": "https://iili.io/CgrexDv.jpg", "url": "http://marveliptv.life/01112727740kh/khiary7740/154339", "category_name": "\u0627\u0644\u0631\u064a\u0627\u0636\u0629 \u0627\u0644\u0639\u0631\u0628\u064a\u0629", "category_id": "custom_pro_4", "user_agent": "", "referer": "", "keys": {}}, {"name": "\u0642\u0646\u0627\u0629 \u0627\u0644\u062c\u0632\u064a\u0631\u0629 \u0627\u0644\u0625\u062e\u0628\u0627\u0631\u064a\u0629 Al Jazeera HD \u26a1", "icon": "https://iili.io/CzNY9yJ.jpg", "url": "https://live-hls-web-aja.getaj.net/AJA/index.m3u8", "category_name": "\u0642\u0646\u0648\u0627\u062a \u0627\u0644\u0623\u062e\u0628\u0627\u0631 \u0648\u0627\u0644\u0623\u062d\u062f\u0627\u062b", "category_id": "custom_pro_5", "user_agent": "IPTV-Android-Box", "referer": "https://aljazeera.net", "keys": {"7406a641db1b63cbdcffdaae8df2831f": "daae8df2831f7406a641db1b63cbdcff"}}, {"name": "\u0627\u0644\u0639\u0631\u0628\u064a\u0629 \u0627\u0644\u062d\u062f\u062b Al Hadath HD \u26a1", "icon": "https://iili.io/CzwcODx.jpg", "url": "https://live.alarabiya.net/alarabiapublish/alarabiya.smil/playlist.m3u8", "category_name": "\u0642\u0646\u0648\u0627\u062a \u0627\u0644\u0623\u062e\u0628\u0627\u0631 \u0648\u0627\u0644\u0623\u062d\u062f\u0627\u062b", "category_id": "custom_pro_5"}, {"name": "\u0642\u0646\u0627\u0629 \u0627\u0644\u0639\u0631\u0628\u064a\u0629 Al Arabiya HD \u26a1", "icon": "https://iili.io/Czwle7n.jpg", "url": "https://live.kwikmotion.com/alaraby1live/alaraby_abr/playlist.m3u8", "category_name": "\u0642\u0646\u0648\u0627\u062a \u0627\u0644\u0623\u062e\u0628\u0627\u0631 \u0648\u0627\u0644\u0623\u062d\u062f\u0627\u062b", "category_id": "custom_pro_5"}, {"name": "Sky News Arabia \u0633\u0643\u0627\u064a \u0646\u064a\u0648\u0632 \u26a1", "icon": "https://iili.io/Czw1ODG.png", "url": "https://live-stream.skynewsarabia.com/c-horizontal-channel/horizontal-stream/index.m3u8", "category_name": "\u0642\u0646\u0648\u0627\u062a \u0627\u0644\u0623\u062e\u0628\u0627\u0631 \u0648\u0627\u0644\u0623\u062d\u062f\u0627\u062b", "category_id": "custom_pro_5"}, {"name": "BBC Arabic \u0628\u064a \u0628\u064a \u0633\u064a \u0639\u0631\u0628\u064a \u26a1", "icon": "https://iili.io/CzwEld7.png", "url": "https://vs-cmaf-pushb-ww-live.akamaized.net/x=4/i=urn:bbc:pips:service:bbc_arabic_tv/mobile_wifi_main_hd_abr_v2.mpd", "category_name": "\u0642\u0646\u0648\u0627\u062a \u0627\u0644\u0623\u062e\u0628\u0627\u0631 \u0648\u0627\u0644\u0623\u062d\u062f\u0627\u062b", "category_id": "custom_pro_5"}, {"name": "RT Arabic \u0631\u0648\u0633\u064a\u0627 \u0627\u0644\u064a\u0648\u0645 \u26a1", "icon": "https://iili.io/CzwGfTu.jpg", "url": "https://rt-arb.rttv.com/live/rtarab/playlist_1600Kb.m3u8", "category_name": "\u0642\u0646\u0648\u0627\u062a \u0627\u0644\u0623\u062e\u0628\u0627\u0631 \u0648\u0627\u0644\u0623\u062d\u062f\u0627\u062b", "category_id": "custom_pro_5"}, {"name": "NAT GEO WILD \ud83c\udf0d", "icon": "https://iili.io/Cz6SVAx.png", "url": "https://fastlyrwb-live.cdn.intigral-ott.net/NHD/NHD.isml/manifest.mpd", "category_name": "\u0627\u0644\u0648\u062b\u0627\u0626\u0642\u064a\u0629 \u0648\u0627\u0644\u062b\u0642\u0627\u0641\u064a\u0629", "category_id": "custom_pro_6", "user_agent": "Mozilla/5.0 (SmartTV)", "referer": "https://natgeo.ae", "keys": {"276e56bc14095f327bbf0c936eb7b38c": "63127eaddb18c596db05657424849519"}}, {"name": "\u0642\u0646\u0627\u0629 \u0627\u0644\u0634\u0631\u0648\u0642 \u0627\u0644\u0648\u062b\u0627\u0626\u0642\u064a\u0629 \ud83d\uddfa\ufe0f", "icon": "https://iili.io/Cz6SVAx.png", "url": "https://svs.itworkscdn.net/asharqdocumentarylive/asharqdocumentary.smil/playlist_dvr.m3u8", "category_name": "\u0627\u0644\u0648\u062b\u0627\u0626\u0642\u064a\u0629 \u0648\u0627\u0644\u062b\u0642\u0627\u0641\u064a\u0629", "category_id": "custom_pro_6", "user_agent": "", "referer": "", "keys": {}}, {"name": "\u0627\u0644\u062c\u0632\u064a\u0631\u0629 \u0627\u0644\u0648\u062b\u0627\u0626\u0642\u064a\u0629 Al Jazeera Doc \ud83d\udd0e", "icon": "https://iili.io/Cz6SVAx.png", "url": "https://live-hls-apps-ajd-fa.getaj.net/AJD/index.m3u8", "category_name": "\u0627\u0644\u0648\u062b\u0627\u0626\u0642\u064a\u0629 \u0648\u0627\u0644\u062b\u0642\u0627\u0641\u064a\u0629", "category_id": "custom_pro_6", "user_agent": "", "referer": "", "keys": {}}, {"name": "DISCOVER PAKISTAN \ud83c\uddf5\ud83c\uddf0", "icon": "https://iili.io/Cz6SVAx.png", "url": "https://ml-pull-dvc-myco.io:2096/DISCOVER_PAKISTAN/index.m3u8", "category_name": "\u0627\u0644\u0648\u062b\u0627\u0626\u0642\u064a\u0629 \u0648\u0627\u0644\u062b\u0642\u0627\u0641\u064a\u0629", "category_id": "custom_pro_6", "user_agent": "", "referer": "", "keys": {}}, {"name": "INTRAVEL \u2708\ufe0f", "icon": "https://iili.io/Cz6SVAx.png", "url": "https://amg00861-amg00861c10-rakuten-uk-3152.playouts.now.amagi.tv/playlist.m3u8", "category_name": "\u0627\u0644\u0648\u062b\u0627\u0626\u0642\u064a\u0629 \u0648\u0627\u0644\u062b\u0642\u0627\u0641\u064a\u0629", "category_id": "custom_pro_6", "user_agent": "", "referer": "", "keys": {}}, {"name": "WILD TV \ud83c\udf32", "icon": "https://iili.io/Cz6SVAx.png", "url": "https://dfhsahpa45kk2.cloudfront.net/scheduler/scheduleMaster/476.m3u8", "category_name": "\u0627\u0644\u0648\u062b\u0627\u0626\u0642\u064a\u0629 \u0648\u0627\u0644\u062b\u0642\u0627\u0641\u064a\u0629", "category_id": "custom_pro_6", "user_agent": "", "referer": "", "keys": {}}, {"name": "MBC 1 \ud83c\udfad", "icon": "https://iili.io/CK7B3G9.png", "url": "https://shd-gcp-live.edgenextcdn.net/live/bitmovin-mbc-1-na/eec141533c90dd34722c503a296dd0d8/index.m3u8", "category_name": "\u0627\u0644\u0642\u0646\u0648\u0627\u062a \u0627\u0644\u062a\u0631\u0641\u064a\u0647\u064a\u0629", "category_id": "custom_pro_7", "user_agent": "IPTV-Plus", "referer": "https://shahid.mbc.net", "keys": {}}, {"name": "MBC 2 \ud83c\udfac", "icon": "https://iili.io/CRgbxbS.png", "url": "https://shd-gcp-live.edgenextcdn.net/live/bitmovin-mbc-2/51db9d7fa48a27d051f1eecb68069151/index.mpd", "category_name": "\u0627\u0644\u0642\u0646\u0648\u0627\u062a \u0627\u0644\u062a\u0631\u0641\u064a\u0647\u064a\u0629", "category_id": "custom_pro_7", "user_agent": "IPTV-Plus", "referer": "https://shahid.mbc.net", "keys": {"e3ce77324a3d4fa2a913b26cc1976052": "17774f82a3b9e33ea7a149596acbb20f"}}, {"name": "MBC 4 \ud83c\udfa1", "icon": "https://iili.io/CRgmPMF.png", "url": "https://shd-gcp-live.edgenextcdn.net/live/bitmovin-mbc-4/24f134f1cd63db9346439e96b86ca6ed/index.m3u8", "category_name": "\u0627\u0644\u0642\u0646\u0648\u0627\u062a \u0627\u0644\u062a\u0631\u0641\u064a\u0647\u064a\u0629", "category_id": "custom_pro_7", "user_agent": "", "referer": "", "keys": {}}, {"name": "MBC 5 \ud83c\udf1f", "icon": "https://iili.io/CRgploP.png", "url": "https://shd-gcp-live.edgenextcdn.net/live/bitmovin-mbc-5/ee6b000cee0629411b666ab26cb13e9b/index.m3u8", "category_name": "\u0627\u0644\u0642\u0646\u0648\u0627\u062a \u0627\u0644\u062a\u0631\u0641\u064a\u0647\u064a\u0629", "category_id": "custom_pro_7", "user_agent": "", "referer": "", "keys": {}}, {"name": "MBC MASR 1 \u26a1", "icon": "https://iili.io/CK7zZ4S.png", "url": "https://shd-gcp-live.lg.mncdn.com/live/bitmovin-mbc-masr/956eac069c78a35d47245db6cdbb1575/index.m3u8", "category_name": "\u0627\u0644\u0642\u0646\u0648\u0627\u062a \u0627\u0644\u062a\u0631\u0641\u064a\u0647\u064a\u0629", "category_id": "custom_pro_7", "user_agent": "", "referer": "", "keys": {}}, {"name": "MBC MASR 2 \ud83d\udd25", "icon": "https://iili.io/CK7IN9e.png", "url": "https://shd-gcp-live.edgenextcdn.net/live/bitmovin-mbc-masr-2/754931856515075b0aabf0e583495c68/index.m3u8", "category_name": "\u0627\u0644\u0642\u0646\u0648\u0627\u062a \u0627\u0644\u062a\u0631\u0641\u064a\u0647\u064a\u0629", "category_id": "custom_pro_7", "user_agent": "", "referer": "", "keys": {}}, {"name": "MBC IRAQ \ud83c\uddee\ud83c\uddf6", "icon": "https://iili.io/CK7T9St.png", "url": "https://shd-gcp-live.edgenextcdn.net/live/bitmovin-mbc-iraq/e38c44b1b43474e1c39cb5b90203691e/index.m3u8", "category_name": "\u0627\u0644\u0642\u0646\u0648\u0627\u062a \u0627\u0644\u062a\u0631\u0641\u064a\u0647\u064a\u0629", "category_id": "custom_pro_7", "user_agent": "", "referer": "", "keys": {}}]);
      }
      if (url.pathname === "/v1/news" || url.pathname === "/news") {
        try {
          const res = await fetch("https://sportfeeds.gemini.media/yallakoraapi/NewsList?pageIndex=1&pageSize=14&otherSportsNews=false", {
            headers: {
              "User-Agent": "okhttp/4.10.0"
            }
          });
          if (res.ok) {
            const data = await res.json();
            if (Array.isArray(data)) {
              const mapped = data.map(item => {
                let img = "";
                if (item.Picture) {
                  img = item.Picture.ArabiaLargePath || item.Picture.MeduimPath || item.Picture.SmallPath || "";
                }
                let relativeDate = "اليوم";
                try {
                  const d = new Date(item.Date);
                  const diff = Date.now() - d.getTime();
                  const hours = Math.floor(diff / (1000 * 60 * 60));
                  if (hours < 24) {
                    relativeDate = hours <= 0 ? "الآن" : `منذ ${hours} ساعة`;
                  } else {
                    const days = Math.floor(hours / 24);
                    relativeDate = `منذ ${days} يوم`;
                  }
                } catch (de) {}
                
                return {
                  title: item.Title || "",
                  description: item.Description || "شاهد التفاصيل الكاملة لهذا الخبر الرياضي من خلال التطبيق.",
                  date: relativeDate,
                  image_url: img
                };
              });
              return respond(mapped);
            }
          }
        } catch (newsError) {
          console.error("News API failed:", newsError);
        }

        return respond([
          {
            "title": "مبابي يقود ريال مدريد للفوز في دوري أبطال أوروبا",
            "description": "سجل النجم الفرنسي كيليان مبابي هدفين رائعين ليقود الملكي لفوز مستحق.",
            "date": "اليوم",
            "image_url": "https://images.unsplash.com/photo-1508098682722-e99c43a406b2?w=500"
          },
          {
            "title": "برشلونة يستمر في صدارة الدوري الإسباني بالعلامة الكاملة",
            "description": "واصل النادي الكتالوني عروضه القوية واكتسح خصمه بأربعة أهداف نظيفة.",
            "date": "أمس",
            "image_url": "https://images.unsplash.com/photo-1540747737956-378724044432?w=500"
          },
          {
            "title": "الهلال يواصل سلسلة انتصاراته في دوري روشن السعودي",
            "description": "حقق الزعيم فوزاً مهماً بهدف دون رد ليحافظ على الصدارة المطلقة.",
            "date": "منذ يومين",
            "image_url": "https://images.unsplash.com/photo-1518063319789-7217e6706b04?w=500"
          }
        ]);
      }

      if (url.pathname === "/v1/matches" || url.pathname === "/matches") {
        try {
          const res = await fetch("https://api.myychann.site/api/v2/home.php?app_version=15", {
            headers: {
              "User-Agent": "okhttp/4.10.0"
            }
          });
          if (res.ok) {
            const body = await res.json();
            if (body.data && Array.isArray(body.data.sections)) {
              const sec = body.data.sections.find(s => s.type === "today_matches" || s.section_type === "today_matches");
              if (sec && Array.isArray(sec.items)) {
                const mappedMatches = sec.items.map(item => {
                  const channelName = item.channel_name || "";
                  let streamUrl = "https://live-football-2mf.pages.dev/index_bein%20max7.m3u8"; // default
                  
                  const cLower = channelName.toLowerCase();
                  if (cLower.includes("bein") || cLower.includes("بين")) {
                    if (cLower.includes("1")) streamUrl = "https://live-football-2mf.pages.dev/index_bein%20max7.m3u8";
                    else if (cLower.includes("2")) streamUrl = "https://live-football-2mf.pages.dev/index_bein%20max8.m3u8";
                    else if (cLower.includes("3")) streamUrl = "https://live-football-2mf.pages.dev/index_bein%20max9.m3u8";
                    else if (cLower.includes("4")) streamUrl = "https://live-football-2mf.pages.dev/index_bein%20max10.m3u8";
                    else if (cLower.includes("5")) streamUrl = "https://live-football-2mf.pages.dev/index_bein%20max11.m3u8";
                    else if (cLower.includes("6")) streamUrl = "https://live-football-2mf.pages.dev/index_bein%20max12.m3u8";
                  } else if (cLower.includes("alkass") || cLower.includes("الكاس")) {
                    if (cLower.includes("1")) streamUrl = "https://liveeu-gcp.alkassdigital.net/alkass1-p/main.m3u8";
                    else if (cLower.includes("2")) streamUrl = "https://liveeu-gcp.alkassdigital.net/alkass2-p/main.m3u8";
                    else if (cLower.includes("3")) streamUrl = "https://liveeu-gcp.alkassdigital.net/alkass3-p/main.m3u8";
                    else if (cLower.includes("4")) streamUrl = "https://liveeu-gcp.alkassdigital.net/alkass4-p/main.m3u8";
                    else if (cLower.includes("5")) streamUrl = "https://liveeu-gcp.alkassdigital.net/alkass5-p/main.m3u8";
                    else if (cLower.includes("6")) streamUrl = "https://liveeu-gcp.alkassdigital.net/alkass6-p/main.m3u8";
                  } else if (cLower.includes("abu dhabi") || cLower.includes("أبوظبي") || cLower.includes("ابو ظبي") || cLower.includes("أبو ظبي")) {
                    if (cLower.includes("1")) streamUrl = "https://live-football-2mf.pages.dev/index_AD%20sports1.m3u8";
                    else if (cLower.includes("2")) streamUrl = "https://live-football-2mf.pages.dev/index_AD%20sports2.m3u8";
                  } else if (cLower.includes("ssc") || cLower.includes("thmanyah") || cLower.includes("ثمانية")) {
                    if (cLower.includes("1")) streamUrl = "http://marveliptv.life/01112727740kh/khiary7740/474871";
                    else if (cLower.includes("2")) streamUrl = "http://marveliptv.life/01112727740kh/khiary7740/474867";
                    else if (cLower.includes("3")) streamUrl = "http://marveliptv.life/01112727740kh/khiary7740/474863";
                  } else if (cLower.includes("sharjah") || cLower.includes("الشارقة")) {
                    streamUrl = "http://marveliptv.life/01112727740kh/khiary7740/261524";
                  } else if (cLower.includes("iraqi") || cLower.includes("العراقية")) {
                    streamUrl = "http://marveliptv.life/01112727740kh/khiary7740/154339";
                  }

                  let arabStatus = "لم تبدأ";
                  const sUpper = (item.status || "").toUpperCase();
                  if (sUpper === "NS") {
                    arabStatus = "لم تبدأ";
                  } else if (sUpper === "FT") {
                    arabStatus = "انتهت";
                  } else if (["1H", "2H", "HT", "LIVE", "ET", "P", "PEN"].includes(sUpper)) {
                    arabStatus = "مباشر";
                  } else {
                    arabStatus = item.status || "لم تبدأ";
                  }

                  let teamALogo = "";
                  if (item.home_team && item.home_team.logo) {
                    teamALogo = item.home_team.logo.startsWith("http") ? item.home_team.logo : "https://api.myychann.site" + item.home_team.logo;
                  }
                  let teamBLogo = "";
                  if (item.away_team && item.away_team.logo) {
                    teamBLogo = item.away_team.logo.startsWith("http") ? item.away_team.logo : "https://api.myychann.site" + item.away_team.logo;
                  }

                  return {
                    team_a: item.home_team ? item.home_team.name : "",
                    team_b: item.away_team ? item.away_team.name : "",
                    team_a_logo: teamALogo,
                    team_b_logo: teamBLogo,
                    time: item.match_time || "",
                    tournament: item.league_name || "بطولة رياضية",
                    channel: channelName,
                    status: arabStatus,
                    stream_url: streamUrl
                  };
                });
                return respond(mappedMatches);
              }
            }
          }
        } catch (matchesError) {
          console.error("Matches API failed:", matchesError);
        }

        return respond([
          {
            "team_a": "ريال مدريد",
            "team_b": "برشلونة",
            "team_a_logo": "https://iili.io/CK75BIe.png",
            "team_b_logo": "https://iili.io/CK75iZu.png",
            "time": "10:00 م",
            "tournament": "الدوري الإسباني",
            "channel": "beIN Sports 1",
            "status": "مباشر",
            "stream_url": "https://live-football-2mf.pages.dev/index_bein%20max1.m3u8"
          },
          {
            "team_a": "ليفربول",
            "team_b": "مانشستر سيتي",
            "team_a_logo": "https://iili.io/CK77jSV.png",
            "team_b_logo": "https://iili.io/CK7c6Ux.png",
            "time": "08:30 م",
            "tournament": "الدوري الإنجليزي",
            "channel": "beIN Sports 2",
            "status": "لم تبدأ",
            "stream_url": "https://live-football-2mf.pages.dev/index_bein%20max2.m3u8"
          },
          {
            "team_a": "الأهلي",
            "team_b": "الزمالك",
            "team_a_logo": "https://iili.io/CKMJBjf.png",
            "team_b_logo": "https://iili.io/CKMJBjf.png",
            "time": "07:00 م",
            "tournament": "الدوري المصري",
            "channel": "أون تايم سبورتس",
            "status": "انتهت",
            "stream_url": "https://live-football-2mf.pages.dev/index_bein%20max3.m3u8"
          }
        ]);
      }

      if (url.pathname === "/v1/slider") return respond(sliderImages);

      return respond({ ok: true, service: "LIVE STREAM PREMIUM API" });
    } catch (e) {
      return respond({ ok: false, message: "Server error: " + e.message }, 500);
    }
  }
};
