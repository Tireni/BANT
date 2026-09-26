create table if not exists public.follows (
  follower_id uuid not null references public.profiles(id) on delete cascade,
  following_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower_id, following_id),
  constraint follows_no_self_follow check (follower_id <> following_id)
);

create index if not exists follows_following_idx on public.follows (following_id, created_at desc);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  actor_id uuid references public.profiles(id) on delete cascade,
  type text not null,
  body text not null,
  read_at timestamptz,
  created_at timestamptz not null default now(),
  constraint notifications_type_check check (type in ('follow', 'room', 'system'))
);

create index if not exists notifications_user_created_idx on public.notifications (user_id, created_at desc);

create or replace function public.notify_follow()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  actor_name text;
begin
  select display_name into actor_name from public.profiles where id = new.follower_id;
  insert into public.notifications (user_id, actor_id, type, body)
  values (new.following_id, new.follower_id, 'follow', coalesce(actor_name, 'Someone') || ' followed you on BANT.');
  return new;
end;
$$;

drop trigger if exists follows_notify_follow on public.follows;
create trigger follows_notify_follow
after insert on public.follows
for each row execute function public.notify_follow();

alter table public.follows enable row level security;
alter table public.notifications enable row level security;

drop policy if exists "Authenticated users can read follows" on public.follows;
create policy "Authenticated users can read follows"
on public.follows for select
to authenticated
using (true);

drop policy if exists "Users can follow as themselves" on public.follows;
create policy "Users can follow as themselves"
on public.follows for insert
to authenticated
with check (follower_id = auth.uid());

drop policy if exists "Users can unfollow as themselves" on public.follows;
create policy "Users can unfollow as themselves"
on public.follows for delete
to authenticated
using (follower_id = auth.uid());

drop policy if exists "Users read own notifications" on public.notifications;
create policy "Users read own notifications"
on public.notifications for select
to authenticated
using (user_id = auth.uid());

drop policy if exists "Users update own notifications" on public.notifications;
create policy "Users update own notifications"
on public.notifications for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

do $$
begin
  alter publication supabase_realtime add table public.follows;
exception
  when duplicate_object then null;
  when undefined_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.notifications;
exception
  when duplicate_object then null;
  when undefined_object then null;
end $$;
