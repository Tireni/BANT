-- 024_authoritative_room_creation.sql
-- Create rooms through a server-authorized RPC so ownership cannot be spoofed and
-- client-side RLS/schema drift cannot block legitimate room creation.

create or replace function public.create_room(
  p_title text,
  p_slug text,
  p_description text default '',
  p_category text default 'General',
  p_privacy text default 'public',
  p_max_participants integer default 20,
  p_noise_control_enabled boolean default false
)
returns public.rooms
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  room_row public.rooms;
  normalized_title text := btrim(coalesce(p_title, ''));
  normalized_slug text := btrim(coalesce(p_slug, ''));
  normalized_description text := coalesce(p_description, '');
begin
  if current_user_id is null then
    raise exception 'Not authenticated';
  end if;

  if not exists (select 1 from public.profiles p where p.id = current_user_id) then
    raise exception 'Profile required';
  end if;

  if char_length(normalized_title) < 3 or char_length(normalized_title) > 80 then
    raise exception 'Room title must be between 3 and 80 characters';
  end if;

  if normalized_slug = '' then
    raise exception 'Room slug is required';
  end if;

  if char_length(normalized_description) > 280 then
    raise exception 'Room description must be 280 characters or fewer';
  end if;

  if p_category not in (
    'Feed', 'Gaming', 'Anime', 'Art', 'Philosophy', 'Music', 'Technology',
    'Movies', 'Sports', 'Books', 'Fashion', 'Culture', 'Relationships',
    'Business', 'Comedy', 'Science', 'Lifestyle', 'Food', 'Travel', 'General'
  ) then
    raise exception 'Invalid room category';
  end if;

  if p_privacy not in ('public', 'private') then
    raise exception 'Invalid room privacy';
  end if;

  if p_max_participants is null or p_max_participants < 5 or p_max_participants > 100 then
    raise exception 'Room capacity must be between 5 and 100';
  end if;

  insert into public.rooms (
    title,
    slug,
    description,
    category,
    privacy,
    host_id,
    owner_id,
    status,
    max_participants,
    noise_control_enabled
  )
  values (
    normalized_title,
    normalized_slug,
    normalized_description,
    p_category,
    p_privacy,
    current_user_id,
    current_user_id,
    'live',
    p_max_participants,
    coalesce(p_noise_control_enabled, false)
  )
  returning *
  into room_row;

  return room_row;
end;
$$;

revoke all on function public.create_room(text, text, text, text, text, integer, boolean) from public;
grant execute on function public.create_room(text, text, text, text, text, integer, boolean) to authenticated;

-- Room creation now has one authoritative mutation path.
revoke insert on table public.rooms from authenticated;

drop policy if exists "Users create own rooms" on public.rooms;
create policy "Room creation goes through RPC only"
on public.rooms for insert
to authenticated
with check (false);
