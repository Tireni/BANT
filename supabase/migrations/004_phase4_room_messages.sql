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
