-- Move private room invites to Supabase as the source of truth.

create table if not exists public.room_invites (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.rooms(id) on delete cascade,
  created_by uuid not null references public.profiles(id) on delete cascade,
  invite_token text not null unique,
  invitee_user_id uuid references public.profiles(id) on delete cascade,
  status text not null default 'active',
  created_at timestamptz not null default now(),
  expires_at timestamptz,
  used_at timestamptz,
  constraint room_invites_status_check check (status in ('active', 'revoked', 'used', 'expired')),
  constraint room_invites_token_length check (char_length(invite_token) >= 32)
);

create index if not exists room_invites_room_idx on public.room_invites (room_id, status, created_at desc);
create index if not exists room_invites_created_by_idx on public.room_invites (created_by, created_at desc);
create index if not exists room_invites_invitee_idx on public.room_invites (invitee_user_id, status, created_at desc);
create index if not exists room_invites_token_idx on public.room_invites (invite_token);

alter table public.room_invites enable row level security;

alter table public.notifications
drop constraint if exists notifications_target_type_check;

alter table public.notifications
add constraint notifications_target_type_check
check (target_type is null or target_type in ('user', 'friend_request', 'room_invite', 'room', 'system'));

create or replace function public.generate_invite_token()
returns text
language sql
volatile
as $$
  select replace(replace(rtrim(encode(gen_random_bytes(24), 'base64'), '='), '+', '-'), '/', '_');
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

  select *
  into room_row
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

  loop
    new_token := public.generate_invite_token();
    begin
      insert into public.room_invites (room_id, created_by, invite_token, invitee_user_id, expires_at)
      values (p_room_id, current_user_id, new_token, p_invitee_user_id, p_expires_at)
      returning *
      into invite_row;
      exit;
    exception
      when unique_violation then
        null;
    end;
  end loop;

  if p_invitee_user_id is not null then
    select display_name into inviter_name
    from public.profiles
    where id = current_user_id;

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

create or replace function public.join_private_room_with_invite_id(
  p_invite_id uuid,
  p_role text default 'listener'
)
returns public.room_members
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  invite_row public.room_invites;
begin
  if current_user_id is null then
    raise exception 'Not authenticated';
  end if;

  select *
  into invite_row
  from public.room_invites
  where id = p_invite_id;

  if invite_row.id is null then
    raise exception 'Invite is invalid';
  end if;

  if invite_row.invitee_user_id is not null and invite_row.invitee_user_id <> current_user_id then
    raise exception 'You do not have access to this room';
  end if;

  return public.join_private_room_with_invite(invite_row.invite_token, p_role);
end;
$$;

create or replace function public.revoke_room_invite(p_invite_id uuid)
returns public.room_invites
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  invite_row public.room_invites;
begin
  if current_user_id is null then
    raise exception 'Not authenticated';
  end if;

  update public.room_invites ri
  set status = 'revoked'
  from public.rooms r
  where ri.id = p_invite_id
    and ri.room_id = r.id
    and coalesce(r.owner_id, r.host_id) = current_user_id
    and ri.status = 'active'
  returning ri.*
  into invite_row;

  if invite_row.id is null then
    raise exception 'Invite not found';
  end if;

  return invite_row;
end;
$$;

create or replace function public.resolve_room_invite(p_invite_token text)
returns table (
  room_id uuid,
  room_title text,
  room_status text,
  room_privacy text,
  invite_status text,
  expires_at timestamptz,
  invitee_user_id uuid
)
language plpgsql
security definer
set search_path = public
stable
as $$
begin
  return query
  select
    r.id,
    r.title,
    r.status,
    r.privacy,
    case
      when ri.status <> 'active' then ri.status
      when ri.expires_at is not null and ri.expires_at <= now() then 'expired'
      else ri.status
    end,
    ri.expires_at,
    ri.invitee_user_id
  from public.room_invites ri
  join public.rooms r on r.id = ri.room_id
  where ri.invite_token = p_invite_token;
