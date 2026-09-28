-- Launch MVP database alignment for rooms, membership, categories, interests, and RLS.
-- This migration is additive and safe for existing rows.

alter table public.rooms
  add column if not exists owner_id uuid references public.profiles(id) on delete cascade,
  add column if not exists max_participants integer not null default 20,
  add column if not exists noise_control_enabled boolean not null default false,
  add column if not exists ended_at timestamptz;

update public.rooms
set owner_id = coalesce(owner_id, host_id)
where owner_id is null;

alter table public.rooms
  alter column owner_id set not null;

alter table public.rooms
  alter column max_participants set default 20,
  alter column noise_control_enabled set default false;

alter table public.rooms
drop constraint if exists rooms_category_check;

alter table public.rooms
add constraint rooms_category_check
check (
  category in (
    'General',
    'Gaming',
    'Anime',
    'Art',
    'Philosophy',
    'Music',
    'Technology',
    'Movies',
    'Sports',
    'Books',
    'Fashion',
    'Culture',
    'Relationships',
    'Business',
    'Comedy',
    'Science',
    'Lifestyle',
    'Food',
    'Travel',
    'Feed',
    'Gist',
    'Study',
    'Tech',
    'Random',
    'Career',
    'Freshers'
  )
);

alter table public.rooms
drop constraint if exists rooms_max_participants_check;

alter table public.rooms
add constraint rooms_max_participants_check
check (max_participants > 0 and max_participants <= 100);

alter table public.rooms
drop constraint if exists rooms_privacy_check;

alter table public.rooms
add constraint rooms_privacy_check
check (privacy in ('public', 'private'));

alter table public.rooms
drop constraint if exists rooms_status_check;

alter table public.rooms
add constraint rooms_status_check
check (status in ('live', 'ended'));

alter table public.room_members
drop constraint if exists room_members_role_check;

alter table public.room_members
add constraint room_members_role_check
check (role in ('owner', 'host', 'speaker', 'listener'));

update public.room_members rm
set role = 'owner'
from public.rooms r
where r.id = rm.room_id
  and coalesce(r.owner_id, r.host_id) = rm.user_id
  and rm.role = 'host';

insert into public.interests (name, slug) values
  ('General', 'general'),
  ('Gaming', 'gaming'),
  ('Anime', 'anime'),
  ('Art', 'art'),
  ('Philosophy', 'philosophy'),
  ('Music', 'music'),
  ('Technology', 'technology'),
  ('Movies', 'movies'),
  ('Sports', 'sports'),
  ('Books', 'books'),
  ('Fashion', 'fashion'),
  ('Culture', 'culture'),
  ('Relationships', 'relationships'),
  ('Business', 'business'),
  ('Comedy', 'comedy'),
  ('Science', 'science'),
  ('Lifestyle', 'lifestyle'),
  ('Food', 'food'),
  ('Travel', 'travel')
on conflict (slug) do update set name = excluded.name;

create index if not exists rooms_owner_idx on public.rooms (owner_id);
create index if not exists rooms_host_idx on public.rooms (host_id);
create index if not exists rooms_status_idx on public.rooms (status);
create index if not exists rooms_privacy_idx on public.rooms (privacy);
create index if not exists rooms_category_idx on public.rooms (category);
create index if not exists room_members_room_idx on public.room_members (room_id);
create index if not exists room_members_user_idx on public.room_members (user_id);
create index if not exists room_members_room_user_idx on public.room_members (room_id, user_id);
create index if not exists user_interests_user_idx on public.user_interests (user_id);
create index if not exists user_interests_interest_idx on public.user_interests (interest_id);

create or replace function public.room_owner_id(p_room_id uuid)
returns uuid
language sql
security definer
set search_path = public
stable
as $$
  select coalesce(r.owner_id, r.host_id)
  from public.rooms r
  where r.id = p_room_id;
$$;

create or replace function public.is_active_room_member(p_room_id uuid, p_user_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.room_members rm
    where rm.room_id = p_room_id
      and rm.user_id = p_user_id
      and rm.left_at is null
  );
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
      )
  );
$$;

create or replace function public.can_join_room(p_room_id uuid, p_user_id uuid)
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
      and r.status = 'live'
      and (
        public.is_active_room_member(r.id, p_user_id)
        or r.privacy = 'public'
        or coalesce(r.owner_id, r.host_id) = p_user_id
      )
      and (
        public.is_active_room_member(r.id, p_user_id)
        or (
          select count(*)
          from public.room_members rm
          where rm.room_id = r.id
            and rm.left_at is null
        ) < r.max_participants
      )
  );
$$;

create or replace function public.add_room_host_member()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  owner_user_id uuid := coalesce(new.owner_id, new.host_id);
begin
  insert into public.room_members (room_id, user_id, role)
  values (new.id, owner_user_id, 'owner')
  on conflict (room_id, user_id) do update
    set role = 'owner', left_at = null, joined_at = now();
  return new;
end;
$$;

drop trigger if exists rooms_add_host_member on public.rooms;
create trigger rooms_add_host_member
after insert on public.rooms
for each row execute function public.add_room_host_member();

