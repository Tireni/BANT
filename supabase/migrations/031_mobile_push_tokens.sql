-- BANT mobile push notification device registry.
-- Tokens are written only through the authenticated mobile-api edge function
-- using the service-role client. App users do not query this table directly.

create table if not exists public.device_push_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  token text not null unique,
  platform text not null default 'android'
    check (platform in ('android', 'ios', 'other')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists device_push_tokens_user_id_idx
  on public.device_push_tokens(user_id);

alter table public.device_push_tokens enable row level security;

revoke all on table public.device_push_tokens from anon, authenticated;
