# BANT Production Checklist

## Backend
- [ ] Canonical migrations 001 through latest applied.
- [ ] 000_complete_setup.sql treated as historical snapshot only.
- [ ] get_live_room_feed RPC available.
- [ ] RLS verified for rooms, membership, friendships, invites, warnings, reports, chat, and notifications.
- [ ] Realtime enabled for rooms, room_members, room_messages, room_warnings, notifications, friend_requests, friendships, and room_invites.

## LiveKit
- [ ] LiveKit project created.
- [ ] LIVEKIT_URL configured as an Edge Function secret.
- [ ] LIVEKIT_API_KEY configured server-side.
- [ ] LIVEKIT_API_SECRET configured server-side.
- [ ] livekit-token Edge Function deployed.
- [ ] LiveKit secret is not exposed through EXPO_PUBLIC_*.
- [ ] 2-person real audio test passed.
- [ ] 10-person media test passed.
- [ ] 50-person media test passed.
- [ ] 100-person media/load test passed before claiming 100-person production validation.

## Auth
- [ ] Email signup/login verified.
- [ ] Google web callback configured.
- [ ] Google native callback configured if native launch is included.
- [ ] First-time user onboarding verified.
- [ ] Username-to-email lookup remains disabled.

## Rooms
- [ ] 5/10/15/20/30/50/75/100 capacity choices work.
- [ ] 100th active member can join a 100-person room.
- [ ] 101st active member is rejected.
- [ ] Public feed uses lightweight room summaries.
- [ ] Private invite join works.
- [ ] Room-specific realtime updates do not reload the full feed.
- [ ] Room end disconnects media clients and blocks new joins.

## Voice
- [ ] Production path uses LiveKit SFU, not mesh RTCPeerConnection fan-out.
- [ ] Remote audio tracks are attached and audible.
- [ ] Self mute works.
- [ ] Host mute overrides self-unmute.
- [ ] Release restores the user's ability to self-unmute.
- [ ] Reconnect tested.
- [ ] Leave/room-end cleanup tested.

## Moderation
- [ ] Mute one.
- [ ] Mute selected.
- [ ] Mute all.
- [ ] Release selected/all.
- [ ] Noise Control one/selected/all.
- [ ] End room owner-only.

## Social
- [ ] Friend request sent.
- [ ] Friend request accepted.
- [ ] Notifications delivered and read state enforced.

## Security
- [ ] SECURITY DEFINER grants reviewed.
- [ ] Direct membership insert blocked.
- [ ] Private invite tokens protected.
- [ ] Non-owner moderation rejected.
- [ ] Avatar storage user-scoped.
- [ ] No client-side LiveKit secret exposure.

## Ops
- [ ] GitHub CI green.
- [ ] npm ci passes.
- [ ] typecheck passes.
- [ ] tests pass.
- [ ] production web export passes.
- [ ] expo-doctor reviewed.
- [ ] error monitoring chosen.
- [ ] rollback plan documented.
