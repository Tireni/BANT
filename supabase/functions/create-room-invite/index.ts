import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS"
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const authorization = req.headers.get("Authorization");
    if (!authorization) return json({ error: "Not authenticated" }, 401);

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !supabaseAnonKey || !serviceRoleKey) {
      return json({ error: "Supabase function environment is not configured" }, 503);
    }

    const authClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false, autoRefreshToken: false }
    });

    const { data: userResult, error: userError } = await authClient.auth.getUser();
    const user = userResult.user;
    if (userError || !user) return json({ error: "Not authenticated" }, 401);

    const body = await req.json().catch(() => ({}));
    const roomId = typeof body?.room_id === "string" ? body.room_id : "";
    const inviteeUserId = typeof body?.invitee_user_id === "string" ? body.invitee_user_id : null;

    if (!roomId) return json({ error: "Room is required" }, 400);
    if (inviteeUserId === user.id) return json({ error: "You cannot invite yourself" }, 400);

    const admin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false }
    });

    const { data: room, error: roomError } = await admin
      .from("rooms")
      .select("id, title, owner_id, host_id, status")
      .eq("id", roomId)
      .maybeSingle();

    if (roomError || !room) return json({ error: "Room not found" }, 404);
    if ((room.owner_id ?? room.host_id) !== user.id) {
      return json({ error: "Only the room owner can create invites" }, 403);
    }
    if (room.status !== "live") return json({ error: "This room has ended" }, 409);

    if (inviteeUserId) {
      const { data: invitee } = await admin.from("profiles").select("id").eq("id", inviteeUserId).maybeSingle();
      if (!invitee) return json({ error: "User not found" }, 404);

      const { data: blocks, error: blockError } = await admin
        .from("user_blocks")
        .select("blocker_id, blocked_id")
        .or(
          `and(blocker_id.eq.${user.id},blocked_id.eq.${inviteeUserId}),and(blocker_id.eq.${inviteeUserId},blocked_id.eq.${user.id})`
        )
        .limit(1);

      if (blockError) return json({ error: "Unable to validate invite" }, 500);
      if (blocks?.length) return json({ error: "Invite unavailable" }, 403);
    }

    let invite: any = null;
    let insertError: any = null;

    for (let attempt = 0; attempt < 3; attempt += 1) {
      const inviteToken = randomToken(12);
      const result = await admin
        .from("room_invites")
        .insert({
          room_id: roomId,
          created_by: user.id,
          invite_token: inviteToken,
          invitee_user_id: inviteeUserId,
          expires_at: null
        })
        .select("id, room_id, invite_token, invitee_user_id, status, expires_at")
        .single();

      if (!result.error && result.data) {
        invite = result.data;
        insertError = null;
        break;
      }

      insertError = result.error;
      if (result.error?.code !== "23505") break;
    }

    if (!invite) {
      console.error("create-room-invite insert failed", insertError);
      return json({ error: "Unable to create invite" }, 500);
    }

    if (inviteeUserId) {
      const { data: inviter } = await admin.from("profiles").select("display_name").eq("id", user.id).maybeSingle();
      await admin.from("notifications").insert({
        user_id: inviteeUserId,
        actor_id: user.id,
        type: "room_invite",
        body: `${inviter?.display_name ?? "Someone"} invited you to ${room.title}.`,
        target_id: invite.id,
        target_type: "room_invite"
      });
    }

    return json(invite);
  } catch (error) {
    console.error("create-room-invite failed", error instanceof Error ? error.message : error);
    return json({ error: "Unable to create invite" }, 500);
  }
});

function randomToken(byteLength: number) {
  const bytes = new Uint8Array(byteLength);
  crypto.getRandomValues(bytes);
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

function json(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" }
  });
}
