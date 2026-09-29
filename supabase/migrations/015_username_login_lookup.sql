-- Allow the login form to resolve a public username to its auth email.
-- This is intentionally narrow and returns only one email for an exact username match.

create or replace function public.login_username_lookup(p_username text)
returns text
language sql
security definer
set search_path = public, auth
stable
as $$
  select au.email
  from public.profiles p
  join auth.users au on au.id = p.id
  where p.username = lower(trim(p_username))
  limit 1;
$$;

revoke all on function public.login_username_lookup(text) from public;
grant execute on function public.login_username_lookup(text) to anon, authenticated;
