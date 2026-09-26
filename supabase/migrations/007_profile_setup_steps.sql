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
