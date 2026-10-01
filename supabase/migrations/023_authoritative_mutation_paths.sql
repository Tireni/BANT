-- Force sensitive mutations through backend-authorized RPCs.
-- This prevents clients from bypassing block checks, invite token generation, role control,
-- moderation side effects, and notification creation.

-- room_members: clients may only mark their own membership as left.
revoke update on table public.room_members from authenticated;
grant update (left_at) on table public.room_members to authenticated;

-- Friend requests must go through send/accept/decline/cancel RPCs.
drop policy if exists "Users insert own friend requests" on public.friend_requests;
drop policy if exists "Users update relevant friend requests" on public.friend_requests;

create policy "Friend request inserts go through RPC only"
on public.friend_requests for insert
to authenticated
with check (false);

create policy "Friend request updates go through RPC only"
on public.friend_requests for update
to authenticated
using (false)
with check (false);

-- Room invites must go through create/revoke/join RPCs so tokens and block rules cannot be bypassed.
drop policy if exists "Owners create room invites" on public.room_invites;
drop policy if exists "Owners update room invites" on public.room_invites;

create policy "Room invite inserts go through RPC only"
on public.room_invites for insert
to authenticated
with check (false);

create policy "Room invite updates go through RPC only"
on public.room_invites for update
to authenticated
using (false)
with check (false);

-- Blocks must go through block_user/unblock_user so friendship and invitation cleanup is atomic.
drop policy if exists "Users create own blocks" on public.user_blocks;
drop policy if exists "Users delete own blocks" on public.user_blocks;

create policy "Block inserts go through RPC only"
on public.user_blocks for insert
to authenticated
with check (false);

create policy "Block deletes go through RPC only"
on public.user_blocks for delete
to authenticated
using (false);

revoke all on function public.block_user(uuid) from public;
grant execute on function public.block_user(uuid) to authenticated;
revoke all on function public.unblock_user(uuid) from public;
grant execute on function public.unblock_user(uuid) to authenticated;
