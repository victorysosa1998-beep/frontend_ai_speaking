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
-dontwarn org.webrtc.**

# Firebase Authentication & Core
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# FIX: Google Play Core / Split Install (Solves your R8 build error)
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }

# Speech to Text & Audio Session
-keep class com.csdcorp.speech_to_text.** { *; }
-keep class com.ryanheise.audio_session.** { *; }
-dontwarn com.ryanheise.audio_session.**

# General rules for plugins using reflection
-keepattributes Signature,Exceptions,*Annotation*
-keep class com.google.gson.** { *; }