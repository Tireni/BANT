-- 016_disable_insecure_username_lookup.sql
-- Username-to-email lookup exposed private auth email addresses to anon callers.
-- Username login is deferred until it can be handled by a server-side auth proxy.

revoke all on function public.login_username_lookup(text) from public;
revoke all on function public.login_username_lookup(text) from anon;
revoke all on function public.login_username_lookup(text) from authenticated;

drop function if exists public.login_username_lookup(text);

