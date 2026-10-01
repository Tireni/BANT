-- Make required realtime tables explicit and narrow execution of SECURITY DEFINER helpers.

do $$
begin
  alter publication supabase_realtime add table public.rooms;
exception when duplicate_object then null; when undefined_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.room_warnings;
exception when duplicate_object then null; when undefined_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.notifications;
exception when duplicate_object then null; when undefined_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.friend_requests;
exception when duplicate_object then null; when undefined_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.friendships;
exception when duplicate_object then null; when undefined_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.room_invites;
exception when duplicate_object then null; when undefined_object then null;
end $$;

revoke all on function public.current_user_is_admin() from public;
grant execute on function public.current_user_is_admin() to authenticated;

revoke all on function public.room_owner_id(uuid) from public;
grant execute on function public.room_owner_id(uuid) to authenticated;

revoke all on function public.is_active_room_member(uuid, uuid) from public;
grant execute on function public.is_active_room_member(uuid, uuid) to authenticated;

revoke all on function public.can_read_room(uuid, uuid) from public;
grant execute on function public.can_read_room(uuid, uuid) to authenticated;

revoke all on function public.can_join_room(uuid, uuid) from public;
grant execute on function public.can_join_room(uuid, uuid) to authenticated;

revoke all on function public.are_friends(uuid, uuid) from public;
grant execute on function public.are_friends(uuid, uuid) to authenticated;
