-- 029_mobile_room_realtime.sql
-- Make the Android room experience explicitly realtime for membership and chat.
-- Safe to run on projects where the tables are already published.

do $$
begin
  alter publication supabase_realtime add table public.room_members;
exception
  when duplicate_object then null;
  when undefined_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.room_messages;
exception
  when duplicate_object then null;
  when undefined_object then null;
end $$;

-- Preserve enough UPDATE information for clients to recognize room-member leaves
-- and role/mute changes from realtime payloads.
alter table public.room_members replica identity full;
