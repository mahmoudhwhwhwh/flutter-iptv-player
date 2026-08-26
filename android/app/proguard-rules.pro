# Keep the Android launcher and Flutter bridge names referenced by the manifest and generated registrant.
-keep class com.mahmoud.iptv.MainActivity { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Preserve classes reached via reflection by Android and Firebase.
-keepattributes *Annotation*
-keep class com.google.firebase.** { *; }
-dontwarn javax.annotation.**

# Flutter references Play Core deferred-component classes optionally; this app does not ship deferred components.
-dontwarn com.google.android.play.core.**

# Maximum Obfuscation Rules
-keep class com.mahmoud.iptv.** { *; }
-allowaccessmodification
-repackageclasses 'com.mahmoud.iptv.secure'
