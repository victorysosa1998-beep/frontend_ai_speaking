# Ovie group-call integration (safe additive groundwork)

This bundle adds `lib/group_call_service.dart`, a client helper for exchanging an invite code for a guest-specific LiveKit token. The existing 1:1 call screen is intentionally unchanged.

## Backend contract

1. The host calls the existing `GET /get_token` endpoint. Its response now includes `invite_code` alongside `token`, `url`, and `room`.
2. Share the `invite_code` through the app's share sheet or copy button.
3. A guest submits the code using `GroupCallService.joinWithInvite(code)`.
4. Connect the guest's LiveKit `Room` to the returned `url` with the returned `token`.

Invite codes are signed and expire after 30 minutes. They are bearer invitations: anyone possessing a valid code can join until it expires, so share them only with people you trust.

## Critical AI limitation

LiveKit rooms support multiple participants, but the current Ovie `AgentSession` is linked to one participant by default. The new endpoints allow room entry; they do not yet make Ovie understand and fairly respond to every person in a group. For a safe first release, use a host-controlled turn-taking mode (one designated speaker at a time) and show a clear indicator of who Ovie is listening to. Do not ship open-mic AI group chat until multi-speaker handling, consent, participant caps, moderation, billing, disconnect/reconnect, and abuse reporting are implemented and tested.
