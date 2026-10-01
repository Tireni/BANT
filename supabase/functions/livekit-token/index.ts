import { AccessToken } from "npm:livekit-server-sdk@2";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS"
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authorization = req.headers.get("Authorization");
    if (!authorization) return json({ error: "Not authenticated" }, 401);

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const livekitUrl = Deno.env.get("LIVEKIT_URL");
    const livekitApiKey = Deno.env.get("LIVEKIT_API_KEY");
    const livekitApiSecret = Deno.env.get("LIVEKIT_API_SECRET");

    if (!supabaseUrl || !supabaseAnonKey || !livekitUrl || !livekitApiKey || !livekitApiSecret) {
      return json({ error: "LiveKit is not configured" }, 503);
    }

    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false, autoRefreshToken: false }
    });

    const { data: userResult, error: userError } = await supabase.auth.getUser();
    const user = userResult.user;
    if (userError || !user) return json({ error: "Not authenticated" }, 401);

    const body = await req.json().catch(() => ({}));
    const roomId = typeof body?.room_id === "string" ? body.room_id : "";
    if (!roomId) return json({ error: "Room is required" }, 400);

    const { data: room, error: roomError } = await supabase
      .from("rooms")
      .select("id, status")
      .eq("id", roomId)
      .maybeSingle();

    if (roomError || !room) return json({ error: "Room not found" }, 404);
    if (room.status !== "live") return json({ error: "This room has ended" }, 409);

    const { data: member, error: memberError } = await supabase
      .from("room_members")
      .select("role, is_muted, profiles!room_members_user_id_fkey(display_name, username, avatar_url)")
      .eq("room_id", roomId)
      .eq("user_id", user.id)
      .is("left_at", null)
      .maybeSingle();

    if (memberError || !member) return json({ error: "Active room membership required" }, 403);

    const profile = Array.isArray(member.profiles) ? member.profiles[0] : member.profiles;
    const token = new AccessToken(livekitApiKey, livekitApiSecret, {
      identity: user.id,
      name: profile?.display_name ?? profile?.username ?? "BANT user",
      metadata: JSON.stringify({
        username: profile?.username ?? null,
        avatar_url: profile?.avatar_url ?? null,
        role: member.role,
        admin_muted: Boolean(member.is_muted)
      }),
      ttl: "6h"
    });

    token.addGrant({
      room: roomId,
      roomJoin: true,
      canSubscribe: true,
      canPublish: member.role !== "listener",
      canPublishData: true
    });

    return json({
      token: await token.toJwt(),
      url: livekitUrl,
      roomName: roomId,
      participantIdentity: user.id
    });
  } catch (error) {
    console.error("livekit-token failed", error instanceof Error ? error.message : error);
    return json({ error: "Unable to create room audio token" }, 500);
  }
});

function json(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" }
  });
}
