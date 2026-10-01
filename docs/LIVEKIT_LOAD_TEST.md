# BANT 100-Person Load Validation

BANT's production media path uses LiveKit SFU. Database capacity and media capacity must be validated separately.

## 1. Supabase membership/capacity test

Use a dedicated staging Supabase project only.

Set:

```bash
TEST_SUPABASE_URL=...
TEST_SUPABASE_ANON_KEY=...
TEST_SUPABASE_SERVICE_ROLE_KEY=...
ALLOW_BANT_LOAD_TEST=yes
```

Run:

```bash
npm run loadtest:room
```

The script creates temporary staging users, creates a 100-person room, joins until there are 100 active members, confirms the active count is exactly 100, verifies the 101st join is rejected, ends the room, and cleans up test users.

Never point this script at the public production database.

## 2. LiveKit media validation

Before describing the deployment as 100-person production validated:

1. Deploy the `livekit-token` Edge Function against the staging Supabase project.
2. Configure staging LiveKit secrets.
3. Use LiveKit's supported load-testing tooling or provider test facilities for the same LiveKit deployment intended for launch.
4. Ramp tests through 10, 50, then 100 connected participants.
5. Include realistic audio publishers/subscribers rather than connection-only clients.
6. Verify reconnect behavior, participant churn, self-mute, host mute/release, and room end.
7. Record client CPU/memory, connection failures, reconnect failures, and LiveKit server/provider metrics.
8. Repeat from representative mobile and fixed networks where possible.

A code review or database capacity test alone is not evidence that 100 simultaneous media participants have been validated.
