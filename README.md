# BANT

BANT is a social conversation app for discovering live voice rooms, joining conversations, meeting people, making friends, and moderating owned rooms.

Core loop:

```text
DISCOVER -> JOIN -> TALK -> CONNECT -> RETURN
```

## Requirements

- Node.js 20+ and npm
- Supabase project
- Modern browser with microphone support for web voice testing
- HTTPS or localhost for microphone access
- TURN server for reliable production WebRTC across real networks

## Installation

```bash
npm install
cp .env.example .env
```

Fill `.env`:

```bash
EXPO_PUBLIC_SUPABASE_URL=your-project-url
EXPO_PUBLIC_SUPABASE_ANON_KEY=your-anon-key
EXPO_PUBLIC_TURN_URL=turn:your-turn-host:3478
EXPO_PUBLIC_TURN_USERNAME=your-turn-username
EXPO_PUBLIC_TURN_CREDENTIAL=your-turn-credential
```

TURN values are optional for local UI testing, but required before trusting voice reliability in production networks.

## Database Setup

Canonical fresh database path:

```text
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
016_disable_insecure_username_lookup.sql
017_limited_mesh_voice_capacity.sql
018_rpc_permission_and_membership_hardening.sql
```

`000_complete_setup.sql` is a legacy snapshot only. Do not run it as part of the current fresh database sequence because later migrations supersede it.

Migration `015` introduced an insecure username-to-email lookup. Migration `016` revokes/drops that function, and the app no longer calls it.

## Development

```bash
npm run web
```

## Build And Validation

```bash
npm ci
npm run typecheck
npm test
npm run build
```

CI runs the same typecheck, test, and build steps on pushes to `main` and pull requests.

## Current Product Flow

1. Sign up with email/password or Google.
2. Set display name, username, avatar, and bio.
3. Pick interests.
4. Discover or create a live room.
5. Join a room. Voice starts after backend entry succeeds.
6. Chat, mute/unmute, and talk.
7. Add friends.
8. Create private invites and moderate participants if you own the room.

## Auth

- Email/password login is email-only in this build.
- Username login is deferred until it can be handled by a server-side auth proxy without exposing auth emails.
- Google OAuth uses the current web origin on web and `bant://auth/callback` on native.
- First-time users are routed into profile setup before entering the app.
- Pending private-room invites are preserved through login and onboarding.

## Rooms And Voice

- Supabase Postgres is the source of truth for rooms, room members, friendships, private invites, notifications, reports, feedback, chat, voice signaling, and moderation.
- Joining rooms goes through backend RPC validation and capacity checks.
- Voice uses browser WebRTC mesh on web with Supabase Realtime signaling.
- Mesh voice is capped at 8 participants in UI and database. BANT should move to an SFU such as LiveKit, Daily, Agora, Twilio Video, or mediasoup before larger live audio rooms.
- ICE config always includes STUN and adds TURN when `EXPO_PUBLIC_TURN_*` values are configured.

## Moderation And Noise Control

Room owners can mute/release selected participants, mute/release all eligible participants, send Noise Control warnings when enabled, and end the room. Host mute is persisted in `room_members`, delivered through realtime, disables the target participant's outgoing audio track, and blocks self-unmute until released.

## Testing

Automated tests cover auth helpers, OAuth redirects, onboarding routes, room capacity/category helpers, mesh voice config, friendship contracts, invite contracts, and security contracts that prevent the old username lookup from returning.

Optional staging integration tests live under `tests/integration` and skip unless `TEST_SUPABASE_URL` and `TEST_SUPABASE_ANON_KEY` are configured.

## Production Docs

- [Production smoke test](docs/PRODUCTION_SMOKE_TEST.md)
- [Production checklist](docs/PRODUCTION_CHECKLIST.md)

## Production Notes

- Apply migrations to Supabase manually or through your chosen migration runner before deploying app code that depends on them.
- Configure Google OAuth callback URLs in the Supabase dashboard for the deployed web domain and native scheme.
- Verify avatar storage bucket/policies in Supabase before enabling public profile images at scale.
- Keep `000_complete_setup.sql`, university columns, and follow tables as historical compatibility only; the active product uses profile setup and mutual friendships.

