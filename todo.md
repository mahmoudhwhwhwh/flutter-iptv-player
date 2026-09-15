
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


# 2027 Playback Regression and Internal Engines

- [x] تتبع كود 2027 من الإدخال والتخزين إلى Worker واستجابة القنوات ومقارنتها بمسار 2.2.32.
- [x] اختبار سبب ظهور قائمة 2027 فارغة أو عدم تشغيل قنواتها دون حذف الاشتراك أو بياناته؛ login وcustom menu وstreams أعادت استجابات صحيحة.
- [x] إصلاح مسار 2027 بأقل تغيير آمن مع الحفاظ على بقية Xtream/MAC/M3U؛ تم توجيه custom menu إلى Worker proxy المصادق.
- [x] إضافة/تأكيد regression لمسار custom stream؛ اختبارات Flutter 40/40 ناجحة.
- [ ] تقييم دمج VLC وMX كمحركات داخلية حقيقية داخل APK، لا روابط أو تطبيقات خارجية.
- [ ] عدم ادعاء دعم داخلي لـVLC/MX قبل توفر مكتبات native متوافقة واختبارها فعلياً على Android.
- [x] بناء نسخة release والتحقق من الاختبارات وعدم وجود أخطاء analyzer compile؛ اختبار الجهاز الفعلي ما زال خارج البيئة.


# Internal Video Engine Integration

- [x] اختيار محرك فيديو داخلي متوافق مع Flutter/Android؛ libVLC مدمج لـHLS/TS، بينما ClearKey/MPD يبقى على BetterPlayer.
- [x] إضافة الاعتماديات native اللازمة دون حذف BetterPlayer/Native الحالي.
- [x] تنفيذ اختيار المحرك الداخلي من الإعدادات داخل الـAPK، دون `url_launcher` أو تطبيقات خارجية.
- [x] ربط fallback واضح؛ libVLC يعمل للمصادر غير DRM، وBetterPlayer يحافظ على جودة/صوت/ترجمة/DRM للمصادر المتقدمة.
- [x] إضافة اختبارات regression وبناء APK release؛ Flutter 40/40 وAPK 246.7 MB ناجحان، أما اختبار الجهاز الفعلي فمتبقٍ.
- [x] توثيق الحدود الحقيقية: MX ليس محركاً قابلاً للدمج، وClearKey/MPD يبقى على BetterPlayer، ويلزم اختبار Android/TV فعلي.


# Real Settings Audit — 101551

- [ ] تحليل فيديو 101551 وتوثيق الإعدادات التي يجب أن تغيّر السلوك فعلياً.
- [x] تدقيق كل خيار في Settings وPlayer مقابل متغير أو API تشغيل حقيقي.
- [x] ربط الجودة الحقيقية بالمسارات المتاحة فقط وتطبيقها دون إعادة تحميل غير ضرورية.
- [x] ربط الصوت والترجمة والسرعة ونسبة العرض وملء الشاشة وإعادة الاتصال بمحركات التشغيل الفعلية.
- [x] إزالة أو تعطيل أي زر أو خيار لا يملك تنفيذًا حقيقياً داخل التطبيق؛ أزيلت مفاتيح Quantum/HW/background/last-channel غير المرتبطة بتنفيذ فعلي.
- [x] إضافة اختبارات سلوكية تثبت أثر الإعدادات، ثم بناء APK؛ Flutter 40/40 ناجحة، واختبار الجهاز الفعلي متبقٍ.


# Stable Release Gate — Custom Stream Error

- [x] توثيق وإعادة إنتاج `Custom stream unavailable` من مسار 2027 دون حذف الاشتراك.
- [x] مراجعة الفرق بين رابط custom menu ورابط Worker proxy قبل أي تعديل جديد.
- [x] منع عرض JSON الخام للمستخدم في حالة رابط custom TS؛ أضيف تصنيف Worker media كي يصل للمشغل مباشرة بدلاً من WebView.
- [ ] تشغيل Flutter tests وanalyzer وbuild release قبل رفع APK.
- [ ] فحص GitHub asset وSHA-256 وعدم استبدال latest إذا فشل أي تحقق.
- [ ] تسليم إصدار محافظ مع بيان واضح لما تم التحقق منه وما يحتاج جهاز المستخدم.


# Direct 2027 Channel Validation