end;
$$;

create or replace function public.join_private_room_with_invite(
  p_invite_token text,
  p_role text default 'listener'
)
returns public.room_members
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  requested_role text := coalesce(p_role, 'listener');
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

  select *
  into invite_row
  from public.room_invites
  where invite_token = p_invite_token
  for update;

  if invite_row.id is null then
    raise exception 'Invite is invalid';
  end if;

  select *
  into room_row
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

  -- Block checks should be added here when the launch blocks table exists.

  if coalesce(room_row.owner_id, room_row.host_id) = current_user_id then
    requested_role := 'owner';
  end if;

  select count(*)
  into active_count
  from public.room_members rm
  where rm.room_id = room_row.id
    and rm.left_at is null;

  if not public.is_active_room_member(room_row.id, current_user_id) and active_count >= room_row.max_participants then
    raise exception 'Room is full';
  end if;

  insert into public.room_members (room_id, user_id, role, left_at, joined_at)
  values (room_row.id, current_user_id, requested_role, null, now())
  on conflict (room_id, user_id) do update
    set role = case when public.room_owner_id(room_row.id) = excluded.user_id then 'owner' else excluded.role end,
        left_at = null,
        joined_at = now()
  returning *
  into member_row;

  if invite_row.invitee_user_id is not null then
    update public.room_invites
    set status = 'used', used_at = now()
    where id = invite_row.id;
  end if;

  return member_row;
end;
$$;

create or replace function public.can_read_room(p_room_id uuid, p_user_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.rooms r
    where r.id = p_room_id
      and (
        r.privacy = 'public'
        or coalesce(r.owner_id, r.host_id) = p_user_id
        or public.is_active_room_member(r.id, p_user_id)
        or exists (
          select 1
          from public.room_invites ri
          where ri.room_id = r.id
            and ri.invitee_user_id = p_user_id
            and ri.status = 'active'
            and (ri.expires_at is null or ri.expires_at > now())
        )
      )
  );
$$;

grant execute on function public.create_room_invite(uuid, uuid, timestamptz) to authenticated;
grant execute on function public.revoke_room_invite(uuid) to authenticated;
grant execute on function public.resolve_room_invite(text) to authenticated;
grant execute on function public.join_private_room_with_invite(text, text) to authenticated;
grant execute on function public.join_private_room_with_invite_id(uuid, text) to authenticated;

drop policy if exists "Owners read room invites" on public.room_invites;
create policy "Owners read room invites"
on public.room_invites for select
to authenticated
using (
  exists (
    select 1 from public.rooms r
    where r.id = room_id
      and coalesce(r.owner_id, r.host_id) = auth.uid()
  )
);

drop policy if exists "Invitees read own direct invites" on public.room_invites;
create policy "Invitees read own direct invites"
on public.room_invites for select
to authenticated
using (invitee_user_id = auth.uid());

drop policy if exists "Owners create room invites" on public.room_invites;
create policy "Owners create room invites"
on public.room_invites for insert
to authenticated
with check (
  created_by = auth.uid()
  and exists (
    select 1 from public.rooms r
    where r.id = room_id
      and coalesce(r.owner_id, r.host_id) = auth.uid()
  )
);

drop policy if exists "Owners update room invites" on public.room_invites;
create policy "Owners update room invites"
on public.room_invites for update
to authenticated
using (
  exists (
    select 1 from public.rooms r
    where r.id = room_id
      and coalesce(r.owner_id, r.host_id) = auth.uid()
  )
)
with check (
  exists (
    select 1 from public.rooms r
    where r.id = room_id
      and coalesce(r.owner_id, r.host_id) = auth.uid()
  )
);

do $$
begin
  alter publication supabase_realtime add table public.room_invites;
exception
  when duplicate_object then null;
  when undefined_object then null;
end $$;
