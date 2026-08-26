
- [x] إضافة إشعار منبثق عربي يوضح سبب تفعيل Lite Mode تلقائياً عند أول تشغيل فقط.
- [x] اختبار عدم تكرار الإشعار عند التشغيلات اللاحقة، وعدم ظهوره عند التفعيل اليدوي أو الأجهزة غير الضعيفة؛ اختبارات Lite Mode 16/16.
- [x] بناء ورفع النسخة المحدثة بعد اكتمال الاختبارات؛ APK 2.2.52+252 مرفوع إلى GitHub latest.

- [x] تصميم شاشة دخول وترحيب فاخرة ومميزة عند بداية تشغيل التطبيق.
- [x] إنشاء فيديو افتتاحي قصير مناسب للعلامة التجارية وإدماجه بطريقة لا تثقل التطبيق؛ مدة الفيديو 6 ثوانٍ وحجمه نحو 1.6MB.
- [x] إضافة خيارات عرض 4K و8K داخل المشغل مع توضيح أنها لا ترفع الدقة الحقيقية إذا كان المصدر أقل.
- [x] تطبيق اختيار الجودة بأمان على مسارات المصدر الفعلية دون التأثير على تشغيل القنوات أو الأجهزة الضعيفة.
- [x] إضافة اختبارات لمنطق الجودة؛ نجحت جميع اختبارات Flutter 18/18، وبُني APK 2.2.52+252 ورُفع إلى GitHub latest.

- [x] إضافة انتقال تلاشي سينمائي عند انتهاء فيديو الترحيب أو الضغط على تخطي.
- [x] احترام Lite Mode وتقليل الحركة على الأجهزة الضعيفة.
- [x] اختبار اكتمال الانتقال وبناء ورفع الإصدار الجديد؛ نجحت اختبارات Flutter 20/20 وبُني APK 2.2.53+253.

- [x] إضافة زرين مستقلين وواضحين داخل أدوات المشغل باسم 4K و8K لفلتر صورة البث الحي.
- [x] تطبيق تحسين بصري فعلي للصورة عند اختيار الفلتر مع حماية أداء Lite Mode؛ ColorFiltered بمصفوفات تحسين مختلفة.
- [x] اختبار الأزرار على مسار البث الحي وبناء ورفع الإصدار الجديد؛ اختبارات الجودة والبناء والرفع ناجحة.

- [x] مراجعة وتثبيت جميع الإضافات الأخيرة في نسخة واحدة متوافقة مع GitHub الخاص وCloudflare.
- [x] إصلاح الاختبارات أو أخطاء التكامل المتبقية قبل البناء النهائي؛ نجحت جميع اختبارات Flutter 20/20.
- [x] التحقق من مسارات 2027 وتسجيل الدخول والقوائم عبر Worker ثم بناء ورفع النسخة المستقرة؛ config/login HTTP 200 وAPK 2.2.53+253 مرفوع.


# v2.2.61 Audit

- [x] Fix Xtream HTTP/Worker gateway mismatch causing black playback and empty content on legacy saved subscriptions
- [x] Add explicit player load failure feedback and retry action instead of silently closing
- [x] Harden series season/episode normalization across Xtream response variants
- [ ] Improve poster loading and metadata request performance without hiding content
- [x] Add regression tests for series normalization; player/gateway behavior covered by static code path and release build
- [ ] Run end-to-end verification for Xtream, Stalker, and custom-menu flows
- [x] Build release APKs for 2.2.61+261 and upload direct download artifacts


# Real Quality Selector Revision

- [x] Replace the separate 4K/8K visual-filter buttons with one real stream-quality button
- [x] Read only actual HLS/DASH variant tracks and switch the BetterPlayer track without faking unavailable resolutions
- [x] Match the Arabic RTL quality dialog layout shown in the supplied reference image
- [x] Add regression tests for real track extraction and selection behavior
- [x] Build release APK 2.2.62+262; live playback verification remains pending


# Blocking Regression Report

