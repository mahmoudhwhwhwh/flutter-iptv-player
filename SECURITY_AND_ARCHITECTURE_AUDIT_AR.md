# تقرير التدقيق الأمني والتقني

## نطاق المراجعة

تمت مراجعة مستودع `mahmoudhwhwhwh/flutter-iptv-player`، تطبيق Flutter، Worker الخاص بـ Cloudflare، مسار تسجيل الاشتراكات، GitHub Actions، وإعدادات التوزيع العامة. هذه المراجعة لا تنفذ تغييرات على المستخدمين أو الاشتراكات.

## الخلاصة التنفيذية

المشروع قابل للتطوير، لكن لا أنصح بإطلاق لوحة إدارة الاشتراكات فوق البنية الحالية مباشرة. الأولوية القصوى هي إزالة بيانات دخول خوادم IPTV من الكود والـ Worker، لأن endpoint الإعدادات العامة يعيد هذه البيانات لأي زائر. بعد ذلك يجب حماية API وإضافة إدارة أجهزة فعلية، ثم بناء لوحة الإدارة خلف مصادقة قوية وصلاحيات محددة.

يوجد أيضاً انفصال بين ما هو موجود في GitHub وما هو منشور فعلياً على Cloudflare: المستودع يحتوي على إصدار `2.2.87+287` وRelease ناجح، بينما الإعداد المنشور يعيد `min_version_code=286` و`latest_version=v2.2.86`. لذلك لا ينبغي اعتبار النسخة متزامنة حتى يتم إصلاح Cloudflare والتحقق من رابط التحديث من جهاز غير مسجل الدخول إلى GitHub.

## المخاطر الحرجة

| الأولوية | المشكلة | الدليل | الأثر | الإجراء المطلوب |
|---|---|---|---|---|
| حرجة | بيانات دخول IPTV موجودة نصاً داخل Worker وGit history | `worker.js:40-253` يحتوي hosts وusernames وpasswords | أي شخص لديه وصول للكود أو endpoint يستطيع استخدام الخوادم، وقد تتسرب الحسابات أو تتوقف الخدمة | تدوير جميع كلمات المرور/الحسابات فوراً، حذفها من الكود، تخزينها في D1 أو Secrets، وإرجاع أقل قدر ممكن للتطبيق |
| حرجة | `/v1/config` عام ويعيد قائمة الخوادم وبيانات الاعتماد | `worker.js:31-265` و`Access-Control-Allow-Origin: *` | كشف جماعي للخوادم والحسابات، scraping واستنزاف الموارد | اجعل الإعدادات العامة لا تحتوي أسراراً، واربط بيانات الخادم بطلب login صالح فقط |
| حرجة | رابط التحديث يعتمد على GitHub الخاص | الإعداد المنشور يعيد `releases/latest/download/LIVE_STREAM_PREMIUM.apk` والمستودع Private | المستخدمون العاديون يحصلون على 404 ولا يستطيعون التحديث | رفع APK إلى R2 برابط عام موقّع/عام، أو جعل مستودع التوزيع عاماً منفصلاً عن مستودع المصدر |
| عالية | لا يوجد تطبيق فعلي لـ `device_id` و`max_devices` في Worker المنشور | `worker.js:291-339`: تتم قراءة القيم لكن لا يتم تسجيل الجهاز أو رفض الأجهزة الزائدة | مشاركة كود الاشتراك على عدد غير محدود من الأجهزة | إنشاء جدول devices، تسجيل أول جهاز، فرض الحد، وإتاحة reset من اللوحة مع audit log |
| عالية | لا توجد حماية واضحة من brute force على `/v1/login` | `worker.js:291-309` يقبل محاولات غير محدودة ولا يوجد rate limit | تخمين الأكواد، استنزاف D1، وتسهيل إساءة الاستخدام | Cloudflare Rate Limiting/WAF، سجل محاولات، backoff، ورسائل موحدة |
| عالية | SHA-256 مباشر لأكواد الاشتراك | `worker.js:10-14` و`306` | إذا تسربت قاعدة D1 يمكن اختبار الأكواد الضعيفة offline | استخدم أكواداً عشوائية عالية entropy، ويفضل HMAC/pepper داخل Secret مع تدوير آمن |
| عالية | التطبيق يسمح بالـ HTTP cleartext على مستوى عام | `AndroidManifest.xml` و`network_security_config.xml:4-12` | اعتراض أو تعديل قوائم/روابط وبيانات اعتماد عند استخدام HTTP | منع cleartext افتراضياً، والسماح بنطاقات IPTV محددة فقط عند الضرورة، وإظهار تحذير للمصادر غير الآمنة |
| عالية | الأسرار وملفات البيئة ليست مفصولة جيداً عن المستودع | `android/local.properties` و`google-services.json` tracked، وبيانات الخوادم في `worker.js` | صعوبة تدوير الأسرار واحتمال تسرب إعدادات البناء | إزالة local.properties من Git، مراجعة Firebase key restrictions، وتفعيل secret scanning |

