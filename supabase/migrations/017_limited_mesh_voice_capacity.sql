-- 017_limited_mesh_voice_capacity.sql
-- The launch build uses browser WebRTC mesh, so live voice rooms are capped at 8.

update public.rooms
set max_participants = 8
where max_participants > 8;

alter table public.rooms
  alter column max_participants set default 8;

alter table public.rooms
  drop constraint if exists rooms_max_participants_check;

alter table public.rooms
  add constraint rooms_max_participants_check
  check (max_participants between 2 and 8);

