# Ovie 1.5.0 Build 7 — AI Social Groups

## Implemented
- Firestore-backed AI group chats with usernames and member lists.
- Ovie is a visible AI member and responds only when explicitly mentioned in group chat.
- Group chat context includes recent messages and sender names.
- Group chat AI endpoint verifies the Firebase ID token and group membership.
- Group call button in the group-chat header creates a LiveKit AI group call.
- Active call banner lets members join the live room.
- Group-call presence carries display names.
- LiveKit active-speaker detection switches the AI input to the person currently speaking.
- Voice-agent group mode stays silent unless the transcript explicitly addresses Ovie.
- Speaker attribution is injected into the AI turn context.
- Existing 1:1 call and group-call room/token architecture is preserved.

## Important
A microphone permission prompt should still be user-initiated. The app does not silently start a member's microphone from a push notification. For background incoming-call UX, connect the existing FCM notification layer to `group_chats/{groupId}.active_call` and open an accept/join screen; do not auto-enable the microphone.

## Validation
- Python backend syntax checked with `py_compile`.
- Modified Dart files were statically bracket-checked.
- LiveKit 2.13.0 APIs used for participant speaking state and room participants.
- Full `flutter analyze`, `flutter test`, and release AAB build still need to be run on a machine with Flutter 3.38+/Dart 3.10+ installed.
