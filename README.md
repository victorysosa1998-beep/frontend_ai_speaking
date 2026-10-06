# Ovie

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Ovie 1.3.0 — production upgrade

This release keeps the existing 1:1 AI calling, chat, Firebase, credits and payment flows and adds an optional group experience.

### New
- Play with Friends group rooms using LiveKit
- 30-minute signed invite codes
- Group in-room text chat
- My Turn speaker handoff for the AI
- AI-generated group games
- Hot takes, Who Goes First, Finish My Sentence, Deep Gist, Soft Life Simulator and Naija Life Simulator
- Reactions
- Squad Sparks points and leaderboard
- Daily Fun Zone challenges, streaks, levels and achievements
- Naija slang and natural English/Pidgin prompts
- Vibe DJ / music-mood conversation prompts

### Build configuration
- Android compile/target SDK 36
- NDK 28.2.13676358
- Flutter LiveKit client 2.13.0
- App version 1.3.0, build 5

Run `flutter pub get` before building because this production bundle intentionally does not include a stale dependency lockfile.


## Technical compatibility note
The public app brand is **Ovie**. Existing Firebase Android/iOS application IDs and the Firebase project identifier are intentionally unchanged so existing production users and data are not migrated accidentally.


## Admin setup
The payment/admin flow uses a server-controlled Firestore `admins/{uid}` document.

1. In Firebase Console → Firestore, create a document in the `admins` collection.
2. Use the admin Firebase Authentication UID as the document ID.
3. The document can contain any non-sensitive fields; it is intentionally not writable by the app.
4. The Ovie app will then show the Admin Panel to that account, and Firestore rules will permit admin order/credit operations.

Do **not** put admin UIDs or credit-management credentials in the Flutter source.