create or replace function public.join_room(p_room_id uuid, p_role text default 'listener')
returns public.room_members
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  requested_role text := coalesce(p_role, 'listener');
  owner_user_id uuid;
  active_count integer;
  capacity integer;
  member_row public.room_members;
begin
  if current_user_id is null then
    raise exception 'Not authenticated';
  end if;

  if requested_role not in ('speaker', 'listener') then
    raise exception 'Invalid room role';
  end if;

  select coalesce(r.owner_id, r.host_id), r.max_participants
  into owner_user_id, capacity
  from public.rooms r
  where r.id = p_room_id
    and r.status = 'live'
  for update;

  if owner_user_id is null then
    raise exception 'Room is not live';
  end if;

  if owner_user_id = current_user_id then
    requested_role := 'owner';
  elsif not public.can_join_room(p_room_id, current_user_id) then
    raise exception 'Room is private or full';
  end if;

  select count(*)
  into active_count
  from public.room_members rm
  where rm.room_id = p_room_id
    and rm.left_at is null;

  if not public.is_active_room_member(p_room_id, current_user_id) and active_count >= capacity then
    raise exception 'Room is full';
  end if;

  insert into public.room_members (room_id, user_id, role, left_at, joined_at)
  values (p_room_id, current_user_id, requested_role, null, now())
  on conflict (room_id, user_id) do update
    set role = case when public.room_owner_id(p_room_id) = excluded.user_id then 'owner' else excluded.role end,
        left_at = null,
        joined_at = now()
  returning *
  into member_row;

  return member_row;
end;
$$;

grant execute on function public.room_owner_id(uuid) to authenticated;
grant execute on function public.is_active_room_member(uuid, uuid) to authenticated;
grant execute on function public.can_read_room(uuid, uuid) to authenticated;
grant execute on function public.can_join_room(uuid, uuid) to authenticated;
grant execute on function public.join_room(uuid, text) to authenticated;

drop policy if exists "Authenticated users can read visible rooms" on public.rooms;
create policy "Authenticated users can read visible rooms"
on public.rooms for select
to authenticated
using (public.can_read_room(id, auth.uid()));

drop policy if exists "Users create own rooms" on public.rooms;
create policy "Users create own rooms"
on public.rooms for insert
to authenticated
with check (
  coalesce(owner_id, host_id) = auth.uid()
  and host_id = auth.uid()
  and privacy in ('public', 'private')
  and status = 'live'
  and max_participants > 0
  and max_participants <= 100
);

drop policy if exists "Hosts update own rooms" on public.rooms;
drop policy if exists "Owners update own rooms" on public.rooms;
create policy "Owners update own rooms"
on public.rooms for update
to authenticated
using (coalesce(owner_id, host_id) = auth.uid())
with check (coalesce(owner_id, host_id) = auth.uid());

drop policy if exists "Users read visible room members" on public.room_members;
create policy "Users read visible room members"
on public.room_members for select
to authenticated
using (public.can_read_room(room_id, auth.uid()));

drop policy if exists "Users join visible rooms as themselves" on public.room_members;
create policy "Users join rooms as themselves"
on public.room_members for insert
to authenticated
with check (
  user_id = auth.uid()
  and (
    (role = 'owner' and public.room_owner_id(room_id) = auth.uid())
    or (role in ('speaker', 'listener') and public.can_join_room(room_id, auth.uid()))
  )
);

drop policy if exists "Users update own room membership" on public.room_members;
create policy "Users update own room membership"
on public.room_members for update
to authenticated
using (user_id = auth.uid())
with check (
  user_id = auth.uid()
  and (
    (role = 'owner' and public.room_owner_id(room_id) = auth.uid())
    or role in ('speaker', 'listener')
  )
);

drop policy if exists "Room owners can manage memberships" on public.room_members;
create policy "Room owners can manage memberships"
on public.room_members for update
to authenticated
using (public.room_owner_id(room_id) = auth.uid())
with check (public.room_owner_id(room_id) = auth.uid());

drop policy if exists "Users leave rooms as themselves" on public.room_members;
create policy "Users leave rooms as themselves"
on public.room_members for delete
to authenticated
using (user_id = auth.uid() and public.room_owner_id(room_id) <> auth.uid());

drop policy if exists "Room members can read their voice signals" on public.voice_signals;
create policy "Room members can read their voice signals"
on public.voice_signals for select
to authenticated
using (
  recipient_id = auth.uid()
  and public.is_active_room_member(room_id, auth.uid())
);

drop policy if exists "Room members can send voice signals" on public.voice_signals;
create policy "Room members can send voice signals"
on public.voice_signals for insert
to authenticated
with check (
  sender_id = auth.uid()
  and sender_id <> recipient_id
  and public.is_active_room_member(room_id, auth.uid())
  and public.is_active_room_member(room_id, recipient_id)
);

drop policy if exists "Active room members can read messages" on public.room_messages;
create policy "Active room members can read messages"
on public.room_messages for select
to authenticated
using (public.is_active_room_member(room_id, auth.uid()));

drop policy if exists "Active room members can send messages" on public.room_messages;
create policy "Active room members can send messages"
on public.room_messages for insert
to authenticated
with check (
  sender_id = auth.uid()
  and public.is_active_room_member(room_id, auth.uid())
);
