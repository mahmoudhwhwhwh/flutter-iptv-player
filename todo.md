
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
