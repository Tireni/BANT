-- 018_rpc_permission_and_membership_hardening.sql
-- Keep joins on the serialized RPC path and remove broad default function execution.

drop policy if exists "Users join visible rooms as themselves" on public.room_members;
drop policy if exists "Users join rooms as themselves" on public.room_members;

create policy "Room membership inserts go through RPC only"
on public.room_members for insert
to authenticated
with check (false);

revoke all on function public.ensure_profile(text, text) from public;
grant execute on function public.ensure_profile(text, text) to authenticated;

revoke all on function public.join_room(uuid, text) from public;
grant execute on function public.join_room(uuid, text) to authenticated;

revoke all on function public.send_friend_request(uuid) from public;
revoke all on function public.accept_friend_request(uuid) from public;
revoke all on function public.decline_friend_request(uuid) from public;
revoke all on function public.cancel_friend_request(uuid) from public;
grant execute on function public.send_friend_request(uuid) to authenticated;
grant execute on function public.accept_friend_request(uuid) to authenticated;
grant execute on function public.decline_friend_request(uuid) to authenticated;
grant execute on function public.cancel_friend_request(uuid) to authenticated;

revoke all on function public.create_room_invite(uuid, uuid, timestamptz) from public;
revoke all on function public.revoke_room_invite(uuid) from public;
revoke all on function public.resolve_room_invite(text) from public;
revoke all on function public.join_private_room_with_invite(text, text) from public;
revoke all on function public.join_private_room_with_invite_id(uuid, text) from public;
grant execute on function public.create_room_invite(uuid, uuid, timestamptz) to authenticated;
grant execute on function public.revoke_room_invite(uuid) to authenticated;
grant execute on function public.resolve_room_invite(text) to authenticated;
grant execute on function public.join_private_room_with_invite(text, text) to authenticated;
grant execute on function public.join_private_room_with_invite_id(uuid, text) to authenticated;

revoke all on function public.moderate_room_members(uuid, uuid[], text) from public;
revoke all on function public.moderate_room_all_members(uuid, text) from public;
revoke all on function public.send_room_warning(uuid, uuid[]) from public;
revoke all on function public.end_room(uuid) from public;
grant execute on function public.moderate_room_members(uuid, uuid[], text) to authenticated;
grant execute on function public.moderate_room_all_members(uuid, text) to authenticated;
grant execute on function public.send_room_warning(uuid, uuid[]) to authenticated;
grant execute on function public.end_room(uuid) to authenticated;

