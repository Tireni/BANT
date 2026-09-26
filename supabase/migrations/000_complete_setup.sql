create extension if not exists "pgcrypto";

create table if not exists public.universities (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  short_name text not null,
  location text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.interests (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  slug text not null unique,
  created_at timestamptz not null default now()
);

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null,
  username text not null unique,
  university_id uuid references public.universities(id),
  bio text,
  avatar_url text,
  onboarding_completed boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint username_format check (username ~ '^[a-z0-9_]{3,24}$')
);

create table if not exists public.user_interests (
  user_id uuid not null references public.profiles(id) on delete cascade,
  interest_id uuid not null references public.interests(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, interest_id)
);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

alter table public.universities enable row level security;
alter table public.interests enable row level security;
alter table public.profiles enable row level security;
alter table public.user_interests enable row level security;

drop policy if exists "Universities are readable" on public.universities;
create policy "Universities are readable"
on public.universities for select
to anon, authenticated
using (true);

drop policy if exists "Authenticated users can add missing universities" on public.universities;
create policy "Authenticated users can add missing universities"
on public.universities for insert
to authenticated
with check (true);

drop policy if exists "Interests are readable" on public.interests;
create policy "Interests are readable"
on public.interests for select
to anon, authenticated
using (true);

drop policy if exists "Profiles are readable to authenticated users" on public.profiles;
create policy "Profiles are readable to authenticated users"
on public.profiles for select
to authenticated
using (true);

drop policy if exists "Users insert own profile" on public.profiles;
create policy "Users insert own profile"
on public.profiles for insert
to authenticated
with check (auth.uid() = id);

drop policy if exists "Users update own profile" on public.profiles;
create policy "Users update own profile"
on public.profiles for update
to authenticated
using (auth.uid() = id)
with check (auth.uid() = id);

drop policy if exists "Users read own interests" on public.user_interests;
create policy "Users read own interests"
on public.user_interests for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists "Users insert own interests" on public.user_interests;
create policy "Users insert own interests"
on public.user_interests for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists "Users delete own interests" on public.user_interests;
create policy "Users delete own interests"
on public.user_interests for delete
to authenticated
using (auth.uid() = user_id);

insert into public.universities (name, short_name, location) values
  ('University of Lagos', 'UNILAG', 'Lagos'),
  ('University of Ibadan', 'UI', 'Ibadan'),
  ('University of Abuja', 'UNIABUJA', 'Abuja'),
  ('Baze University', 'BAZE', 'Abuja'),
  ('Nile University of Nigeria', 'NILE', 'Abuja'),
  ('University of Nigeria, Nsukka', 'UNN', 'Nsukka'),
  ('Obafemi Awolowo University', 'OAU', 'Ile-Ife'),
  ('Ahmadu Bello University', 'ABU', 'Zaria'),
  ('Lagos State University', 'LASU', 'Lagos'),
  ('Covenant University', 'CU', 'Ota'),
  ('Babcock University', 'BABCOCK', 'Ilishan'),
  ('University of Benin', 'UNIBEN', 'Benin City'),
  ('University of Ilorin', 'UNILORIN', 'Ilorin'),
  ('University of Port Harcourt', 'UNIPORT', 'Port Harcourt'),
  ('Nnamdi Azikiwe University', 'UNIZIK', 'Awka'),
  ('Federal University of Technology Akure', 'FUTA', 'Akure'),
  ('Federal University of Technology Minna', 'FUTMINNA', 'Minna'),
  ('Bayero University Kano', 'BUK', 'Kano'),
  ('University of Jos', 'UNIJOS', 'Jos'),
  ('University of Calabar', 'UNICAL', 'Calabar'),
  ('University of Uyo', 'UNIUYO', 'Uyo'),
  ('University of Maiduguri', 'UNIMAID', 'Maiduguri')
on conflict (name) do update set short_name = excluded.short_name, location = excluded.location;

