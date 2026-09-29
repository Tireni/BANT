-- Backend-authoritative live-room moderation controls.

alter table public.room_members
  add column if not exists is_muted boolean not null default false,
  add column if not exists muted_by_owner uuid references public.profiles(id) on delete set null,
  add column if not exists muted_at timestamptz;

create index if not exists room_members_active_capacity_idx
on public.room_members (room_id, left_at)
where left_at is null;

create or replace function public.moderate_room_members(
  p_room_id uuid,
  p_target_user_ids uuid[],
  p_action text
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  normalized_action text := lower(coalesce(p_action, ''));
  affected_count integer := 0;
begin
  if current_user_id is null then
    raise exception 'Not authenticated';
  end if;

  if public.room_owner_id(p_room_id) <> current_user_id then
    raise exception 'Only the room owner can moderate this room';
  end if;

  if normalized_action not in ('mute', 'unmute') then
    raise exception 'Invalid moderation action';
  end if;

  update public.room_members rm
  set is_muted = normalized_action = 'mute',
      muted_by_owner = case when normalized_action = 'mute' then current_user_id else null end,
      muted_at = case when normalized_action = 'mute' then now() else null end
  where rm.room_id = p_room_id
    and rm.left_at is null
    and rm.user_id <> current_user_id
    and rm.user_id = any(p_target_user_ids)
    and exists (
      select 1
      from public.rooms r
      where r.id = p_room_id
        and r.status = 'live'
    );

  get diagnostics affected_count = row_count;
  return affected_count;
end;
$$;

create or replace function public.moderate_room_all_members(
  p_room_id uuid,
  p_action text
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  target_ids uuid[];
begin
  if current_user_id is null then
    raise exception 'Not authenticated';
  end if;

  if public.room_owner_id(p_room_id) <> current_user_id then
    raise exception 'Only the room owner can moderate this room';
  end if;

  select coalesce(array_agg(rm.user_id), '{}')
  into target_ids
  from public.room_members rm
  where rm.room_id = p_room_id
    and rm.left_at is null
    and rm.user_id <> current_user_id;

  return public.moderate_room_members(p_room_id, target_ids, p_action);
end;
$$;

create or replace function public.send_room_warning(
  p_room_id uuid,
  p_target_user_ids uuid[] default null
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  target_ids uuid[];
  affected_count integer := 0;
begin
  if current_user_id is null then
    raise exception 'Not authenticated';
  end if;

  if public.room_owner_id(p_room_id) <> current_user_id then
    raise exception 'Only the room owner can warn this room';
  end if;

  if not exists (
    select 1
    from public.rooms r
    where r.id = p_room_id
      and r.status = 'live'
      and r.noise_control_enabled = true
  ) then
    raise exception 'Noise Control is not enabled';
  end if;

  if p_target_user_ids is null or cardinality(p_target_user_ids) = 0 then
    select coalesce(array_agg(rm.user_id), '{}')
    into target_ids
    from public.room_members rm
    where rm.room_id = p_room_id
      and rm.left_at is null
      and rm.user_id <> current_user_id;
  else
    select coalesce(array_agg(rm.user_id), '{}')
    into target_ids
    from public.room_members rm
    where rm.room_id = p_room_id
      and rm.left_at is null
      and rm.user_id <> current_user_id
      and rm.user_id = any(p_target_user_ids);
  end if;

  insert into public.room_warnings (room_id, sender_id, target_user_id, message)
  select p_room_id, current_user_id, target_id, 'Easy on the noise'
  from unnest(target_ids) as target_id;

  get diagnostics affected_count = row_count;
  return affected_count;
end;
$$;

create or replace function public.end_room(p_room_id uuid)
returns public.rooms
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  room_row public.rooms;
begin
  if current_user_id is null then
    raise exception 'Not authenticated';
  end if;

  update public.rooms
  set status = 'ended',
      ended_at = now()
  where id = p_room_id
    and status = 'live'
    and coalesce(owner_id, host_id) = current_user_id
  returning *
  into room_row;

  if room_row.id is null then
    raise exception 'Only the room owner can end this room';
  end if;

  update public.room_members
  set left_at = coalesce(left_at, now())
  where room_id = p_room_id
    and left_at is null;

  update public.room_invites
  set status = 'revoked'
  where room_id = p_room_id
    and status = 'active';

  return room_row;
end;
$$;

create or replace function public.prevent_non_owner_mute_field_updates()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.room_owner_id(new.room_id) = auth.uid() then
    return new;
  end if;

  if new.is_muted is distinct from old.is_muted
    or new.muted_by_owner is distinct from old.muted_by_owner
    or new.muted_at is distinct from old.muted_at then
    raise exception 'Only the room owner can change host mute state';
  end if;

  return new;
end;
$$;

drop trigger if exists room_members_protect_mute_fields on public.room_members;
create trigger room_members_protect_mute_fields
before update on public.room_members
for each row execute function public.prevent_non_owner_mute_field_updates();

grant execute on function public.moderate_room_members(uuid, uuid[], text) to authenticated;
grant execute on function public.moderate_room_all_members(uuid, text) to authenticated;
grant execute on function public.send_room_warning(uuid, uuid[]) to authenticated;
grant execute on function public.end_room(uuid) to authenticated;

drop policy if exists "Hosts can send room warnings" on public.room_warnings;
drop policy if exists "Users can insert room warnings" on public.room_warnings;
create policy "No direct room warning inserts"
on public.room_warnings for insert
to authenticated
with check (false);

drop policy if exists "Users can read own room warnings" on public.room_warnings;
create policy "Users can read own room warnings"
on public.room_warnings for select
to authenticated
using (
  target_user_id = auth.uid()
  or sender_id = auth.uid()
  or public.room_owner_id(room_id) = auth.uid()
);
