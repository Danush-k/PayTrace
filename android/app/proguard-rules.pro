# Flutter-specific ProGuard rules
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Keep PayTrace notification listener
-keep class com.paytrace.paytrace.PaymentNotificationListener { *; }
