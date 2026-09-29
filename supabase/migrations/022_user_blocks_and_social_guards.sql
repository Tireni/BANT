-- Launch safety: user blocking and enforcement across friendships and direct room invitations.

create table if not exists public.user_blocks (
  blocker_id uuid not null references public.profiles(id) on delete cascade,
  blocked_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  constraint user_blocks_no_self check (blocker_id <> blocked_id)
);

create index if not exists user_blocks_blocked_idx
  on public.user_blocks (blocked_id, created_at desc);

alter table public.user_blocks enable row level security;

drop policy if exists "Users read own blocks" on public.user_blocks;
create policy "Users read own blocks"
on public.user_blocks for select
to authenticated
using (blocker_id = auth.uid());

drop policy if exists "Users create own blocks" on public.user_blocks;
create policy "Users create own blocks"
on public.user_blocks for insert
to authenticated
with check (blocker_id = auth.uid() and blocker_id <> blocked_id);

drop policy if exists "Users delete own blocks" on public.user_blocks;
create policy "Users delete own blocks"
on public.user_blocks for delete
to authenticated
using (blocker_id = auth.uid());

create or replace function public.users_blocked_between(p_user_1 uuid, p_user_2 uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.user_blocks b
    where (b.blocker_id = p_user_1 and b.blocked_id = p_user_2)
       or (b.blocker_id = p_user_2 and b.blocked_id = p_user_1)
  );
$$;

