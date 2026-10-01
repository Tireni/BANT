-- 030_fix_invite_token_pgcrypto_schema.sql
-- Fix invite generation when SECURITY DEFINER functions use search_path=public.
-- Supabase installs pgcrypto in the extensions schema, so schema-qualify
-- gen_random_bytes instead of relying on search_path resolution.

create extension if not exists pgcrypto with schema extensions;

create or replace function public.generate_invite_token()
returns text
language sql
volatile
set search_path = public, extensions
as $$
  select replace(
    replace(
      rtrim(encode(extensions.gen_random_bytes(12), 'base64'), '='),
      '+',
      '-'
    ),
    '/',
    '_'
  );
$$;

revoke all on function public.generate_invite_token() from public;
revoke all on function public.generate_invite_token() from anon;
grant execute on function public.generate_invite_token() to authenticated;

notify pgrst, 'reload schema';
