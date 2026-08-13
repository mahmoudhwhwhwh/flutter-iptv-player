# Keep the Android launcher and Flutter bridge names referenced by the manifest and generated registrant.
-keep class com.mahmoud.iptv.MainActivity { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Preserve classes reached via reflection by Android and Firebase.
-keepattributes *Annotation*
-keep class com.google.firebase.** { *; }
-dontwarn javax.annotation.**
