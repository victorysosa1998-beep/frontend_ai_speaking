# Ovie 1.3.0+5 — Google Play release checklist

## Current Android/Play baseline

- Target SDK: Android 16 / API 36.
- Compile SDK: 36.
- Android Gradle Plugin: 8.11.1.
- Gradle wrapper: 8.14.
- Java/Kotlin target: Java 17 / Kotlin JVM 17.
- NDK: 28.2.13676358.
- Release build: Android App Bundle (`.aab`), not APK.
- Release signing: `android/key.properties` only; never commit the keystore.
- `versionCode` must increase for every Play upload. This release is build 5.
- 64-bit native libraries and 16 KB page-size compatibility must be verified before production rollout.

Google Play requires new apps and app updates submitted from August 31, 2026 to target Android 16 (API 36) or higher. Apps targeting Android 15+ also need 16 KB page-size support for Google Play's compatibility requirements.

## Before building

1. Install a current stable Flutter SDK with Dart 3.10+.
2. Run:

```bash
flutter clean
flutter pub get
flutter analyze
flutter test
```

3. Confirm `android/key.properties` exists locally and points to the production upload keystore.
4. Confirm production backend environment variables are set on Railway:
   - `APP_API_KEY`
   - `OPENAI_API_KEY`
   - `LIVEKIT_API_KEY`
   - `LIVEKIT_API_SECRET`
   - `LIVEKIT_URL`
   - `REDIS_URL`
   - `TAVILY_API_KEY`
   - `CARTESIA_API_KEY`
   - `FIREBASE_SERVICE_ACCOUNT_JSON`
5. Set the public legal URLs at build time:

```text
SYMPY_PRIVACY_URL=https://YOUR-DOMAIN/privacy
SYMPY_ACCOUNT_DELETION_URL=https://YOUR-DOMAIN/delete-account
```

The URLs above are placeholders. Replace them with real public pages before Play submission.

## Production build

```bash
flutter build appbundle --release ^
  --dart-define=SYMPY_API_KEY=YOUR_APP_API_KEY ^
  --dart-define=SYMPY_PRIVACY_URL=https://YOUR-DOMAIN/privacy ^
  --dart-define=SYMPY_ACCOUNT_DELETION_URL=https://YOUR-DOMAIN/delete-account
```

For PowerShell, use one line or replace `^` with the PowerShell continuation character.

Output:

```text
build/app/outputs/bundle/release/app-release.aab
```

## 16 KB page-size validation

Because Ovie uses LiveKit/WebRTC and other native libraries, do not assume 16 KB compatibility from Dart code alone.

- Keep AGP at 8.5.1+ (this project uses 8.11.1).
- Keep NDK 28+ for native builds (this project uses 28.2.13676358).
- Build the AAB.
- Use Google's 16 KB testing guidance and test the release build on a 16 KB Android emulator/device.
- Inspect the produced bundle/APK native libraries if Play Console reports an alignment warning.

## Functional smoke test

### Authentication
- Sign up.
- Verify email.
- Log in/out.
- Reset password.
- Delete account from Settings → Delete Account.

### AI chat
- English.
- Nigerian Pidgin.
- Image input.
- Internet/current-information questions.
- Conversation memory.
- Error/retry handling.

### Voice
- Buddy.
- Missy.
- Chaotic / Savage / Calm / Hype / Gist / Story.
- Microphone permission.
- Bluetooth/headphones.
- Call start/end.
- In-call emoji reactions and AI spoken reactions.
- Free call time.
- Purchased credits.
- Network interruption/reconnect.

### Social/fun
- Fun Zone.
- Daily challenge/streak.
- Sparks/levels.
- Emoji Decode.
- 2 Truths + 1 Lie.
- Call Challenge.
- Wild Card.
- Share challenge.
- Group call/invite.

### Notifications
- Android 13+ notification permission.
- Foreground FCM notification.
- Background notification.
- Notification tap routing.
- Credits notification.

## Play Console

Complete these separately in Play Console:

- App content.
- Data Safety form.
- Privacy policy URL.
- Account deletion URL/process.
- Target audience and content rating.
- Ads declaration.
- App access instructions if reviewers need an account.
- Financial features declaration if applicable.
- Store listing, screenshots, icon and feature graphic.
- Internal testing before production.
- Review the Android vitals/crash report after rollout.

## Important architecture note

`com.example.loveable` is currently the production application ID used by the existing Firebase Android configuration. Do not rename the application ID casually. A package/application-ID migration is a separate Firebase + Play Store migration and can make the existing app appear as a new app.

## Release principle

Do not upload a release until:

```text
flutter analyze     → clean
flutter test        → passing
AAB build           → successful
release signing     → verified
16 KB test          → passed
Play pre-launch     → reviewed
account deletion    → tested
```
