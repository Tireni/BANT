-- 025_public_invite_preview.sql
-- Safe public invite preview used before authentication.
-- Exposes only room-facing metadata; never exposes invitee identity or token internals.

create or replace function public.get_room_invite_preview(p_invite_token text)
returns table (
  room_id uuid,
  room_title text,
  room_description text,
  room_category text,
  room_privacy text,
  room_status text,
  invite_status text
)
language plpgsql
security definer
set search_path = public
stable
as $$
begin
  return query
  select
    r.id,
    r.title,
    r.description,
    r.category,
    r.privacy,
    r.status,
    case
      when ri.status <> 'active' then ri.status
      when ri.expires_at is not null and ri.expires_at <= now() then 'expired'
      else ri.status
    end
  from public.room_invites ri
  join public.rooms r on r.id = ri.room_id
  where ri.invite_token = p_invite_token;
end;
$$;

revoke all on function public.get_room_invite_preview(text) from public;
grant execute on function public.get_room_invite_preview(text) to anon;
grant execute on function public.get_room_invite_preview(text) to authenticated;
