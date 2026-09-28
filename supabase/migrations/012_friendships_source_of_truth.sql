-- Replace launch social behavior with mutual friendships.
-- Keeps legacy follows table untouched for historical compatibility.

create table if not exists public.friend_requests (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references public.profiles(id) on delete cascade,
  receiver_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint friend_requests_no_self check (sender_id <> receiver_id),
  constraint friend_requests_status_check check (status in ('pending', 'accepted', 'declined', 'cancelled'))
);

create table if not exists public.friendships (
  id uuid primary key default gen_random_uuid(),
  user_a uuid not null references public.profiles(id) on delete cascade,
  user_b uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint friendships_no_self check (user_a <> user_b),
  constraint friendships_canonical_pair check (user_a < user_b),
  constraint friendships_unique_pair unique (user_a, user_b)
);

drop trigger if exists friend_requests_set_updated_at on public.friend_requests;
create trigger friend_requests_set_updated_at
before update on public.friend_requests
for each row execute function public.set_updated_at();

create index if not exists friend_requests_sender_idx on public.friend_requests (sender_id, status, created_at desc);
create index if not exists friend_requests_receiver_idx on public.friend_requests (receiver_id, status, created_at desc);
create index if not exists friend_requests_status_idx on public.friend_requests (status);
create index if not exists friend_requests_pair_idx on public.friend_requests (sender_id, receiver_id);
create unique index if not exists friend_requests_pending_pair_unique
on public.friend_requests (least(sender_id, receiver_id), greatest(sender_id, receiver_id))
where status = 'pending';

create index if not exists friendships_user_a_idx on public.friendships (user_a);
create index if not exists friendships_user_b_idx on public.friendships (user_b);

alter table public.notifications
  add column if not exists target_id uuid,
  add column if not exists target_type text;

alter table public.notifications
drop constraint if exists notifications_type_check;

alter table public.notifications
add constraint notifications_type_check
check (type in ('friend_request', 'friend_accepted', 'room_invite', 'room', 'system', 'follow'));

alter table public.notifications
drop constraint if exists notifications_target_type_check;

alter table public.notifications
add constraint notifications_target_type_check
check (target_type is null or target_type in ('user', 'friend_request', 'room', 'system'));

create index if not exists notifications_target_idx on public.notifications (target_type, target_id);

alter table public.friend_requests enable row level security;
alter table public.friendships enable row level security;

create or replace function public.friend_pair_a(p_user_1 uuid, p_user_2 uuid)
returns uuid
language sql
immutable
as $$
  select least(p_user_1, p_user_2);
$$;

create or replace function public.friend_pair_b(p_user_1 uuid, p_user_2 uuid)
returns uuid
language sql
immutable
as $$
  select greatest(p_user_1, p_user_2);
$$;

create or replace function public.are_friends(p_user_1 uuid, p_user_2 uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.friendships f
    where f.user_a = public.friend_pair_a(p_user_1, p_user_2)
      and f.user_b = public.friend_pair_b(p_user_1, p_user_2)
  );
$$;

create or replace function public.send_friend_request(p_receiver_id uuid)
returns public.friend_requests
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  receiver_name text;
  sender_name text;
  request_row public.friend_requests;
begin
  if current_user_id is null then
    raise exception 'Not authenticated';
  end if;

  if p_receiver_id = current_user_id then
    raise exception 'You cannot friend yourself';
  end if;

  select display_name into receiver_name
  from public.profiles
  where id = p_receiver_id;

  if receiver_name is null then
    raise exception 'User not found';
  end if;

  if public.are_friends(current_user_id, p_receiver_id) then
    raise exception 'Already friends';
  end if;

  if exists (
    select 1
    from public.friend_requests fr
    where fr.status = 'pending'
      and (
        (fr.sender_id = current_user_id and fr.receiver_id = p_receiver_id)
        or (fr.sender_id = p_receiver_id and fr.receiver_id = current_user_id)
      )
  ) then
    raise exception 'A pending friend request already exists';
  end if;

  insert into public.friend_requests (sender_id, receiver_id, status)
  values (current_user_id, p_receiver_id, 'pending')
  returning *
  into request_row;

  select display_name into sender_name
  from public.profiles
  where id = current_user_id;

  insert into public.notifications (user_id, actor_id, type, body, target_id, target_type)
  values (
    p_receiver_id,
    current_user_id,
    'friend_request',
    coalesce(sender_name, 'Someone') || ' sent you a friend request.',
    request_row.id,
    'friend_request'
  );

  return request_row;