- [ ] Reproduce and fix the current all-content playback failure reported for live, VOD, and Series on a real Android device
- [x] Verify the new APK build contains the latest Worker/gateway and real quality-selector code; previous installed APK was stale
- [x] Fix series detail requests so the real Worker response produces visible seasons and episodes; verified code 02389 / series 6264
- [x] Remove fake 4K/8K quality labels and keep one real source-track selector matching the reference
- [ ] Do not mark release fully verified until at least one live stream, one movie, and one series episode are verified end-to-end


# v2.2.62 Blocking Playback Failure

- [ ] Trace the exact live/VOD/episode URL passed from the provider into BetterPlayer
- [ ] Verify Worker media routes and required auth/query parameters against the URL builder
- [ ] Fix the common playback route without breaking Xtream, Stalker, custom, or DRM sources
- [ ] Verify series detail and episode playback on the installed-version code path
- [ ] Run real-source smoke tests before building another APK


# Real Multi-Quality Regression

- [ ] Reproduce missing HLS/DASH quality tracks for LSP-9I6H6H6Z9C, 02389, 96827, and 2027
- [ ] Ensure the final media URL preserves the manifest format and BetterPlayer ASMS track discovery
- [ ] Keep one quality button and show only source-announced variants, including bitrate and resolution
- [ ] Test quality discovery on a real HLS/DASH manifest before issuing another APK


# Playback Failure Investigation

- [ ] Trace and fix the common media URL/redirect failure for live channels, movies, and series episodes
- [ ] Verify source authorization and CDN redirect behavior through Worker without exposing credentials
- [ ] Confirm at least one real live stream, one movie, and one episode return playable media responses
- [ ] Build a new APK only after real-source smoke tests pass


# Distribution Regression

- [ ] Build and upload the universal app-release.apk referenced by the Worker update URL
- [ ] Confirm the universal APK contains the single real quality selector and latest playback fixes
- [ ] Verify the final APK version and artifact checksum before delivery


# IPTV Smarters Compatibility Audit

- [ ] Compare Flutter's Xtream/Stalker requests with the standard IPTV Smarters request contract
- [ ] Preserve source-provided stream URLs, extensions, query tokens, headers, and cookies end-to-end
- [ ] Fix common player initialization differences that block live, movie, and episode playback
- [ ] Verify VOD/Series parsing against real Xtream response shapes used by the subscriptions


# Playback Compatibility Continuation

- [ ] Compare the exact final media URL and headers used by the app against IPTV Smarters-compatible Xtream/Stalker contracts
- [ ] Fix any lost redirect token, cookie, User-Agent, Referer, Range, or content-type handling
- [ ] Verify a playable live stream, movie, and episode before marking the release stable


# v2.2.73 MAC/VOD/Series Hardening

- [x] إصلاح جلب تفاصيل Series في Stalker/MAC عبر عقد `type=series&action=get_ordered_list` مع استخراج الموسم والحلقات الفعلية.
- [x] دعم IDs بصيغة `seriesId:seasonId` وعدم تمريرها إلى Xtream `player_api.php`.
- [x] الحفاظ على أوامر Stalker المشفرة/المحوّلة من Worker أثناء تشغيل حلقات VOD/Series.
- [x] إضافة اختبارات regression لمسار MAC Series وتحليل المعرّفات.
- [x] مراجعة وتطبيق تدابير حماية واقعية لا تكسر التشغيل: redacted diagnostics، منع cleartext حيث يمكن، وفحوص سلامة غير مدمرة.
- [x] تشغيل اختبارات Flutter وWorker وفحص TypeScript، ثم بناء APK universal 2.2.73 بعد نجاحها؛ Flutter 38/38 وWorker 21/21 وTypeScript ناجحة، وAPK 61.8MB مبني.
- [x] مزامنة رقم الإصدار والبصمة مع Worker/D1/MySQL ولوحة الإدارة؛ GitHub latest SHA-256: 66f4b0c835d22708c922b036da0b63a041ab0009f9e20043a70c4f9902df8765، وMySQL app_settings إلى 2.2.73/273.
- [ ] إبقاء تحقق التشغيل على جهاز Android فعلي كتحقق خارجي، وعدم وصفه بأنه ناجح دون جهاز فعلي.


# Live Reconnect UX Match — 101543