insert into public.interests (name, slug) values
  ('Gist', 'gist'),
  ('Study', 'study'),
  ('Music', 'music'),
  ('Sports', 'sports'),
  ('Tech', 'tech'),
  ('Gaming', 'gaming'),
  ('Relationships', 'relationships'),
  ('Random', 'random'),
  ('Career', 'career'),
  ('Freshers', 'freshers')
on conflict (slug) do update set name = excluded.name;
create table if not exists public.rooms (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  slug text not null,
  description text not null default '',
  category text not null,
  privacy text not null default 'public',
  university_id uuid references public.universities(id),
  host_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'live',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint rooms_title_length check (char_length(trim(title)) between 3 and 80),
  constraint rooms_description_length check (char_length(description) <= 280),
  constraint rooms_category_check check (category in ('Gist', 'Study', 'Music', 'Sports', 'Tech', 'Gaming', 'Relationships', 'Random')),
  constraint rooms_privacy_check check (privacy in ('public', 'private')),
  constraint rooms_status_check check (status in ('live', 'ended'))
);

create unique index if not exists rooms_slug_unique on public.rooms (slug);
create index if not exists rooms_status_created_idx on public.rooms (status, created_at desc);
create index if not exists rooms_university_idx on public.rooms (university_id);

create table if not exists public.room_members (
  room_id uuid not null references public.rooms(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null default 'listener',
  joined_at timestamptz not null default now(),
  left_at timestamptz,
  primary key (room_id, user_id),
  constraint room_members_role_check check (role in ('host', 'speaker', 'listener'))
);

create index if not exists room_members_user_idx on public.room_members (user_id);
create index if not exists room_members_active_room_idx on public.room_members (room_id) where left_at is null;

drop trigger if exists rooms_set_updated_at on public.rooms;
create trigger rooms_set_updated_at
before update on public.rooms
for each row execute function public.set_updated_at();

create or replace function public.add_room_host_member()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.room_members (room_id, user_id, role)
  values (new.id, new.host_id, 'host')
  on conflict (room_id, user_id) do update
    set role = 'host', left_at = null, joined_at = now();
  return new;
end;
$$;

drop trigger if exists rooms_add_host_member on public.rooms;
create trigger rooms_add_host_member
after insert on public.rooms
for each row execute function public.add_room_host_member();

alter table public.rooms enable row level security;
alter table public.room_members enable row level security;

drop policy if exists "Authenticated users can read visible rooms" on public.rooms;
create policy "Authenticated users can read visible rooms"
on public.rooms for select
to authenticated
using (
  privacy = 'public'
  or host_id = auth.uid()
  or exists (
    select 1 from public.room_members rm
    where rm.room_id = rooms.id
      and rm.user_id = auth.uid()
      and rm.left_at is null
  )
);

drop policy if exists "Users create own rooms" on public.rooms;
create policy "Users create own rooms"
on public.rooms for insert
to authenticated
with check (host_id = auth.uid());

drop policy if exists "Hosts update own rooms" on public.rooms;
create policy "Hosts update own rooms"
on public.rooms for update
to authenticated
using (host_id = auth.uid())
with check (host_id = auth.uid());

drop policy if exists "Users read visible room members" on public.room_members;
create policy "Users read visible room members"
on public.room_members for select
to authenticated
using (
  exists (
    select 1 from public.rooms r
    where r.id = room_members.room_id
      and (
        r.privacy = 'public'
        or r.host_id = auth.uid()
        or exists (
          select 1 from public.room_members mine
          where mine.room_id = r.id
            and mine.user_id = auth.uid()
            and mine.left_at is null
        )
      )
  )
);

drop policy if exists "Users join visible rooms as themselves" on public.room_members;
create policy "Users join visible rooms as themselves"
on public.room_members for insert
to authenticated
with check (
  user_id = auth.uid()
  and role in ('speaker', 'listener')
  and exists (
    select 1 from public.rooms r
    where r.id = room_members.room_id
      and r.status = 'live'
      and (r.privacy = 'public' or r.host_id = auth.uid())
  )
);

drop policy if exists "Users update own room membership" on public.room_members;
create policy "Users update own room membership"
on public.room_members for update
to authenticated
using (user_id = auth.uid())
with check (
  user_id = auth.uid()
  and role in ('speaker', 'listener')
);

drop policy if exists "Users leave rooms as themselves" on public.room_members;
create policy "Users leave rooms as themselves"
on public.room_members for delete
to authenticated
using (user_id = auth.uid() and role <> 'host');
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

drop policy if exists "Users can delete own old voice signals" on public.voice_signals;
create policy "Users can delete own old voice signals"
on public.voice_signals for delete
to authenticated
using (sender_id = auth.uid() or recipient_id = auth.uid());

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
create table if not exists public.room_messages (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.rooms(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  body text not null,
  created_at timestamptz not null default now(),
  constraint room_messages_body_length check (char_length(btrim(body)) between 1 and 500)
);

create index if not exists room_messages_room_created_idx on public.room_messages (room_id, created_at asc);
create index if not exists room_messages_sender_idx on public.room_messages (sender_id);

alter table public.room_messages enable row level security;

drop policy if exists "Active room members can read messages" on public.room_messages;
create policy "Active room members can read messages"
on public.room_messages for select
to authenticated
using (
  exists (
    select 1 from public.room_members rm
    where rm.room_id = room_messages.room_id
      and rm.user_id = auth.uid()
      and rm.left_at is null
  )
);

drop policy if exists "Active room members can send messages" on public.room_messages;
create policy "Active room members can send messages"
on public.room_messages for insert
to authenticated
with check (
  sender_id = auth.uid()
  and exists (
    select 1 from public.room_members rm
    where rm.room_id = room_messages.room_id
      and rm.user_id = auth.uid()
      and rm.left_at is null
  )
);

do $$
begin
  alter publication supabase_realtime add table public.room_messages;
exception
  when duplicate_object then null;
  when undefined_object then null;
end $$;
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
alter table public.profiles
add column if not exists is_admin boolean not null default false;

create or replace function public.current_user_is_admin()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select coalesce((select is_admin from public.profiles where id = auth.uid()), false);
$$;

create table if not exists public.feedback (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete set null,
  category text not null,
  message text not null,
  status text not null default 'open',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint feedback_category_check check (category in ('bug', 'feature', 'suggestion', 'complaint', 'other')),
  constraint feedback_status_check check (status in ('open', 'reviewing', 'closed')),
  constraint feedback_message_length check (char_length(btrim(message)) between 5 and 1200)
);

create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  target_type text not null,
  target_id uuid,
  reason text not null,
  description text,
  status text not null default 'open',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint reports_target_type_check check (target_type in ('user', 'room', 'message')),
  constraint reports_reason_check check (reason in ('spam', 'harassment', 'unsafe', 'impersonation', 'other')),
  constraint reports_status_check check (status in ('open', 'reviewing', 'resolved', 'dismissed')),
  constraint reports_description_length check (description is null or char_length(description) <= 1200)
);

create index if not exists feedback_created_idx on public.feedback (created_at desc);
create index if not exists reports_created_idx on public.reports (created_at desc);
create index if not exists reports_target_idx on public.reports (target_type, target_id);

drop trigger if exists feedback_set_updated_at on public.feedback;
create trigger feedback_set_updated_at
before update on public.feedback
for each row execute function public.set_updated_at();

drop trigger if exists reports_set_updated_at on public.reports;
create trigger reports_set_updated_at
before update on public.reports
for each row execute function public.set_updated_at();

alter table public.feedback enable row level security;
alter table public.reports enable row level security;

drop policy if exists "Users submit own feedback" on public.feedback;
create policy "Users submit own feedback"
on public.feedback for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists "Users and admins read feedback" on public.feedback;
create policy "Users and admins read feedback"
on public.feedback for select
to authenticated
using (user_id = auth.uid() or public.current_user_is_admin());

drop policy if exists "Admins update feedback" on public.feedback;
create policy "Admins update feedback"
on public.feedback for update
to authenticated
using (public.current_user_is_admin())
with check (public.current_user_is_admin());

drop policy if exists "Users submit own reports" on public.reports;
create policy "Users submit own reports"
on public.reports for insert
to authenticated
with check (reporter_id = auth.uid());

drop policy if exists "Users and admins read reports" on public.reports;
create policy "Users and admins read reports"
on public.reports for select
to authenticated
using (reporter_id = auth.uid() or public.current_user_is_admin());

drop policy if exists "Admins update reports" on public.reports;
create policy "Admins update reports"
on public.reports for update
to authenticated
using (public.current_user_is_admin())
with check (public.current_user_is_admin());

drop policy if exists "Admins can read all rooms" on public.rooms;
create policy "Admins can read all rooms"
on public.rooms for select
to authenticated
using (public.current_user_is_admin());

do $$
begin
  alter publication supabase_realtime add table public.feedback;
exception
  when duplicate_object then null;
  when undefined_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.reports;
exception
  when duplicate_object then null;
  when undefined_object then null;
end $$;
alter table public.profiles
add column if not exists onboarding_step integer not null default 1,
add column if not exists user_status text,
add column if not exists occupation_category text,
add column if not exists occupation_custom text,
add column if not exists institution_source text;

alter table public.profiles
drop constraint if exists profiles_onboarding_step_check;
alter table public.profiles
add constraint profiles_onboarding_step_check check (onboarding_step between 1 and 4);

alter table public.profiles
drop constraint if exists profiles_user_status_check;
alter table public.profiles
add constraint profiles_user_status_check check (user_status is null or user_status in ('student', 'non_student'));

alter table public.profiles
drop constraint if exists profiles_institution_source_check;
alter table public.profiles
add constraint profiles_institution_source_check check (institution_source is null or institution_source in ('directory', 'manual'));

alter table public.profiles
drop constraint if exists profiles_occupation_category_check;
alter table public.profiles
add constraint profiles_occupation_category_check check (
  occupation_category is null
  or occupation_category in ('lecturer', 'business', 'professional', 'graduate', 'job_seeker', 'creator', 'other')
);

update public.profiles
set onboarding_step = 4
where onboarding_completed = true and onboarding_step < 4;
create or replace function public.ensure_profile(p_display_name text, p_username text)
returns public.profiles
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  cleaned_username text;
  base_username text;
  candidate_username text;
  profile_row public.profiles;
  attempt integer := 0;
begin
  if current_user_id is null then
    raise exception 'Not authenticated';
  end if;

  select *
  into profile_row
  from public.profiles
  where id = current_user_id;

  if found then
    return profile_row;
  end if;

  cleaned_username := lower(regexp_replace(coalesce(p_username, ''), '[^a-z0-9_]+', '_', 'g'));
  cleaned_username := regexp_replace(cleaned_username, '_+', '_', 'g');
  cleaned_username := trim(both '_' from cleaned_username);

  if length(cleaned_username) < 3 then
    cleaned_username := 'user_' || substring(current_user_id::text from 1 for 6);
  end if;

  base_username := substring(cleaned_username from 1 for 19);

  loop
    candidate_username := case
      when attempt = 0 then substring(base_username || '_' || substring(current_user_id::text from 1 for 4) from 1 for 24)
      else substring(base_username || '_' || substring(md5(current_user_id::text || attempt::text) from 1 for 4) from 1 for 24)
    end;

    begin
      insert into public.profiles (id, display_name, username, onboarding_completed, onboarding_step)
      values (
        current_user_id,
        coalesce(nullif(btrim(coalesce(p_display_name, '')), ''), 'BANT User'),
        candidate_username,
        false,
        1
      )
      returning *
      into profile_row;

      return profile_row;
    exception
      when unique_violation then
        attempt := attempt + 1;
        if attempt > 10 then
          raise exception 'Unable to generate a unique username';
        end if;
    end;
  end loop;
end;
$$;

grant execute on function public.ensure_profile(text, text) to authenticated;
