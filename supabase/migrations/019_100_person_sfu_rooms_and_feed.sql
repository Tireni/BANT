-- Restore launch room capacity to 100 now that production audio uses an SFU.
-- Also add a lightweight feed RPC so discovery never pulls every room member/profile.

alter table public.rooms
  alter column max_participants set default 20;

alter table public.rooms
  drop constraint if exists rooms_max_participants_check;

alter table public.rooms
  add constraint rooms_max_participants_check
  check (max_participants between 5 and 100);

create index if not exists room_members_live_room_role_idx
  on public.room_members (room_id, role)
  where left_at is null;

create or replace function public.get_live_room_feed(
  p_limit integer default 25,
  p_offset integer default 0,
  p_category text default null,
  p_search text default null
)
returns table (
  id uuid,
  title text,
  slug text,
  description text,
  category text,
  privacy text,
  status text,
  owner_id uuid,
  host_id uuid,
  max_participants integer,
  noise_control_enabled boolean,
  created_at timestamptz,
  participant_count bigint,
  speaker_count bigint
)
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  current_user_id uuid := auth.uid();
  safe_limit integer := least(greatest(coalesce(p_limit, 25), 1), 50);
  safe_offset integer := greatest(coalesce(p_offset, 0), 0);
  normalized_search text := nullif(btrim(coalesce(p_search, '')), '');
begin
  if current_user_id is null then
    raise exception 'Not authenticated';
  end if;

  return query
  select
    r.id,
    r.title,
    r.slug,
    r.description,
    r.category,
    r.privacy,
    r.status,
    r.owner_id,
    r.host_id,
    r.max_participants,
    r.noise_control_enabled,
    r.created_at,
    count(rm.user_id) filter (where rm.left_at is null) as participant_count,
    count(rm.user_id) filter (
      where rm.left_at is null
        and rm.role in ('owner', 'host', 'speaker')
    ) as speaker_count
  from public.rooms r
  left join public.room_members rm on rm.room_id = r.id
  where r.status = 'live'
    and r.privacy = 'public'
    and (p_category is null or p_category = 'Feed' or r.category = p_category)
    and (
      normalized_search is null
      or r.title ilike '%' || normalized_search || '%'
      or r.description ilike '%' || normalized_search || '%'
    )
  group by
    r.id, r.title, r.slug, r.description, r.category, r.privacy, r.status,
    r.owner_id, r.host_id, r.max_participants, r.noise_control_enabled, r.created_at
  order by r.created_at desc
  limit safe_limit
  offset safe_offset;
end;
$$;

revoke all on function public.get_live_room_feed(integer, integer, text, text) from public;
grant execute on function public.get_live_room_feed(integer, integer, text, text) to authenticated;