- [x] تحليل فيديو 101543 وتوثيق تسلسل توقف القناة وإعادة الاتصال الظاهر للمستخدم.
- [x] إبقاء نفس القناة ونفس شاشة المشغل أثناء reconnect وعدم الرجوع للقائمة.
- [x] إظهار حالة اتصال خفيفة وغير نهائية بدلاً من شاشة Playback failure أثناء المحاولات.
- [x] إعادة المحاولة عند توقف البث أو انقطاع الشبكة مع backoff وإلغاء آمن عند تبديل القناة/الخروج.
- [ ] إضافة اختبار regression ثم بناء APK فقط إذا تغير السلوك، وتوثيق أن المصدر المتوقف لا يمكن إصلاحه من داخل التطبيق.


# Full Premium Settings and Player Scope — pasted_content.txt

- [x] تدقيق بنية التطبيق الحالية، المشغل Native/BetterPlayer، مصادر Xtream وMAC/M3U، والإعدادات الموجودة قبل التعديل.
- [x] إضافة نموذج محفوظ للمشغل الافتراضي: Native Player، VLC، MX Player، مع Auto Player واضح وحالة الاختيار الحالي.
- [x] إضافة إعداد صيغة البث الافتراضي Auto مع HLS/M3U8 وMPEG-TS والصيغ المدعومة فعلياً، دون إجبار الرابط على صيغة خاطئة.
- [x] تنفيذ Auto Player بتحليل الرابط/الامتداد/الصيغة، مع fallback محدود وآمن وعدم إظهار أخطاء تقنية غير مفهومة.
- [x] الحفاظ على Native Player الحالي وكل وظائف Live/VOD/Series/DRM/quality/reconnect دون حذف.
- [x] تصميم وتنفيذ صفحة إعدادات Premium منظمة RTL بالعربية والإنجليزية، مناسبة للمس والريموت وAndroid TV focus.
- [x] إضافة إعدادات التشغيل والترجمة والواجهة والتخزين/الأداء المطلوبة مع حفظها محلياً بصورة آمنة.
- [ ] تحسين التنقل والقوائم عبر lazy loading وcache وimage cache وpagination/debounced search وعدم إعادة جلب البيانات عند الرجوع.
- [ ] إضافة placeholders ومعالجة صور القنوات والأفلام والمسلسلات الفاشلة دون مربعات فارغة.
- [x] إضافة fallback خارجي واضح لـVLC/MX فقط عندما يسمح النظام، مع عدم ادعاء تشغيل داخلي لا توفره المكتبات الحالية.
- [x] إضافة اختبارات regression للإعدادات، الصيغ، Auto Player، fallback، reconnect، الحفظ، والقوائم.
- [x] تنفيذ build/release؛ APK release بُني بنجاح، أما التحقق الفعلي من M3U8 وMPEG-TS وMP4 وHTTP/HTTPS وLive/VOD/Series فيحتاج أجهزة ومصادر تشغيل فعلية.
- [x] إعداد تقرير نهائي يميز ما تم تنفيذه فعلياً وما يحتاج جهاز Android/TV أو مكتبات/مفاتيح توقيع خارجية.


# Professional Quality Dialog — User Request

- [x] تدقيق نافذة الجودة الحالية وBetterPlayer ASMS video/audio/subtitle tracks.
- [x] بناء نافذة جودة Premium فوق الفيديو بخلفية خافتة، تبويبات فيديو/صوت/ترجمة، وحركة Fade وإغلاق خارج النافذة.
- [x] عرض Auto أولاً ثم المسارات الحقيقية فقط بترتيب تنازلي للدقة والـbitrate مع Radio Buttons وحالة محددة فورية.
- [x] إضافة Cancel وApply/OK؛ Cancel لا يغير شيئاً وApply يطبق المسار الحقيقي دون إعادة تحميل غير ضرورية.
- [x] إضافة Hover/focus واضح وتخطيط متجاوب للهاتف والتابلت والكمبيوتر وAndroid TV/الريموت.
- [x] الحفاظ على وظائف التشغيل وملء الشاشة والصوت والترجمة وLive reconnect وعدم التأثير عليها.
- [x] إضافة اختبارات جودة regression وتشغيل analyzer/build release؛ Flutter tests 40/40 وAPK release ناجح، والتحقق البصري/الجهاز الفعلي ما زال خارج البيئة.
