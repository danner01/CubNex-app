# Reglas de ProGuard/R8 del proyecto.

# Mapbox
-keep class com.mapbox.** { *; }
-dontwarn com.mapbox.**

# Firebase
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# ML Kit
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# Google Material
-keep class com.google.android.material.** { *; }
-dontwarn com.google.android.material.**

# Install referrer
-keep class com.android.installreferrer.** { *; }
-dontwarn com.android.installreferrer.**

# Hive / Gson
-keep class com.google.gson.** { *; }
-keepclassmembers class * extends com.google.gson.TypeAdapter { *; }
-keepclassmembers class * implements com.google.gson.JsonSerializer { *; }
-keepclassmembers class * implements com.google.gson.JsonDeserializer { *; }

# Flutter
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**
