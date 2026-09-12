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
          app_version: "2.2.81",
          disable_vpn_check: true,
          disable_sniffer_check: true,
          slider: sliderImages,
          // Credentials are never exposed from the public config endpoint.
          servers: [],
          // Legacy and redacted builds remain blocked; active builds use D1 login.
          blocking: {
            min_version_code: 281,
            blocked_version_codes: [125, 130, 140, 144, 205, 211, 212, 233, 234, 277, 278, 279, 280],
            block_message: "يرجى التحديث إلى الإصدار v2.2.81 للاستمرار."
          },
          update: {
            latest_version: "v2.2.81",
            apk_url: "https://iptv-subscription-api.tvkora56.workers.dev/v1/download",
            update_message: "يتوفر الآن LIVE STREAM PREMIUM v2.2.81 مع مصادقة الاشتراكات عبر Cloudflare D1 وحماية بيانات الخوادم."
          }
        });
      }

      if (url.pathname === "/v1/download") {
        const apkUrl = "https://github.com/mahmoudhwhwhwh/flutter-iptv-player/releases/download/v2.2.81/LIVE_STREAM_PREMIUM.apk";
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
