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
