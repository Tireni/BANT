-- 027_share_room_invite_rpc.sql
-- Dedicated one-argument RPC for generating a shareable room invite link.
-- Keeps the public-share path simple and avoids PostgREST signature/cache ambiguity.

create or replace function public.create_share_room_invite(p_room_id uuid)
returns public.room_invites
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  room_row public.rooms;
  invite_row public.room_invites;
  new_token text;
begin
  if current_user_id is null then
    raise exception 'Not authenticated';
  end if;

  select *
  into room_row
  from public.rooms
  where id = p_room_id
  for update;

  if room_row.id is null then
    raise exception 'Room not found';
  end if;

  if coalesce(room_row.owner_id, room_row.host_id) <> current_user_id then
    raise exception 'Only the room owner can create invites';
  end if;

  if room_row.status <> 'live' then
    raise exception 'This room has ended';
  end if;

  loop
    new_token := public.generate_invite_token();
    begin
      insert into public.room_invites (
        room_id,
        created_by,
        invite_token,
        invitee_user_id,
        expires_at
      )
      values (
        p_room_id,
        current_user_id,
        new_token,
        null,
        null
      )
      returning *
      into invite_row;
      exit;
    exception
      when unique_violation then
        null;
    end;
  end loop;

  return invite_row;
end;
$$;

revoke all on function public.create_share_room_invite(uuid) from public;
grant execute on function public.create_share_room_invite(uuid) to authenticated;

notify pgrst, 'reload schema';
