# BANT Demo

BANT is a campus-first social voice rooms MVP for university students.

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

Run these migrations in Supabase SQL Editor in order:

```text
supabase/migrations/001_phase1_auth_onboarding.sql
supabase/migrations/002_phase2_rooms.sql
supabase/migrations/003_phase3_voice_signaling.sql
supabase/migrations/004_phase4_room_messages.sql
supabase/migrations/005_phase5_social_profiles.sql
supabase/migrations/006_phase6_feedback_reports_admin.sql
```

For local auth testing, either disable email confirmations in Supabase Auth settings or confirm each test user email before login.

To make an admin account after onboarding:

```sql
update public.profiles
set is_admin = true
where username = 'your_username';
```

## Development

```bash
npx expo start --web --port 8082
```

Open:

```text
http://localhost:8082
```

## Build

```bash
npm run typecheck
npm run build
```

## What Works

- Email/password signup, login, logout, and session persistence through Supabase Auth
- Protected app routes and onboarding guard
- Persistent profiles, universities, and interests
- Persistent room creation, discovery, join, leave, host/listener/speaker membership
- Browser WebRTC voice using Supabase Realtime for signaling
- Persistent real-time room text chat
- User discovery, profile editing, follow/unfollow, and follow notifications
- Feedback submission
- Room reporting
- Protected `/admin` console for admin users
- Responsive Expo web interface with the existing BANT visual style

## Known Limitations

- Voice is browser WebRTC only. It needs two authenticated browser sessions, microphone permission, and working Supabase Realtime.
- Active-speaker detection is not implemented. The app shows speaker/listener roles without pretending to detect live speech.
- Room invite flow copies or shares a room link; there is no push invite system yet.
- No native mobile build has been verified in this phase.
- No automated end-to-end tests are included.
- Supabase must be configured before real app flows can be tested. Without env vars, backend-backed actions correctly show setup errors or fallback visual data where retained.
- `npm audit` still reports transitive Expo/Metro vulnerabilities. The remaining npm-proposed fixes require breaking upgrades to Expo/router, so they were not forced during final verification.

## Two-User MVP Test

Use two browser sessions, such as normal Chrome and an incognito window.

### User A

1. Open BANT.
2. Create an account.
3. Complete onboarding.
4. Select university and interests.
5. Enter BANT.
6. Create a public room.
7. Enter the room.
8. Tap `Join` on the mic control and allow microphone access.
9. Send a room chat message.

### User B

1. Create a second account.
2. Complete onboarding.
3. Open `Rooms`.
4. Join User A's room.
5. Confirm User A appears as a room participant.
6. Confirm User A's chat message appears.
7. Send a reply.
8. Tap `Join` on the mic control and allow microphone access.
9. Speak, mute, unmute, then leave.
10. Open `People`, follow User A, and confirm the follow state persists.

### User A Again

1. Confirm User B appears in the room while joined.
2. Confirm User B's chat message persists after refresh.
3. Confirm voice can connect while both users are in the room.
4. Confirm the follow notification appears under `People -> Notifications`.

## Failure Case Tests

- Wrong password shows an auth error.
- Duplicate/invalid usernames are rejected by database constraints.
- Empty chat messages are rejected.
- Messages over 500 characters are rejected.
- Room reports with invalid payloads are rejected by RLS/check constraints.
- Non-admin users cannot access `/admin`.
- Microphone denial shows a voice error instead of pretending to connect.
- Refreshing inside a room reloads persisted room and chat data.

## Admin Test

1. Mark one user as admin using the SQL above.
2. Visit `/admin`.
3. Confirm users, rooms, feedback, and reports load.
4. Submit feedback from `Profile`.
5. Submit a room report from room options.
6. Change feedback/report statuses in `/admin`.
7. Refresh and confirm status updates persist.
