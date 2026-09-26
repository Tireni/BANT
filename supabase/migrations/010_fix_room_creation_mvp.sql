-- Fix the create-room MVP schema so the app can persist the fields the UI expects.

alter table public.rooms
  add column if not exists max_participants integer not null default 20,
  add column if not exists noise_control_enabled boolean not null default false;

alter table public.rooms
  alter column max_participants set default 20,
  alter column noise_control_enabled set default false;

-- Expand categories to match the live app and keep room creation valid.
alter table public.rooms
drop constraint if exists rooms_category_check;

alter table public.rooms
  add constraint rooms_category_check
  check (
    category in (
      'Feed',
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
      'General',
      'Gist',
      'Study',
      'Random',
      'Career',
      'Freshers'
    )
  );

alter table public.rooms
  add constraint rooms_max_participants_check check (max_participants between 5 and 100);

alter table public.room_members
  add column if not exists is_muted boolean not null default false,
  add column if not exists muted_by_owner uuid references public.profiles(id) on delete set null,
  add column if not exists muted_at timestamptz;

drop policy if exists "Users update own room membership" on public.room_members;
create policy "Users update own room membership"
on public.room_members for update
to authenticated
using (user_id = auth.uid())
with check (
  user_id = auth.uid()
  and role in ('host', 'speaker', 'listener')
);

drop policy if exists "Room owners can manage memberships" on public.room_members;
create policy "Room owners can manage memberships"
on public.room_members for update
to authenticated
using (
  exists (
    select 1
    from public.rooms r
    where r.id = room_members.room_id
      and r.host_id = auth.uid()
  )
)
with check (
  exists (
    select 1
    from public.rooms r
    where r.id = room_members.room_id
      and r.host_id = auth.uid()
  )
  and user_id <> auth.uid()
);

-- Create room warnings support for the Noise Control feature.
create table if not exists public.room_warnings (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.rooms(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  target_user_id uuid references public.profiles(id) on delete set null,
  message text not null default 'Easy on the noise',
  created_at timestamptz not null default now()
);

alter table public.room_warnings enable row level security;

drop policy if exists "Hosts can send room warnings" on public.room_warnings;
create policy "Hosts can send room warnings"
on public.room_warnings for insert
to authenticated
with check (
  sender_id = auth.uid()
  and exists (
    select 1
    from public.rooms r
    where r.id = room_warnings.room_id
      and r.host_id = auth.uid()
  )
);

drop policy if exists "Users can read own room warnings" on public.room_warnings;
create policy "Users can read own room warnings"
on public.room_warnings for select
to authenticated
using (
  target_user_id = auth.uid()
  or sender_id = auth.uid()
  or exists (
    select 1
    from public.rooms r
    where r.id = room_warnings.room_id
      and r.host_id = auth.uid()
  )
);

create or replace function public.ensure_owner_moderation_access()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (
    select 1
    from public.rooms r
    where r.id = new.room_id
      and r.host_id = auth.uid()
  ) then
    raise exception 'Only the room owner can moderate this room';
  end if;
  return new;
end;
$$;

create trigger room_warnings_owner_check
before insert on public.room_warnings
for each row execute function public.ensure_owner_moderation_access();

-- Ensure room creation remains safe for authenticated users.
drop policy if exists "Users create own rooms" on public.rooms;
create policy "Users create own rooms"
on public.rooms for insert
to authenticated
with check (
  host_id = auth.uid()
  and title is not null and char_length(trim(title)) between 3 and 80
  and max_participants between 5 and 100
);

-- Allow owner to manage room and members without recursive checks.
drop policy if exists "Hosts update own rooms" on public.rooms;
create policy "Hosts update own rooms"
on public.rooms for update
to authenticated
using (host_id = auth.uid())
with check (host_id = auth.uid());

-- Ensure room_members is safe and usable for the owner membership insert.
drop policy if exists "Users read visible room members" on public.room_members;
create policy "Users read visible room members"
on public.room_members for select
to authenticated
using (
  user_id = auth.uid()
  or exists (
    select 1
    from public.rooms r
    where r.id = room_members.room_id
      and (
        r.host_id = auth.uid()
        or r.privacy = 'public'
      )
  )
);

drop policy if exists "Users join visible rooms as themselves" on public.room_members;
create policy "Users join visible rooms as themselves"
on public.room_members for insert
to authenticated
with check (
  user_id = auth.uid()
  and role in ('host', 'speaker', 'listener')
  and exists (
    select 1
    from public.rooms r
    where r.id = room_members.room_id
      and r.status = 'live'
      and (
        r.privacy = 'public'
        or r.host_id = auth.uid()
      )
  )
);

-- Keep the creator's host membership insert valid when a new room is created.
drop trigger if exists rooms_add_host_member on public.rooms;
create trigger rooms_add_host_member
after insert on public.rooms
for each row execute function public.add_room_host_member();

create or replace function public.delete_room_if_empty()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if exists (
    select 1
    from public.room_members rm
    where rm.room_id = coalesce(NEW.room_id, OLD.room_id)
      and rm.left_at is null
  ) then
    return coalesce(NEW, OLD);
  end if;

  delete from public.rooms r
  where r.id = coalesce(NEW.room_id, OLD.room_id);

  return coalesce(NEW, OLD);
end;
$$;

delete from public.rooms r
where r.status = 'ended'
  and not exists (
    select 1
    from public.room_members rm
    where rm.room_id = r.id
      and rm.left_at is null
  );

create table if not exists public.voice_signals (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.rooms(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  kind text not null,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint voice_signals_kind_check check (kind in ('offer', 'answer', 'ice', 'leave'))
);

create index if not exists voice_signals_room_created_idx on public.voice_signals (room_id, created_at desc);
create index if not exists voice_signals_recipient_idx on public.voice_signals (recipient_id, created_at desc);

alter table public.voice_signals enable row level security;

drop policy if exists "Room members can read their voice signals" on public.voice_signals;
create policy "Room members can read their voice signals"
on public.voice_signals for select
to authenticated
using (
  recipient_id = auth.uid()
  and exists (
    select 1 from public.room_members rm
    where rm.room_id = voice_signals.room_id
      and rm.user_id = auth.uid()
      and rm.left_at is null
  )
);

drop policy if exists "Room members can send voice signals" on public.voice_signals;
create policy "Room members can send voice signals"
on public.voice_signals for insert
to authenticated
with check (
  sender_id = auth.uid()
  and sender_id <> recipient_id
  and exists (
    select 1 from public.room_members sender_member
    where sender_member.room_id = voice_signals.room_id
      and sender_member.user_id = auth.uid()
      and sender_member.left_at is null
  )
  and exists (
    select 1 from public.room_members recipient_member
    where recipient_member.room_id = voice_signals.room_id
      and recipient_member.user_id = voice_signals.recipient_id
      and recipient_member.left_at is null
  )
);

do $$
begin
  alter publication supabase_realtime add table public.room_members;
exception
  when duplicate_object then null;
  when undefined_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.voice_signals;
exception
  when duplicate_object then null;
  when undefined_object then null;
end $$;

drop trigger if exists room_members_cleanup_empty_room on public.room_members;
create trigger room_members_cleanup_empty_room
after update of left_at or delete on public.room_members
for each row execute function public.delete_room_if_empty();
