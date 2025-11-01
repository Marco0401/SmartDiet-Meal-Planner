########################################
# Flutter General
########################################
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.plugins.** { *; }

########################################
# Google ML Kit (Text Recognition)
########################################
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

########################################
# OkHttp (used by uCrop)
########################################
-keep class okhttp3.** { *; }
-dontwarn okhttp3.**

########################################
# uCrop (Image Cropper)
########################################
-keep class com.yalantis.ucrop.** { *; }
-dontwarn com.yalantis.ucrop.**

########################################
# Firebase (optional if you use it)
########################################
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