create or replace function public.block_user(p_blocked_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
begin
  if current_user_id is null then
    raise exception 'Not authenticated';
  end if;
  if p_blocked_id is null or p_blocked_id = current_user_id then
    raise exception 'Invalid user';
  end if;
  if not exists (select 1 from public.profiles where id = p_blocked_id) then
    raise exception 'User not found';
  end if;

  insert into public.user_blocks (blocker_id, blocked_id)
  values (current_user_id, p_blocked_id)
  on conflict do nothing;

  delete from public.friend_requests
  where status = 'pending'
    and (
      (sender_id = current_user_id and receiver_id = p_blocked_id)
      or (sender_id = p_blocked_id and receiver_id = current_user_id)
    );

  delete from public.friendships
  where user_a = public.friend_pair_a(current_user_id, p_blocked_id)
    and user_b = public.friend_pair_b(current_user_id, p_blocked_id);

  update public.room_invites
  set status = 'revoked'
  where status = 'active'
    and invitee_user_id is not null
    and (
      (created_by = current_user_id and invitee_user_id = p_blocked_id)
      or (created_by = p_blocked_id and invitee_user_id = current_user_id)
    );

  return true;
end;
$$;

create or replace function public.unblock_user(p_blocked_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
begin
  if current_user_id is null then
    raise exception 'Not authenticated';
  end if;

  delete from public.user_blocks
  where blocker_id = current_user_id
    and blocked_id = p_blocked_id;

  return true;
end;
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
  if public.users_blocked_between(current_user_id, p_receiver_id) then
    raise exception 'Friend request unavailable';
  end if;

  select display_name into receiver_name from public.profiles where id = p_receiver_id;
  if receiver_name is null then
    raise exception 'User not found';
  end if;
  if public.are_friends(current_user_id, p_receiver_id) then
    raise exception 'Already friends';
  end if;
  if exists (
    select 1 from public.friend_requests fr
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
  returning * into request_row;

  select display_name into sender_name from public.profiles where id = current_user_id;

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

create or replace function public.create_room_invite(
  p_room_id uuid,
  p_invitee_user_id uuid default null,
  p_expires_at timestamptz default null
)
returns public.room_invites
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  room_row public.rooms;
  inviter_name text;
  invite_row public.room_invites;
  new_token text;
begin
  if current_user_id is null then
    raise exception 'Not authenticated';
  end if;

  select * into room_row
  from public.rooms
  where id = p_room_id
  for update;

  if room_row.id is null then
    raise exception 'Room not found';
  end if;
  if coalesce(room_row.owner_id, room_row.host_id) <> current_user_id then
    raise exception 'Only the room owner can create invites';
  end if;
  if room_row.status <> 'live' then
    raise exception 'This room has ended';
  end if;
  if p_invitee_user_id is not null and p_invitee_user_id = current_user_id then
    raise exception 'You cannot invite yourself';
  end if;
  if p_invitee_user_id is not null and public.users_blocked_between(current_user_id, p_invitee_user_id) then
    raise exception 'Invite unavailable';
  end if;

  loop
    new_token := public.generate_invite_token();
    begin
      insert into public.room_invites (room_id, created_by, invite_token, invitee_user_id, expires_at)
      values (p_room_id, current_user_id, new_token, p_invitee_user_id, p_expires_at)
      returning * into invite_row;
      exit;
    exception when unique_violation then
      null;
    end;
  end loop;

  if p_invitee_user_id is not null then
    select display_name into inviter_name from public.profiles where id = current_user_id;
    insert into public.notifications (user_id, actor_id, type, body, target_id, target_type)
    values (
      p_invitee_user_id,
      current_user_id,
      'room_invite',
      coalesce(inviter_name, 'Someone') || ' invited you to ' || room_row.title || '.',
      invite_row.id,
      'room_invite'
    );
  end if;

  return invite_row;
end;
$$;

create or replace function public.join_private_room_with_invite(
  p_invite_token text,
  p_role text default 'speaker'
)
returns public.room_members
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  requested_role text := coalesce(p_role, 'speaker');
  invite_row public.room_invites;
  room_row public.rooms;
  active_count integer;
  member_row public.room_members;
begin
  if current_user_id is null then
    raise exception 'Not authenticated';
  end if;
  if requested_role not in ('speaker', 'listener') then
    raise exception 'Invalid room role';
  end if;

  select * into invite_row
  from public.room_invites
  where invite_token = p_invite_token
  for update;

  if invite_row.id is null then
    raise exception 'Invite is invalid';
  end if;

  select * into room_row
  from public.rooms
  where id = invite_row.room_id
  for update;

  if room_row.id is null then
    raise exception 'Invite is invalid';
  end if;
  if room_row.status <> 'live' then
    raise exception 'This room has ended';
  end if;
  if invite_row.status <> 'active' then
    raise exception 'Invite is invalid';
  end if;
  if invite_row.expires_at is not null and invite_row.expires_at <= now() then
    update public.room_invites set status = 'expired' where id = invite_row.id;
    raise exception 'Invite has expired';
  end if;
  if invite_row.invitee_user_id is not null and invite_row.invitee_user_id <> current_user_id then
    raise exception 'You do not have access to this room';
  end if;
  if public.users_blocked_between(current_user_id, invite_row.created_by) then
    raise exception 'You do not have access to this room';
  end if;

  if coalesce(room_row.owner_id, room_row.host_id) = current_user_id then
    requested_role := 'owner';
  end if;

  select count(*) into active_count
  from public.room_members rm
  where rm.room_id = room_row.id
    and rm.left_at is null;

  if not public.is_active_room_member(room_row.id, current_user_id)
     and active_count >= room_row.max_participants then
    raise exception 'Room is full';
  end if;

  insert into public.room_members (room_id, user_id, role, left_at, joined_at)
  values (room_row.id, current_user_id, requested_role, null, now())
  on conflict (room_id, user_id) do update
    set role = case when public.room_owner_id(room_row.id) = excluded.user_id then 'owner' else excluded.role end,
        left_at = null,
        joined_at = now()
  returning * into member_row;

  if invite_row.invitee_user_id is not null then
    update public.room_invites
    set status = 'used', used_at = now()
    where id = invite_row.id;
  end if;

  return member_row;
end;
$$;

revoke all on function public.users_blocked_between(uuid, uuid) from public;
grant execute on function public.users_blocked_between(uuid, uuid) to authenticated;
revoke all on function public.block_user(uuid) from public;
grant execute on function public.block_user(uuid) to authenticated;
revoke all on function public.unblock_user(uuid) from public;
grant execute on function public.unblock_user(uuid) to authenticated;
revoke all on function public.send_friend_request(uuid) from public;
grant execute on function public.send_friend_request(uuid) to authenticated;
revoke all on function public.create_room_invite(uuid, uuid, timestamptz) from public;
grant execute on function public.create_room_invite(uuid, uuid, timestamptz) to authenticated;
revoke all on function public.join_private_room_with_invite(text, text) from public;
grant execute on function public.join_private_room_with_invite(text, text) to authenticated;
