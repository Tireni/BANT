# BANT Production Smoke Test

Use two real accounts in two separate browsers or browser profiles.

## Setup

- Apply canonical migrations `001` through latest. Do not run `000_complete_setup.sql` on a fresh production project.
- Confirm Supabase Auth email/password works.
- Confirm Google OAuth callback URLs are configured for the deployed domain and `bant://auth/callback`.
- Configure TURN for real network testing when using mesh voice.

## User A

1. Sign up with email/password.
2. Confirm email if Supabase email confirmation is enabled.
3. Complete profile and interests.
4. Create a public room with Noise Control enabled and capacity 2-8.
5. Confirm User A enters as owner/host.

## User B

1. Sign up or log in with email/password.
2. Complete onboarding.
3. Join User A's public room.
4. Confirm both users see the same participants.
5. Confirm A hears B and B hears A.
6. Toggle self mute and confirm local audio state changes.

## Moderation

1. User A mutes User B.
2. Confirm User B shows host-muted and cannot self-unmute.
3. User A releases User B.
4. Confirm User B can self-mute/unmute again.
5. User A sends a Noise Control warning to User B.
6. Confirm User B sees the warning overlay for a few seconds.
7. User A ends the room.
8. Confirm both clients leave the ended room and new joins are rejected.

## Friends And Invites

1. User B sends User A a friend request.
2. User A accepts.
3. Confirm both users see friendship state after refresh.
4. User A creates a private room invite.
5. User B joins from the invite link.
6. Test invalid, revoked, expired, full-room, and ended-room invite paths.

## Security Checks

1. Try logging in with username. It should not be offered in this build.
2. Try a non-owner moderation action. It should fail.
3. Try joining a full room. It should fail with a friendly message.
4. Try joining an ended room. It should fail.