## مشاكل عالية التأثير غير الأمنية مباشرة

### عدم تزامن الإصدارات

المستودع يعلن `pubspec.yaml` كنسخة `2.2.87+287`، وGitHub Release موجود، لكن `android/gradle.properties` ما زال يحتوي قيماً قديمة (`2.2.62` و`262`). صحيح أن Workflow يمرر build-name/build-number أثناء البناء، لكن وجود مصادر متعددة للإصدار يسبب أخطاء في التشخيص والحظر والتوزيع. يجب اعتماد مصدر واحد للإصدار والتحقق منه في CI.

كما أن `lib/providers/iptv_provider.dart` يحتوي fallback للإصدار، ثم يستبدله بقيمة `package_info_plus` عند التشغيل. يجب إزالة التكرار أو جعل fallback مشتقاً من build metadata، لأن اختلاف القيم قد يؤدي إلى حظر نسخة صحيحة.

### الاختبارات لا تثبت التشغيل الحقيقي

يوجد عدد جيد من اختبارات parsing وregression، لكن `todo.md` يقر بأن اختبار live وmovie وseries على جهاز Android حقيقي لم يكتمل. لذلك لا يجوز اعتبار الإصدار مستقراً اعتماداً على نجاح CI وحده. يجب إضافة smoke test عملي قبل كل release:

1. تسجيل دخول باشتراك Xtream.
2. تشغيل قناة live.
3. تشغيل movie.
4. فتح series وتشغيل episode.
5. تسجيل دخول Stalker/MAC.
6. تجربة custom menu.
7. التحقق من التحديث من جهاز غير موثق بحساب GitHub.

### CI يحتاج إلى تشديد

Workflow يستخدم `permissions: contents: write` على مستوى الـ job كله. الأفضل تقليل الصلاحية إلى خطوة إنشاء Release فقط، واستخدام حماية للفرع الرئيسي وطلب مراجعة قبل merge. كما لا يظهر Dependabot أو إعداد واضح لـ CodeQL/secret scanning أو فحص dependency vulnerabilities.

## تصميم لوحة الاشتراكات المقترح

### طبقة البيانات

استخدم D1 مع جداول منفصلة ومحددة:

- `subscriptions`: code hash، نوع الخادم، server profile id، الحالة، تاريخ الانتهاء، الحد الأقصى للأجهزة.
- `server_profiles`: اسم داخلي، host، username، password المشفر أو Secret reference، وحالة الخادم.
- `devices`: subscription id، device fingerprint hash، first seen، last seen، status.
- `plans`: اسم الباقة، المدة، الحد، الخصائص.
- `admin_users`: هوية الإدارة أو Cloudflare Access identity، بدون كلمات مرور مخزنة داخل Worker.
- `audit_logs`: من فعل ماذا ومتى وعلى أي اشتراك.

