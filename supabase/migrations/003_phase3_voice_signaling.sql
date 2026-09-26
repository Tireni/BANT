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
