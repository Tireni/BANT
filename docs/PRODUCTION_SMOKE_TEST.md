# BANT Production Smoke Test

Use a staging or production-like environment. Do not run destructive test data against the live public project.

## Prerequisites

- migrations through latest applied
- livekit-token Edge Function deployed
- LIVEKIT_URL, LIVEKIT_API_KEY, LIVEKIT_API_SECRET configured server-side
- Google OAuth callback configured if testing Google
- two real test users A and B

## Auth

1. Sign in User A with email/password.
2. Sign in User B in a separate browser/profile.
3. Verify first-time onboarding routes correctly.
4. Verify Google sign-in separately if enabled.
5. Confirm no username-to-email login lookup is exposed.

## Public Room

1. A creates a public room with maximum participants 100.
2. Confirm room card shows in Feed.
3. Open room as A.
4. B opens the room and joins.
5. Confirm Supabase active membership count is 2.
6. Confirm the room header shows 2 / 100.

## LiveKit Audio

1. Confirm both clients obtain LiveKit media access only after BANT room membership exists.
2. Confirm A hears B and B hears A.
3. Self-mute A; B should stop hearing A.
4. Unmute A.
5. Temporarily interrupt B network and verify reconnect behavior.
6. Leave B and verify BANT membership becomes inactive and media disconnects.

## Moderation

1. Rejoin B.
2. A selects B and mutes B.
3. Verify room_members.is_muted is true.
4. Verify B's outgoing LiveKit audio becomes muted.
5. Verify B cannot self-unmute while host-muted.
6. A releases B.
7. Verify B may self-unmute again.

## Noise Control

1. Create/enable a room with Noise Control.
2. A warns B.
3. Verify B receives the realtime 🤫 overlay.
4. Warn selected users.
5. Warn all.
6. Confirm warnings do not mute participants.

## Chat

1. A sends a message.
2. B sees it without full-page reload.
3. B replies.
4. Verify no duplicate messages.

## Private Invite

1. A creates a private room.
2. Generate an invite.
3. B follows the invite while signed in.
4. Verify membership is validated before LiveKit token issuance.
5. Verify revoked/expired/invalid invites fail cleanly.

## Room End

1. A ends the room using End Room.
2. Verify room status becomes ended.
3. Verify both clients disconnect LiveKit.
4. Verify B is returned to room discovery.
5. Verify a new join attempt is rejected.

## 100-Person Gate

Before claiming 100-person production readiness:

- run backend capacity/load validation through 100 active users
- verify user 101 is rejected
- run LiveKit's load testing tooling or equivalent against the production-sized media configuration
- record CPU/network/client behavior
- verify moderation and room-end under load
