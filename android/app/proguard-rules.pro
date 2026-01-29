# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# LiveKit & WebRTC (Crucial for voice calls)
-keep class com.livekit.** { *; }
-keep class org.webrtc.** { *; }

# Firebase Authentication
-keep class com.google.firebase.** { *; }