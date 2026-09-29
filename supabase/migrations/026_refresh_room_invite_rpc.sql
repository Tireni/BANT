-- 026_refresh_room_invite_rpc.sql
-- Recreate the room invite RPC with the exact launch signature and force PostgREST
-- to reload its schema cache so the frontend can resolve /rpc/create_room_invite.

create or replace function public.create_room_invite(
  p_room_id uuid,
  p_invitee_user_id uuid default null,
  p_expires_at timestamptz default null
)
returns public.room_invites
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  room_row public.rooms;
  inviter_name text;
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

  if p_invitee_user_id is not null and p_invitee_user_id = current_user_id then
    raise exception 'You cannot invite yourself';
  end if;

  if p_invitee_user_id is not null
     and public.users_blocked_between(current_user_id, p_invitee_user_id) then
    raise exception 'Invite unavailable';
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
        p_invitee_user_id,
        p_expires_at
      )
      returning *
      into invite_row;

      exit;
    exception
      when unique_violation then
        null;
    end;
  end loop;

  if p_invitee_user_id is not null then
    select display_name
    into inviter_name
    from public.profiles
    where id = current_user_id;

    insert into public.notifications (
      user_id,
      actor_id,
      type,
      body,
      target_id,
      target_type
    )
    values (
      p_invitee_user_id,
      current_user_id,
      'room_invite',
      coalesce(inviter_name, 'Someone') || ' invited you to ' || room_row.title || '.',
      invite_row.id,
      'room_invite'
    );
  end if;

  return invite_row;
end;
$$;

revoke all on function public.create_room_invite(uuid, uuid, timestamptz) from public;
grant execute on function public.create_room_invite(uuid, uuid, timestamptz) to authenticated;

notify pgrst, 'reload schema';
