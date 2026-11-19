# Scaneliq Proguard & R8 Rules

# ML Kit Text Recognition, Object Detection, Translation & Document Scanner
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**
-keep class com.google.android.gms.internal.mlkit_** { *; }
-dontwarn com.google.android.gms.internal.mlkit_**

# Tesseract4Android native JNI bindings
-keep class com.googlecode.tesseract.android.** { *; }
-keep class cz.adaptech.tesseract4android.** { *; }
-dontwarn cz.adaptech.tesseract4android.**

# Mobile Scanner & CameraX
-keep class dev.steenbakker.mobile_scanner.** { *; }
-keep class androidx.camera.** { *; }

# Keep native JNI methods for PDFium (pdfrx), SQLite, and Tesseract
-keepclasseswithmembernames class * {
    native <methods>;
}

# Flutter Secure Storage & Tink / KeyStore
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-dontwarn com.google.crypto.tink.**

# Google Play Billing (in_app_purchase)
-keep class com.android.billingclient.api.** { *; }
-dontwarn com.android.billingclient.api.**

# Biometric prompt & FragmentActivity
-keep class androidx.biometric.** { *; }
-keep class io.flutter.plugins.localauth.** { *; }