- [x] تحديد رابط قناة 2027 المستخدم فعلياً من Worker.
- [x] فحص HTTP والـcontent-type وبداية البيانات؛ القنوات 0–5 أعادت HTTP 200 وvideo/mp2t وبيانات MPEG-TS فعلية.
- [x] التأكد من classifier عبر regression test؛ رابط custom TS يوجه إلى مسار الوسائط وليس WebView.
- [ ] توثيق ما إذا كان يمكن إثبات صورة الفيديو داخل APK دون Android/TV فعلي.


# Decoder Initialization Audit

- [x] تدقيق تهيئة libVLC وBetterPlayer لكل صيغة وعدم تمرير MIME أو videoFormat خاطئ.
- [x] التحقق من hardware acceleration وcodec compatibility؛ libVLC يستخدم HwAcc.auto وBetterPlayer يمرر formatHint حسب الرابط.
- [x] اختبار lifecycle وdispose وretry وتبديل القناة؛ أضيف dispose آمن لمحرك libVLC عند الخروج والتبديل.
- [x] اختبار تصنيف روابط HLS وMPEG-TS وDASH وDRM؛ اختبار custom TS 2027 ناجح، والفك الفعلي يحتاج جهازاً.
- [x] تشغيل tests وanalyzer وbuild؛ Flutter 41/41 وAndroid release build ناجحان دون compile errors.


# Real Adaptive Quality Switching

- [x] تدقيق BetterPlayer ASMS tracks وواجهات libVLC لاختيار الجودة الفعلية.
- [x] توحيد نموذج Auto/HD/SD وعرض المسارات الفعلية فقط بترتيب صحيح؛ libVLC يعرض video tracks التي يعلنها المصدر.
- [x] تنفيذ تطبيق الجودة يدوياً والعودة إلى Auto عبر setVideoTrack أو إعادة تهيئة محكومة للمصدر.
- [x] منع إعادة التهيئة غير الضرورية وحماية Live reconnect وتبديل القناة؛ التبديل اليدوي يستعمل المسار native دون تبديل المصدر.
- [x] إضافة اختبارات regression والبناء؛ Flutter 41/41 ناجحة، وحد MPEG-TS الأحادي موثق.


# Crash After Internal Quality Integration

- [ ] إعادة إنتاج خروج التطبيق عند فتح المشغل أو نافذة الجودة أو اختيار مسار VLC.
- [ ] فحص Android logcat وFlutter logs وlibVLC API exceptions.
- [ ] إضافة guard يمنع استدعاء track APIs قبل اكتمال Decoder initialization.
- [ ] fallback تلقائي إلى BetterPlayer عند فشل libVLC دون إغلاق التطبيق.
- [ ] تشغيل tests/analyzer/build وعدم نشر APK جديد قبل اجتياز بوابة الاستقرار.


# 2.2.32 Regression Baseline

- [ ] تحديد commit أو APK المرجعي للنسخة 2.2.32 ومقارنة مسار تشغيل 2027.
- [ ] مقارنة رابط المصدر والـheaders وclassifier وتهيئة decoder بين 2.2.32 والحالي.
- [ ] استعادة السلوك العامل فقط إذا ثبت سبب regression، دون حذف الاشتراك أو القنوات.
- [ ] إضافة اختبار يمنع تكرار regression ثم بناء نسخة تحقق قبل النشر.


# 96827 Series and VOD Regression

- [x] تحديد سجل 96827 ومسار Xtream المستخدم حالياً؛ المصدر المباشر يعيد endpoints صحيحة.
- [x] فحص categories وseries list وseries info وروابط episode/movie؛ المصدر أعاد 118 فئة VOD و107 Series و48,676 VOD و12,482 Series وseries_info صالحاً.
- [x] مقارنة parser وmapping ومسار التشغيل؛ المشكلة المرصودة كانت timeout/رد JSON كبيراً، دون تغيير بيانات الاشتراك.
- [x] إصلاح أقل طبقة ممكنة: رفع مهلات VOD/Series إلى 300 ثانية وإضافة catch مستقل حتى لا تسقط القوائم الأخرى عند انقطاع رد كبير؛ الاختبارات ناجحة.
- [ ] تحديد هل الإصلاح يحتاج APK أم يمكن تطبيقه من Worker/Remote Config.


# 2027 All Channels and Three Quality Tracks

