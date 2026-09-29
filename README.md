# BANT

BANT is a social conversation platform for discovering live voice rooms, joining conversations, meeting people, making friends, and creating or moderating rooms.

Core loop:

```text
DISCOVER -> JOIN -> TALK -> CONNECT -> RETURN
```

## Launch Architecture

BANT uses two complementary systems:

- **Supabase** is the business source of truth for authentication, profiles, interests, rooms, room membership, capacity, friendships, notifications, invitations, moderation, Noise Control, chat, reports, and feedback.
- **LiveKit** is the production SFU media layer for room audio. BANT does not use browser peer-to-peer mesh audio in the production room path.

A participant must first have valid active BANT room membership in Supabase. The server-side `livekit-token` Edge Function verifies that membership before issuing a LiveKit token.

## Requirements

- Node.js 22+ and npm
- Supabase project
- LiveKit project
- Modern browser with microphone support
- HTTPS or localhost for microphone access

## Client Environment

Create `.env`:

```bash
EXPO_PUBLIC_SUPABASE_URL=your-project-url
EXPO_PUBLIC_SUPABASE_ANON_KEY=your-anon-key
```

Never place LiveKit API secrets in `EXPO_PUBLIC_*` variables.

## LiveKit Server Secrets

Configure these as Supabase Edge Function secrets:

```bash
LIVEKIT_URL=wss://your-project.livekit.cloud
LIVEKIT_API_KEY=your-livekit-api-key
LIVEKIT_API_SECRET=your-livekit-api-secret
```

Deploy:

```bash
supabase functions deploy livekit-token
```

The Edge Function authenticates the Supabase user, verifies the room is live, verifies active room membership, derives the BANT role from the database, and only then issues a media token.

## Database Setup

`000_complete_setup.sql` is a legacy snapshot only. Do not run it in the canonical current sequence.

Apply numbered migrations in order:

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
019_100_person_sfu_rooms_and_feed.sql
020_realtime_and_function_hardening.sql
```

Migration 017 is historical: it temporarily limited the mesh implementation to eight participants. Migration 019 supersedes that launch limit after the production media path moved to LiveKit and allows room capacities from 5 through 100, defaulting to 20.

Migration 015 introduced an unsafe username-to-email lookup. Migration 016 removes it. Login is email/password or Google until username authentication is implemented through a safe server-side auth flow.

## Room Capacity

Room creators can choose:

```text
5, 10, 15, 20, 30, 50, 75, 100
```

The database is authoritative. Join RPCs still enforce room state and capacity.

The 100-person target is an **SFU architecture target**, not a claim that a 100-participant media load test has already passed. Run the production load test before declaring the deployment fully validated.

## Room Discovery

Feed/discovery uses the lightweight `get_live_room_feed` RPC. It returns room metadata and aggregate participant/speaker counts rather than downloading every participant profile for every room.

The live-room screen uses a separate full room-detail query and room-specific realtime refresh.

## Voice

Production room audio uses `livekit-client` and the `livekit-token` Supabase Edge Function.

The old `voice_signals` table and migration remain as historical compatibility but are no longer the production media signaling path.

Current launch media behavior:
- owner and speakers can publish audio
- listeners subscribe without publishing
- ordinary public/invite joins default to speaker in the current MVP
- self mute and owner/admin mute remain distinct
- effective mute is self mute OR admin mute
- room-end realtime disconnects media clients

## Moderation And Noise Control

Room owners can:
- mute/release selected participants
- mute/release all eligible participants
- send Noise Control warnings when enabled
- end the room

Supabase remains authoritative for host mute state. Recipient clients receive the room membership update and apply it to their local published LiveKit audio track.

Noise Control is separate from mute and displays a temporary realtime warning.

## Development

```bash
npm install
npm run web
```

## Validation

```bash
npm ci
npm run typecheck
npm test
npm run build
npx expo-doctor
```

CI runs typecheck, tests, and web export on pushes to `main` and pull requests.

## Auth

- Email/password login
- Google OAuth with platform-aware callback handling
- first-time users complete profile setup and interests
- pending private-room invites survive auth/onboarding
- username login is intentionally deferred rather than exposing private authentication email addresses

## Current Product Flow

1. Sign up or sign in.
2. Complete profile setup.
3. Pick interests.
4. Discover or create a room.
5. Enter through Supabase membership validation.
6. Receive a server-authorized LiveKit media token.
7. Talk, chat, mute/unmute, and interact.
8. Add friends.
9. Create private invites.
10. Moderate an owned room.

## Production Checklist

See:
- [Production checklist](docs/PRODUCTION_CHECKLIST.md)
- [Production smoke test](docs/PRODUCTION_SMOKE_TEST.md)

Before public launch verify:
- migrations through latest applied
- `livekit-token` Edge Function deployed
- LiveKit secrets configured server-side
- Google OAuth redirect URLs configured
- realtime publication verified
- avatar storage policies verified
- CI green
- two-browser media test passed
- 10/50/100 participant load tests completed at the intended launch scale
