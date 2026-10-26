-keep class io.flutter.** { *; }
-keep class com.google.firebase.** { *; }
-keep class com.dexterous.** { *; }
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes Exceptions
-dontwarn org.jetbrains.annotations.**
-dontwarn kotlin.**

# ✅ إصلاح خطأ R8 لمكتبات Play Core المفقودة
-dontwarn com.google.android.play.core.**
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
