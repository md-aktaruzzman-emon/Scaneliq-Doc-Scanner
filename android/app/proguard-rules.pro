# Scaneliq Proguard & R8 Rules

# ML Kit Text Recognition optional language script options
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# ML Kit Vision & Scanner
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# Keep native JNI methods for PDFium and SQLite
-keepclasseswithmembernames class * {
    native <methods>;
}
