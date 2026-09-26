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
