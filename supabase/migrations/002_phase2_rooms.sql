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
