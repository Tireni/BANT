# BANT

BANT is a social conversation platform where people discover live voice rooms, join conversations, meet people, make friends, and create/moderate their own rooms.

Core loop:

```text
DISCOVER -> JOIN -> TALK -> CONNECT -> RETURN
```

## Requirements

- Node.js and npm
- A Supabase project
- A modern browser with microphone support for web voice testing
- HTTPS or localhost for microphone access

## Installation

```bash
npm install
cp .env.example .env
```

Fill `.env`:

```bash
EXPO_PUBLIC_SUPABASE_URL=your-project-url
EXPO_PUBLIC_SUPABASE_ANON_KEY=your-anon-key
```

## Database Setup

Run the SQL files in `supabase/migrations` in this order:

```text
000_complete_setup.sql
001_phase1_auth_onboarding.sql
002_phase2_rooms.sql
003_phase3_voice_signaling.sql
004_phase4_room_messages.sql
005_phase5_social_profiles.sql
006_phase6_feedback_reports_admin.sql
007_profile_setup_steps.sql
008_ensure_profile_rpc.sql
009_fix_room_members_rls.sql
010_fix_room_creation_mvp.sql
011_launch_mvp_database_alignment.sql
012_friendships_source_of_truth.sql
013_private_room_invites.sql
014_live_room_moderation_controls.sql
015_username_login_lookup.sql
```

For email/password testing, either disable email confirmations in Supabase Auth settings or confirm each test user before login. Configure Google OAuth in Supabase with the deployed web callback URL and the native deep-link callback for the `bant` scheme.

## Development

```bash
npm run web
```

## Build And Validation

```bash
npm run typecheck
npm run build
npm test
```

## Current Product Flow

1. Sign up with email/password or Google.
2. Set display name, username, avatar, and bio.
3. Pick interests.
4. Enter BANT.
5. Discover a live room.
6. Join the room. Voice starts automatically after backend entry succeeds.
7. Chat, mute/unmute, and talk.
8. Add friends from People.
9. Create a room, share private invites, and moderate participants if you own the room.

## Architecture

- Expo Router app targeting web and native-compatible routing.
- Supabase Auth for email/password and Google OAuth.
- Supabase Postgres as source of truth for profiles, rooms, room members, friendships, private invites, notifications, reports, feedback, chat, voice signaling, and moderation.
- Supabase Realtime for room membership, chat, warning overlays, and WebRTC signaling.
- Zustand stores client session state and cached backend data only. It is not the authority for friendships, invites, room access, or moderation.

## Auth

- Email/password login supports either email or username in one field.
- Username login uses `login_username_lookup(username)` to resolve the auth email without exposing profile email through normal profile queries.
- Google OAuth uses a platform-aware callback: current web origin on web and the configured `bant` deep link on native.
- First-time users are routed into profile setup before entering the app.
- Pending private-room invites are preserved through login and onboarding.

## Rooms And Voice

- Room creation persists title, category, privacy, max participants, Noise Control setting, and owner.
- Joining rooms goes through backend RPC validation and capacity checks.
- Voice uses browser WebRTC on web with Supabase Realtime for signaling.
- The owner is represented by `rooms.owner_id` and the owner membership role.

## Friendships

BANT uses mutual friendships:

- send request
- accept request
- decline/cancel request
- friend count and state from backend data

Legacy follow tables may still exist in historical migrations for compatibility, but follows are not the current product model.

## Private Invites

Private room access is backend-authoritative:

- owners generate secure invite tokens
- invite links resolve through `/invite/:token`
- direct user invites create backend notifications
- revoked, expired, ended-room, full-room, and wrong-recipient cases are rejected by RPCs

## Moderation And Noise Control

Room owners can:

- select one or multiple participants
- mute selected participants
- mute all eligible participants
- release/unmute selected participants
- release all
- warn selected participants when Noise Control is enabled
- warn all eligible participants
- end the room

Host mute is persisted in `room_members`, delivered through realtime, disables the target participant's outgoing audio track, and blocks self-unmute until released.

## Testing

Automated tests cover pure launch contracts:

- username normalization
- email vs username login detection
- OAuth redirect generation
- onboarding routing
- room capacity/category helpers
- friendship state resolution
- pending invite key stability

Run:

```bash
npm test
```

## Two-User Smoke Test

Use two authenticated users in separate browser sessions.

1. User A creates a room with Noise Control enabled.
2. User B joins from the rooms list or a private invite.
3. Confirm both users see synced participants.
4. User A selects User B and mutes them.
5. Confirm User B becomes host-muted and cannot self-unmute.
6. User A releases User B.
7. User B can self-mute/unmute again.
8. User A warns User B.
9. Confirm the warning overlay appears and dismisses.
10. User A ends the room.
11. Confirm participants are returned away from the ended room and new joins are rejected.

## Legacy / Compatibility Schema

Some historical migrations still include tables or columns such as `universities`, `university_id`, and `follows`. They remain for database compatibility and older rows. The current launch app does not require a university selection and does not use follows as the social model.

## Production Notes

- Supabase URL and anon key must be configured.
- Supabase Google provider must include the correct callback URLs.
- Web voice requires HTTPS or localhost and browser microphone permission.
- Native mobile builds have not been fully production-verified in this repository.