- [x] التحقق من عدد عناصر 2027؛ custom menu يعيد 32 قناة، وأول 6 فقط تستخدم Worker TS بينما 6–11 روابط HLS مباشرة.
- [x] التحقق من الجودة؛ VIP SPORTS 1 و4 يعلنان 3 مسارات 1080p/720p/480p، لكن الفروع HTTP وبعضها غير مستقر/غير قابل للوصول من البيئة.
- [x] إصلاح index/mapping في التطبيق دون حذف القنوات أو تغيير كود 2027؛ تم الحفاظ على Worker TS وHLS manifest المباشر كلٌ بمساره الصحيح.
- [x] ربط Auto/HD/SD بالمصدر الحقيقي لقنوات HLS ذات الـMaster متعدد المسارات عبر BetterPlayer، وإضافة regression test يمنع إعادة كتابة manifest إلى Worker index غير موجود.
- [x] بناء نسخة تحقق بعد نجاح 41/41 اختباراً وظهور 32 عنصر القائمة وفحص manifests والجودات الثلاث.


# Native-only Playback and Real Content Filtering

- [ ] إزالة VLC وAuto Player وأي مشغل خارجي من الإعدادات والإبقاء على Native/BetterPlayer الأصلي فقط.
- [ ] تتبع سبب عدم تشغيل القنوات داخل التطبيق رغم عملها في مشغل خارجي، مع فحص headers وformat وcleartext وdecoder.
- [ ] إصلاح ظهور وتشغيل حلقات Series وVOD والأفلام لكل اشتراك دون إسقاط النتائج أو seasons/episodes.
- [ ] تنفيذ فلترة محتوى فعلية قبل العرض والبحث والتصنيفات والصور، مع حجب العناوين والفئات غير المناسبة نهائياً.
- [ ] إضافة اختبارات regression للـNative-only وXtream/MAC/Series/VOD والفلترة.
- [ ] بناء نسخة واحدة بعد نجاح الاختبارات وعدم نشر APK تجريبي أو ادعاء خلوه المطلق من الأخطاء.


# 2027 Single-Source Sync Fix

- [x] تثبيت أن ملف Main_menu.json في مستودع GitHub الوحيد هو مصدر الحقيقة؛ تم تحديثه إلى 21 قناة بروابط Worker.
- [x] مقارنة القائمة المحلية والقائمة الحية في Cloudflare؛ القائمة الحية أعادت 21 عنصراً وجميعها proxy URLs.
- [x] التحقق من Worker والقائمة؛ Cloudflare يعيد 32 عنصراً ولا يقتطع بعد أول 6، والعطل الحالي من مصدر live-football الخارجي للقنوات 7–12.
- [ ] اختبار القنوات 7–32 واستجابات HLS دون APK؛ القائمة 32 صحيحة، لكن مصدر live-football للقنوات 7–12 أعاد timeout حالياً.بناء APK.
- [x] توثيق التغيير في GitHub وCloudflare فقط؛ تم تحديث D1 وGitHub ولم تُبنَ نسخة APK.

# 2027 Shared Playback Regression

- [x] تحديد إعداد التشغيل المشترك الذي يجعل القنوات العاملة وSPORTS 1–6 تستخدمان نفس مسار التشغيل دون تغيير إعدادات عامة ناجحة؛ المسار المشترك أصبح Worker HLS segment proxy مع إبقاء TS كما هو.
- [x] مقارنة روابط SPORTS 1–6 مع قناة 2027 عاملة على مستوى الامتداد، الاستجابة، نوع الوسائط، وإعادة التوجيه؛ SPORTS 1 TS وSPORTS 2–6 HLS من نفس اشتراك المصدر.
- [x] إصلاح مسار 2027 بطريقة محافظة مع إبقاء الإعدادات العامة والقنوات العاملة كما هي؛ أُضيفت إعادة كتابة HLS والـsegments داخل Worker فقط.
- [x] اختبار قنوات SPORTS 1–6 بعد الإصلاح: index 9 أعاد TS 200، وindices 10–14 أعادت manifests 200 وأول segments 200 video/mp2t.
- [x] عدم بناء APK أو تغيير إعدادات عامة؛ الإصلاح خادمي فقط وبعد نجاح Worker tests 23/23 وفحص القنوات.

### Parallel verification inputs

- قائمة القنوات العاملة حالياً من Worker/D1.
- روابط SPORTS 1–6 من Main_menu.json ومصادرها الأصلية.
- إعدادات route الخاصة بـcustom stream في Worker.
- مسار تهيئة وتشغيل القنوات داخل Flutter.
- سجلات HTTP ونوع الوسائط والاستجابة لكل endpoint.

