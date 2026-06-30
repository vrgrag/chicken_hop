# Flutter / Dart entry points
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# AppsFlyer
-keep class com.appsflyer.** { *; }
-keepclassmembers class com.appsflyer.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Play Integrity (AppCheck)
-keep class com.google.android.play.core.integrity.** { *; }

# Play Core (deferred components / split install) — referenced by Flutter
# embedding even when the app does not use dynamic feature delivery.
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# Notifications
-keep class com.dexterous.** { *; }

# WebView
-keep class * extends android.webkit.WebViewClient
-keep class * extends android.webkit.WebChromeClient
-keepattributes JavascriptInterface
-keepclassmembers class * { @android.webkit.JavascriptInterface <methods>; }
