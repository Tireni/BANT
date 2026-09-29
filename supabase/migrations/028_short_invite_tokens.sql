-- 028_short_invite_tokens.sql
-- Allow compact BANT invite tokens while retaining strong randomness.
-- 12 random bytes = 96 bits of entropy and a 16-character base64url token.

alter table public.room_invites
drop constraint if exists room_invites_token_length;

alter table public.room_invites
add constraint room_invites_token_length
check (char_length(invite_token) >= 16);

notify pgrst, 'reload schema';