لا تخزن كلمة المرور الخام لخادم IPTV في response عام أو في واجهة العميل إلا عند الحاجة الفعلية للتشغيل، والأفضل أن يبقى التطبيق يتلقى session/profile مؤقتاً بدلاً من كشف بيانات الخادم طويلة الأجل.

### طبقة API

اقترح endpoints منفصلة:

- `POST /v1/auth/login`: تسجيل دخول الكود، rate limit، device binding.
- `GET /v1/subscription`: حالة الاشتراك للجلسة الحالية فقط.
- `POST /admin/subscriptions`: إنشاء اشتراك بعد Admin auth.
- `PATCH /admin/subscriptions/:id`: تمديد/إيقاف/تغيير الباقة.
- `POST /admin/subscriptions/:id/reset-devices`: إعادة الأجهزة.
- `GET /admin/stats`: إحصاءات بدون كشف كلمات مرور.

يجب أن تكون `/admin/*` خلف Cloudflare Access أو OIDC، مع CSRF protection للطلبات التي تعتمد على cookies، وaudit log لكل عملية تغيير.

### توزيع APK

الخيار المفضل هو R2:

1. يبقى مستودع المصدر Private.
2. يرفع CI ملف APK إلى R2 بعد نجاح البناء.
3. يستخدم Worker رابط R2 عام أو signed URL قصير المدة.
4. يطابق Worker checksum/version قبل إعادة الرابط.

بهذا لا يحتاج التطبيق إلى GitHub token ولا يصبح مستودع المصدر عاماً.

## خطة التنفيذ المقترحة

### المرحلة 0: احتواء الخطر

- تدوير كل بيانات دخول IPTV الموجودة في `worker.js` وD1 إذا كانت مستخدمة فعلياً.
- إزالة قائمة الخوادم السرية من `/v1/config`.
- إصلاح مصدر APK قبل حظر النسخ القديمة.
- تعطيل أو تقييد cleartext قدر الإمكان.

### المرحلة 1: تثبيت الأساس

- توحيد version source في `pubspec.yaml` وCI.
- إضافة D1 migrations موثقة.
- تطبيق device binding وrate limiting.
- إضافة tests لعقود API والـ Worker.
- تفعيل GitHub branch protection وDependabot وCodeQL/secret scanning.

### المرحلة 2: لوحة الإدارة

- Cloudflare Access/OIDC للإدارة.
- Dashboard عربي RTL responsive.
- إنشاء وتمديد وإيقاف الاشتراكات.
- reset devices.
- إدارة الباقات والخوادم.
- سجل عمليات قابل للتصدير.
- عدم عرض كلمات مرور الخوادم إلا في خدمة داخلية محدودة.

### المرحلة 3: التحقق والإطلاق

- اختبار end-to-end على جهاز Android حقيقي.
- نشر Worker في بيئة staging أولاً.
- تشغيل smoke tests.
- نشر production مع rollback version.
- رفع APK إلى R2 والتحقق من رابط تنزيل غير مسجل الدخول.

## قرارات أوصي بها

1. **لا نعطي التوكن صلاحيات كاملة**؛ نستخدم توكن محدوداً لـ Workers/D1/R2 فقط.
2. **لا نجعل مستودع المصدر عاماً**؛ نستخدم R2 لتوزيع APK.
3. **لا نبني لوحة الإدارة فوق `/v1/config` الحالي**؛ نصلح عقد API أولاً.
4. **لا نحذف أو نبدل بيانات D1 قبل أخذ export ونسخة احتياطية**.
5. **لا نعتبر أي إصدار مستقراً حتى ينجح اختبار live/movie/series فعلياً**.

## الملفات الأهم للمراجعة التالية

- `worker.js`
- `lib/providers/iptv_provider.dart`
- `lib/services/remote_config_service.dart`
- `android/app/src/main/AndroidManifest.xml`
- `android/app/src/main/res/xml/network_security_config.xml`
- `.github/workflows/android.yml`
- `android/local.properties`
- `todo.md`
