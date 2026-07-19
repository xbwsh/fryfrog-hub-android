# Add project specific ProGuard rules here.
-keepattributes *Annotation*

# Kotlin
-dontwarn kotlin.**
-keep class kotlin.Metadata { *; }

# Compose
-dontwarn androidx.compose.**
