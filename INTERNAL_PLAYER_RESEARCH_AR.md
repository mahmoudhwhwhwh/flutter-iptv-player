# تقييم محركات التشغيل الداخلية

## الخلاصة

`flutter_vlc_player` يدمج libVLC داخل التطبيق ويدعم Android/iOS، لكنه يضيف مكتبات native كبيرة ويتطلب قواعد R8/ProGuard خاصة لـ`org.videolan.libvlc`. توثيق الحزمة يذكر دعم HLS ضمن الأمثلة، لكن لا يضمن تكافؤ مسارات BetterPlayer الحالية في DASH/ClearKey أو نفس دورة reconnect والـASMS tracks.

`media_kit` يستخدم محركاً أصلياً داخل التطبيق عبر حزم video/rendering منفصلة، ويعرض API لاختيار video/audio/subtitle tracks وHTTP headers، وهو خيار أقرب لبناء طبقة تشغيل داخلية قابلة للتحكم. لكنه يحتاج إضافة `media_kit` و`media_kit_video` وتهيئة native لكل منصة، وسيحتاج ربطاً مخصصاً مع واجهة المشغل الحالية وDRM والـquality dialog.

المشروع الحالي يستخدم `better_player_plus` المبني على video_player/Android Media3 ويحتوي بالفعل على HLS وDASH وASMS quality tracks وsubtitles وClearKey ومسار Live reconnect. لذلك لا ينبغي استبداله دفعة واحدة بمحرك آخر؛ الدمج الآمن يكون عبر طبقة داخلية اختيارية مع إبقاء BetterPlayer مساراً افتراضياً حتى يتم اختبار الصيغ وDRM على أجهزة فعلية.

| الخيار | داخل APK | HLS/TS | DASH/DRM | كلفة الدمج | القرار |
|---|---:|---:|---:|---:|---|
| BetterPlayer الحالي | نعم | موجود | موجود جزئياً ومختبر بالكود | منخفض | يبقى الافتراضي |
| flutter_vlc_player | نعم | قوي عادةً | يحتاج تحققاً خاصاً | مرتفع وحجم أكبر | ليس بديلاً آمناً فورياً |
| media_kit + media_kit_video | نعم | مناسب | يحتاج ربط DRM مخصص | مرتفع | يصلح كمسار تجريبي مستقل |

المراجع: [flutter_vlc_player على pub.dev](https://pub.dev/packages/flutter_vlc_player)، [media_kit على pub.dev](https://pub.dev/packages/media_kit)، [better_player_enhanced على pub.dev](https://pub.dev/packages/better_player_enhanced).
