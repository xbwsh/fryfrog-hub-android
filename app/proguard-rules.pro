# Add project specific ProGuard rules here.
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes Exceptions

# Kotlin
-dontwarn kotlin.**
-keep class kotlin.Metadata { *; }

# Compose
-dontwarn androidx.compose.**

# Retrofit
-dontwarn retrofit2.**
-keep class retrofit2.** { *; }
-keepattributes Exceptions
-keepclasseswithmembers class * {
    @retrofit2.http.* <methods>;
}

# OkHttp
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }

# Gson
-keep class com.google.gson.** { *; }
-keep class com.fryfrog.hub.data.model.** { *; }
-keepclassmembers class com.fryfrog.hub.data.model.** { *; }

# Keep API response models
-keep class com.fryfrog.hub.data.remote.** { *; }