end;
$$;

create or replace function public.accept_friend_request(p_request_id uuid)
returns public.friendships
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  request_row public.friend_requests;
  receiver_name text;
  friendship_row public.friendships;
begin
  if current_user_id is null then
    raise exception 'Not authenticated';
  end if;

  select *
  into request_row
  from public.friend_requests
  where id = p_request_id
  for update;

  if request_row.id is null then
    raise exception 'Friend request not found';
  end if;

  if request_row.receiver_id <> current_user_id then
    raise exception 'Only the receiver can accept this request';
  end if;

  if request_row.status <> 'pending' then
    raise exception 'Friend request is not pending';
  end if;

  insert into public.friendships (user_a, user_b)
  values (
    public.friend_pair_a(request_row.sender_id, request_row.receiver_id),
    public.friend_pair_b(request_row.sender_id, request_row.receiver_id)
  )
  on conflict (user_a, user_b) do nothing
  returning *
  into friendship_row;

  if friendship_row.id is null then
    select *
    into friendship_row
    from public.friendships
    where user_a = public.friend_pair_a(request_row.sender_id, request_row.receiver_id)
      and user_b = public.friend_pair_b(request_row.sender_id, request_row.receiver_id);
  end if;

  update public.friend_requests
  set status = 'accepted'
  where id = p_request_id;

  select display_name into receiver_name
  from public.profiles
  where id = current_user_id;

  insert into public.notifications (user_id, actor_id, type, body, target_id, target_type)
  values (
    request_row.sender_id,
    current_user_id,
    'friend_accepted',
    coalesce(receiver_name, 'Someone') || ' accepted your friend request.',
    current_user_id,
    'user'
  );

  return friendship_row;
end;
$$;

create or replace function public.decline_friend_request(p_request_id uuid)
returns public.friend_requests
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  request_row public.friend_requests;
begin
  if current_user_id is null then
    raise exception 'Not authenticated';
  end if;

  update public.friend_requests
  set status = 'declined'
  where id = p_request_id
    and receiver_id = current_user_id
    and status = 'pending'
  returning *
  into request_row;

  if request_row.id is null then
    raise exception 'Pending friend request not found';
  end if;

  return request_row;
end;
$$;

create or replace function public.cancel_friend_request(p_request_id uuid)
returns public.friend_requests
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  request_row public.friend_requests;
begin
  if current_user_id is null then
    raise exception 'Not authenticated';
  end if;

  update public.friend_requests
  set status = 'cancelled'
  where id = p_request_id
    and sender_id = current_user_id
    and status = 'pending'
  returning *
  into request_row;

  if request_row.id is null then
    raise exception 'Pending friend request not found';
  end if;

  return request_row;
end;
$$;

grant execute on function public.are_friends(uuid, uuid) to authenticated;
grant execute on function public.send_friend_request(uuid) to authenticated;
grant execute on function public.accept_friend_request(uuid) to authenticated;
grant execute on function public.decline_friend_request(uuid) to authenticated;
grant execute on function public.cancel_friend_request(uuid) to authenticated;

drop policy if exists "Users read own friend requests" on public.friend_requests;
create policy "Users read own friend requests"
on public.friend_requests for select
to authenticated
using (sender_id = auth.uid() or receiver_id = auth.uid());

drop policy if exists "Users insert own friend requests" on public.friend_requests;
create policy "Users insert own friend requests"
on public.friend_requests for insert
to authenticated
with check (sender_id = auth.uid() and sender_id <> receiver_id);

drop policy if exists "Users update relevant friend requests" on public.friend_requests;
create policy "Users update relevant friend requests"
on public.friend_requests for update
to authenticated
using (sender_id = auth.uid() or receiver_id = auth.uid())
with check (
  (sender_id = auth.uid() and status = 'cancelled')
  or (receiver_id = auth.uid() and status in ('accepted', 'declined'))
);

drop policy if exists "Users read own friendships" on public.friendships;
create policy "Users read own friendships"
on public.friendships for select
to authenticated
using (user_a = auth.uid() or user_b = auth.uid());

-- No general insert/update/delete policies for friendships; controlled by RPC only.

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
  alter publication supabase_realtime add table public.friend_requests;
exception
  when duplicate_object then null;
  when undefined_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.friendships;
exception
  when duplicate_object then null;
  when undefined_object then null;
end $$;
