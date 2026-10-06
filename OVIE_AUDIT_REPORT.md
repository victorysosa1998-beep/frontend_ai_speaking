# Ovie audit and repair report

## Branding
- Public app name changed to **Ovie**.
- Added a shared Ovie brand/theme and a royal crown-style launcher/logo asset.
- Updated Flutter web metadata, Android/iOS display names, onboarding, social UI, calls, payments, emails and backend AI-facing text.
- Existing Firebase project IDs, Android/iOS application IDs, API header names and internal notification/storage keys were intentionally preserved for production compatibility.

## Frontend repairs
- Removed the unused `dart:io` import from `main.dart`, which could prevent Flutter web compilation.
- Added the missing `permission_handler` import for `openAppSettings()`.
- Removed the `dart:io`/`path_provider` dependency from the chat image-sharing path and now shares an in-memory `XFile`, making that path web-compatible.
- Renamed the chat source file/class to `OvieChatPage` and updated imports.
- Updated the Flutter package name to `ovie` and migrated internal `package:ovie/...` imports.
- Improved the global Material 3 theme, buttons, inputs, cards, navigation bar, splash/onboarding presentation and app icon.
- Fixed the malformed website label in About.
- Preserved legacy `@sympy` group-call mentions while adding `@ovie` so existing group behavior does not suddenly break.

## Backend repairs
- Added localhost CORS support for Flutter web development while keeping production origins explicit through `CORS_ORIGINS`.
- Updated backend branding and group AI identity to Ovie.
- Kept legacy Sympy group-call trigger aliases for migration compatibility.
- Made new-user credit initialization repair missing server-owned fields without overwriting an existing balance/quota.

## Firestore/security repairs
- Added secure `pending_orders` rules so payment orders can actually be created/read by their owner and only admins can approve/update them.
- Added server-controlled `admins/{uid}` membership.
- Prevented normal users from writing billing fields such as `credits`, `is_premium`, and `free_seconds_remaining`.
- Fixed the `conversations` read rule to use `resource.data` instead of `request.resource.data`.
- Restricted friend-request updates to status/response fields.
- Prevented post/status edits from changing author identity/content after creation.

## Validation performed
- Python AST parsing: passed.
- Python bytecode compilation (`python -S -m compileall`): passed.
- JSON parsing: passed.
- XML/plist parsing: passed.
- Dart delimiter/structure sanity check: passed.
- Relative/package import existence checks: passed.
- Frontend/backend REST endpoint inventory: no frontend endpoint was found without a matching backend route.
- Flutter `analyze`, `test`, and device builds could not be executed in this environment because the Flutter SDK is not installed here. Run those commands locally before release.

## Admin setup
Create a Firestore document at `admins/<ADMIN_FIREBASE_UID>` once for each trusted admin account. The client cannot create or modify these documents.
