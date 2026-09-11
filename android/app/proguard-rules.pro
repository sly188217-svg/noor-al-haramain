# ===== Flutter =====
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# ===== HTTP =====
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-dontwarn okhttp3.**

# ===== Firebase =====
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# ===== Audioplayers =====
-keep class com.ryanheise.audioservice.** { *; }
-keep class xyz.luan.audioplayers.** { *; }

# ===== General =====
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# ===== Remove Logs in Release =====
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
    public static *** w(...);
}
