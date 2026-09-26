-- Fix recursive room_members RLS by allowing direct membership access only through
-- the owning room or by the member's own row, without recursively re-querying room_members.

create or replace function public.user_is_room_member(p_room_id uuid, p_user_id uuid)
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.room_members rm
    where rm.room_id = p_room_id
      and rm.user_id = p_user_id
      and rm.left_at is null
  );
$$;

grant execute on function public.user_is_room_member(uuid, uuid) to authenticated;

drop policy if exists "Authenticated users can read visible rooms" on public.rooms;
create policy "Authenticated users can read visible rooms"
on public.rooms for select
to authenticated
using (
  privacy = 'public'
  or host_id = auth.uid()
  or public.user_is_room_member(id, auth.uid())
);

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
  and role in ('speaker', 'listener')
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

-- Let room owners manage membership moderation without recursive re-checks.
create or replace function public.room_owner_matches(p_room_id uuid, p_user_id uuid)
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.rooms r
    where r.id = p_room_id
      and r.host_id = p_user_id
  );
$$;

grant execute on function public.room_owner_matches(uuid, uuid) to authenticated;

-- Additional explicit update policy for owner moderation paths.
drop policy if exists "Room owners can manage memberships" on public.room_members;
create policy "Room owners can manage memberships"
on public.room_members for update
to authenticated
using (
  public.room_owner_matches(room_id, auth.uid())
)
with check (
  room_id = room_members.room_id
  and public.room_owner_matches(room_id, auth.uid())
);
