# BANT Production Checklist

## Backend

- [ ] Canonical migrations `001` through latest applied.
- [ ] `000_complete_setup.sql` treated as historical snapshot only.
- [ ] RLS policies verified on profiles, rooms, room members, voice signals, messages, notifications, friendships, invites, warnings, reports, and feedback.
- [ ] RPC execute grants reviewed and limited to required roles.
- [ ] Realtime enabled for required tables.
- [ ] Avatar storage bucket and user-scoped policies verified.

## Auth

- [ ] Email signup/login verified.
- [ ] Username login intentionally removed until server-side auth proxy is built.
- [ ] Google web callback URL configured.
- [ ] Google native `bant://auth/callback` configured.
- [ ] Confirmed first-time users complete profile setup.

## Rooms

- [ ] Public room creation works.
- [ ] Private invite join works.
- [ ] Capacity cap of 2-8 enforced in UI and database.
- [ ] End-room flow marks active members as left and blocks new joins.
- [ ] Non-owner moderation blocked.

## Voice

- [ ] TURN server configured for production networks.
- [ ] Two-user audio verified.
- [ ] Reconnect tested.
- [ ] Self mute tested.
- [ ] Host mute tested.
- [ ] Mesh limit accepted for closed beta, or SFU provider selected before scale.

## Social

- [ ] Friend request sent.
- [ ] Friend request accepted.
- [ ] Notifications delivered and marked read only by owner.

## Security

- [ ] Username enumeration prevented.
- [ ] No client-side username-to-email lookup.
- [ ] Private invite tokens protected.
- [ ] Non-owner moderation blocked by backend.
- [ ] Raw database errors mapped where user-facing.

## Ops

- [ ] CI passing.
- [ ] Production web build passing.
- [ ] `npm audit` reviewed.
- [ ] Error monitoring selected.
- [ ] Backup plan documented.
- [ ] Rollback plan documented.