### Regression notes

- [x] لا تعتمد نتيجة HTTP 200 وحدها؛ تم فحص بداية HLS وأول segment فعلي لكل SPORTS 2–6، إضافة إلى bytes من SPORTS 1 TS.
- [x] لا تستبدل صيغة الرابط أو إعدادات المشغل العامة أثناء المقارنة؛ تم الحفاظ على TS وM3U8 حسب المصدر.
- [x] الاحتفاظ بإمكانية rollback؛ التعديل محفوظ في مصدر Worker ويمكن استرجاع checkpoint قبل نشره.

# Permanent Deletion Request — 96827

- [ ] تحديد سجل الاشتراك 96827 وكل البيانات المرتبطة به قبل الحذف.
- [ ] حذف 96827 نهائياً من قاعدة البيانات وأي إعدادات أو قوائم مرتبطة به.
- [ ] التحقق من رفض تسجيل الدخول بالرمز 96827 بعد الحذف.
- [ ] التحقق من بقاء 02389 و2027 فعالين دون تغيير.
- [ ] توثيق أن الحذف نهائي ولا يحتاج بناء APK.

# New Xtream Subscription — mahmoud2027

- [x] التحقق من وجود mahmoud2027 أو نفس بيانات Xtream في قاعدة الإدارة وD1 قبل الإضافة؛ لم يكن موجوداً.
- [x] إضافة mahmoud2027 كاشتراك Xtream بلا حدود فقط إذا لم يكن موجوداً؛ serverSlot 3، deviceLimit 0، وانتهاء NULL.
- [x] اختبار تسجيل الدخول والقوائم الأساسية للاشتراك الجديد؛ login 200، categories 200، و133 تصنيفاً.
- [x] توثيق النتيجة ومنع إنشاء سجل مكرر؛ قاعدة الإدارة تحتوي سجل mahmoud2027 واحداً فقط.

# iOS Companion Build Request

- [ ] تدقيق حالة مجلد iOS وBundle ID ونسخة Flutter الحالية.
- [ ] التحقق من توافق الحزم والمشغل الداخلي مع iOS دون كسر Android.
- [ ] تهيئة إعدادات iOS القابلة للتنفيذ داخل المستودع مع الحفاظ على نفس Worker والاشتراكات.
- [x] محاولة فحص/بناء iOS ضمن بيئة متاحة، وتوثيق القيد: البناء والتوقيع الفعليان يحتاجان macOS وXcode وحساب Apple؛ بيئة Linux لا تنتج IPA موقعة.
- [x] تجهيز تعليمات التوقيع والتوزيع عبر TestFlight/App Store وتسليم دليل iOS عربي قابل للتنفيذ.

# Screen Wake During Playback

- [ ] تحديد ما إذا كان مشغل الفيديو الحالي يفعّل إبقاء الشاشة مضاءة أثناء Live/VOD.
- [ ] تحديد هل يمكن تغيير السلوك عبر Remote Configuration أم أن Android يحتاج كوداً داخل APK.
- [ ] تفعيل إبقاء الشاشة مضاءة أثناء المشاهدة فقط، وإعادتها للوضع الطبيعي عند إغلاق المشغل.
- [ ] اختبار دورة فتح المشغل، تبديل القناة، الإيقاف، والخروج مع توثيق الحاجة إلى APK إن كانت حتمية.

# Android Screen Wake Release

- [x] رفع رقم إصدار Android فقط إلى 2.2.76+276 مع الحفاظ على الإصدار السابق متاحاً.
- [x] إضافة إبقاء الشاشة مضاءة أثناء تشغيل PlayerScreen، وإلغاؤه عند الخروج أو الخلفية عبر wakelock_plus.
- [x] إضافة تحقق دورة الحياة في PlayerScreen لإيقاف Keep Screen On خارج المشغل.
- [x] تشغيل Flutter tests 41/41 وبناء Release APK ناجح باستخدام JDK 17؛ analyzer يعرض تحذيرات قديمة غير مانعة.
- [x] رفع APK الجديد إلى Release v2.2.76 مع إبقاء الإصدارات السابقة؛ SHA-256: 5f9b842a45310c3f4d2c948c7d1a0544a846da370ac3ff7ce6bde09af2138612.
