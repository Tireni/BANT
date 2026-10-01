import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS"
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  try {
    const authorization = req.headers.get("Authorization");
    if (!authorization) return json({ error: "Not authenticated" }, 401);

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !anonKey || !serviceRoleKey) {
      return json({ error: "Mobile API is not configured" }, 503);
    }

    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false, autoRefreshToken: false }
    });
    const admin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false }
    });

    const { data: userResult, error: userError } = await userClient.auth.getUser();
    const user = userResult.user;
    if (userError || !user) return json({ error: "Not authenticated" }, 401);

    const body = await req.json().catch(() => ({}));
    const action = typeof body.action === "string" ? body.action : "";

    switch (action) {
      case "feed": {
        const { data, error } = await userClient.rpc("get_live_room_feed", {
          p_limit: 25,
          p_offset: 0,
          p_category: typeof body.category === "string" ? body.category : null,
          p_search: null
        });
        if (error) return fail(error);
        return json({ rooms: data ?? [] });
      }

      case "room": {
        const roomId = requireString(body.room_id, "room_id");
        const { data, error } = await userClient
          .from("rooms")
          .select("id,title,slug,description,category,privacy,status,owner_id,host_id,max_participants,noise_control_enabled,created_at,room_members(user_id,role,left_at,is_muted,profiles!room_members_user_id_fkey(id,display_name,username,bio,avatar_url))")
          .eq("id", roomId)
          .maybeSingle();
        if (error) return fail(error);
        if (!data) return json({ error: "Room not found" }, 404);
        return json({ room: data });
      }

      case "create_room": {
        const title = requireString(body.title, "title").trim();
        const description = typeof body.description === "string" ? body.description.trim() : "";
        const category = typeof body.category === "string" ? body.category : "General";
        const privacy = body.privacy === "private" ? "private" : "public";
        const maxParticipants = Math.max(5, Math.min(100, Number(body.max_participants ?? 20)));
        const noise = Boolean(body.noise_control_enabled);
        const slug = slugify(title) + "-" + Date.now().toString(36);

        const { data, error } = await userClient.rpc("create_room", {
          p_title: title,
          p_slug: slug,
          p_description: description || "A fresh BANT room.",
          p_category: category,
          p_privacy: privacy,
          p_max_participants: maxParticipants,
          p_noise_control_enabled: noise
        });
        if (error) return fail(error);
        return json({ room: data });
      }

      case "join_room": {
        const roomId = requireString(body.room_id, "room_id");
        const role = body.role === "listener" ? "listener" : "speaker";
        const { data, error } = await userClient.rpc("join_room", {
          p_room_id: roomId,
          p_role: role
        });
        if (error) return fail(error);
        return json({ membership: data });
      }

      case "leave_room": {
        const roomId = requireString(body.room_id, "room_id");
        const { data: room, error: roomError } = await userClient
          .from("rooms")
          .select("owner_id,host_id")
          .eq("id", roomId)
          .maybeSingle();
        if (roomError) return fail(roomError);
        if (!room) return json({ error: "Room not found" }, 404);

        if ((room.owner_id ?? room.host_id) === user.id) {
          const { error } = await userClient.rpc("end_room", { p_room_id: roomId });
          if (error) return fail(error);
          return json({ ended: true });
        }

        const { error } = await userClient
          .from("room_members")
          .update({ left_at: new Date().toISOString() })
          .eq("room_id", roomId)
          .eq("user_id", user.id);
        if (error) return fail(error);
        return json({ left: true });
      }

      case "create_invite": {
        const roomId = requireString(body.room_id, "room_id");
        const { data: room } = await admin
          .from("rooms")
          .select("id,status,owner_id,host_id")
          .eq("id", roomId)
          .maybeSingle();
        if (!room) return json({ error: "Room not found" }, 404);
        if (room.status !== "live") return json({ error: "This room has ended" }, 409);

        const { data: membership } = await admin
          .from("room_members")
          .select("user_id")
          .eq("room_id", roomId)
          .eq("user_id", user.id)
          .is("left_at", null)
          .maybeSingle();

        if (!membership && (room.owner_id ?? room.host_id) !== user.id) {
          return json({ error: "Join the room before inviting people" }, 403);
        }

        let invite: any = null;
        for (let attempt = 0; attempt < 3 && !invite; attempt += 1) {
          const token = randomToken(12);
          const result = await admin
            .from("room_invites")
            .insert({
              room_id: roomId,
              created_by: user.id,
              invite_token: token,
              invitee_user_id: null,
              expires_at: null
            })
            .select("id,room_id,invite_token,status,expires_at")
            .single();
          if (!result.error) invite = result.data;
          else if (result.error.code !== "23505") return fail(result.error);
        }
        if (!invite) return json({ error: "Unable to create invite" }, 500);
        return json({ invite });
      }

      case "people": {
        const { data, error } = await userClient
          .from("profiles")
          .select("id,display_name,username,bio,avatar_url")
          .eq("onboarding_completed", true)
          .neq("id", user.id)
          .order("created_at", { ascending: false })
          .limit(50);
        if (error) return fail(error);
        return json({ people: data ?? [] });
      }

      case "notifications": {
        const { data, error } = await userClient
          .from("notifications")
          .select("id,actor_id,type,body,read_at,created_at,target_id,target_type")
          .eq("user_id", user.id)
          .order("created_at", { ascending: false })
          .limit(50);
        if (error) return fail(error);
        return json({ notifications: data ?? [] });
      }

      case "messages": {
        const roomId = requireString(body.room_id, "room_id");
        const { data, error } = await userClient
          .from("room_messages")
          .select("id,room_id,sender_id,body,created_at,profiles!room_messages_sender_id_fkey(display_name,username)")
          .eq("room_id", roomId)
          .order("created_at", { ascending: true })
          .limit(100);
        if (error) return fail(error);
        const messages = (data ?? []).map((row: any) => {
          const profile = Array.isArray(row.profiles) ? row.profiles[0] : row.profiles;
          return {
            id: row.id,
            room_id: row.room_id,
            sender_id: row.sender_id,
            sender_name: profile?.display_name ?? profile?.username ?? "BANT user",
            body: row.body,
            created_at: row.created_at
          };
        });
        return json({ messages });
      }

      case "send_message": {
        const roomId = requireString(body.room_id, "room_id");
        const message = requireString(body.body, "body").trim().slice(0, 500);
        if (!message) return json({ error: "Message is required" }, 400);
        const { data, error } = await userClient
          .from("room_messages")
          .insert({ room_id: roomId, sender_id: user.id, body: message })
          .select("id,room_id,sender_id,body,created_at")
          .single();
        if (error) return fail(error);
        return json({ message: data });
      }

      case "send_friend_request":
        return rpcBoolean(userClient, "send_friend_request", { p_receiver_id: requireString(body.user_id, "user_id") });
      case "accept_friend_request":
        return rpcBoolean(userClient, "accept_friend_request", { p_sender_id: requireString(body.user_id, "user_id") });
      case "decline_friend_request":
        return rpcBoolean(userClient, "decline_friend_request", { p_sender_id: requireString(body.user_id, "user_id") });
      case "cancel_friend_request":
        return rpcBoolean(userClient, "cancel_friend_request", { p_receiver_id: requireString(body.user_id, "user_id") });
      case "block_user":
        return rpcBoolean(userClient, "block_user", { p_blocked_id: requireString(body.user_id, "user_id") });
      case "unblock_user":
        return rpcBoolean(userClient, "unblock_user", { p_blocked_id: requireString(body.user_id, "user_id") });

      case "update_profile": {
        const displayName = requireString(body.display_name, "display_name").trim();
        const username = requireString(body.username, "username").trim().toLowerCase();
        const bio = typeof body.bio === "string" ? body.bio.trim() : "";
        const { error } = await userClient
          .from("profiles")
          .update({ display_name: displayName, username, bio: bio || null })
          .eq("id", user.id);
        if (error) return fail(error);
        return json({ updated: true });
      }

      case "moderate_room": {
        const { data, error } = await userClient.rpc("moderate_room_members", {
          p_room_id: requireString(body.room_id, "room_id"),
          p_target_user_ids: Array.isArray(body.user_ids) ? body.user_ids : [],
          p_action: body.moderation_action === "unmute" ? "unmute" : "mute"
        });
        if (error) return fail(error);
        return json({ result: data });
      }

      case "send_warning": {
        const { data, error } = await userClient.rpc("send_room_warning", {
          p_room_id: requireString(body.room_id, "room_id"),
          p_target_user_ids: Array.isArray(body.user_ids) && body.user_ids.length ? body.user_ids : null
        });
        if (error) return fail(error);
        return json({ result: data });
      }

      default:
        return json({ error: "Unknown mobile API action" }, 400);
    }
  } catch (error) {
    console.error("mobile-api failed", error);
    return json({ error: error instanceof Error ? error.message : "Mobile API failed" }, 500);
  }
});

async function rpcBoolean(client: any, fn: string, args: Record<string, unknown>) {
  const { data, error } = await client.rpc(fn, args);
  if (error) return fail(error);
  return json({ result: data ?? true });
}

function requireString(value: unknown, name: string) {
  if (typeof value !== "string" || !value.trim()) throw new Error(name + " is required");
  return value;
}

function slugify(value: string) {
  return value.toLowerCase().trim().replace(/[^a-z0-9]+/g, "-").replace(/(^-|-$)/g, "") || "room";
}

function randomToken(byteLength: number) {
  const bytes = new Uint8Array(byteLength);
  crypto.getRandomValues(bytes);
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

function fail(error: any) {
  console.error("mobile-api database error", error);
  return json({ error: error?.message ?? "Mobile API request failed" }, 400);
}

function json(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" }
  });
}
