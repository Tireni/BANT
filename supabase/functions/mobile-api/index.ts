import { createClient } from "npm:@supabase/supabase-js@2";
import { GoogleAuth } from "npm:google-auth-library@9.15.1";

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

      case "bootstrap": {
        const metadata = user.user_metadata ?? {};
        const displayName =
          typeof metadata.full_name === "string" ? metadata.full_name :
          typeof metadata.name === "string" ? metadata.name :
          typeof user.email === "string" ? user.email.split("@")[0] :
          "BANT User";
        const requestedUsername =
          typeof metadata.user_name === "string" ? metadata.user_name :
          typeof metadata.preferred_username === "string" ? metadata.preferred_username :
          typeof user.email === "string" ? user.email.split("@")[0] :
          "bant_user";

        const { data: ensured, error: ensureError } = await userClient.rpc("ensure_profile", {
          p_display_name: displayName,
          p_username: requestedUsername
        });
        if (ensureError) return fail(ensureError);

        const { data: profile, error: profileError } = await userClient
          .from("profiles")
          .select("id,display_name,username,bio,avatar_url,onboarding_completed,onboarding_step")
          .eq("id", user.id)
          .single();
        if (profileError) return fail(profileError);

        return json({
          user: { id: user.id, email: user.email ?? null },
          profile: profile ?? ensured
        });
      }

      case "profile": {
        const { data, error } = await userClient
          .from("profiles")
          .select("id,display_name,username,bio,avatar_url,onboarding_completed,onboarding_step")
          .eq("id", user.id)
          .single();
        if (error) return fail(error);
        return json({ profile: data });
      }

      case "interests": {
        const { data, error } = await userClient
          .from("interests")
          .select("id,name,slug")
          .order("name");
        if (error) return fail(error);

        const { data: selected, error: selectedError } = await userClient
          .from("user_interests")
          .select("interest_id,interests(slug)")
          .eq("user_id", user.id);
        if (selectedError) return fail(selectedError);

        return json({
          interests: data ?? [],
          selected: (selected ?? []).map((row: any) =>
            Array.isArray(row.interests) ? row.interests[0]?.slug : row.interests?.slug
          ).filter(Boolean)
        });
      }

      case "onboarding_profile": {
        const displayName = requireString(body.display_name, "display_name").trim();
        const username = requireString(body.username, "username").trim().toLowerCase();
        const bio = typeof body.bio === "string" ? body.bio.trim().slice(0, 160) : "";
        const avatarUrl = typeof body.avatar_url === "string" && body.avatar_url.trim()
          ? body.avatar_url.trim()
          : null;

        if (!/^[a-z0-9_]{3,24}$/.test(username)) {
          return json({ error: "Username must be 3-24 characters using lowercase letters, numbers, or underscore." }, 400);
        }

        const { data, error } = await userClient
          .from("profiles")
          .update({
            display_name: displayName,
            username,
            bio: bio || null,
            avatar_url: avatarUrl,
            onboarding_step: 2
          })
          .eq("id", user.id)
          .select("id,display_name,username,bio,avatar_url,onboarding_completed,onboarding_step")
          .single();
        if (error) return fail(error);
        return json({ profile: data });
      }

      case "onboarding_interests": {
        const slugs = Array.isArray(body.interests)
          ? body.interests.filter((value: unknown) => typeof value === "string")
          : [];
        const uniqueSlugs = [...new Set(slugs)];
        if (uniqueSlugs.length < 3) return json({ error: "Choose at least 3 interests" }, 400);

        const { data: interestRows, error: interestError } = await userClient
          .from("interests")
          .select("id,slug")
          .in("slug", uniqueSlugs);
        if (interestError) return fail(interestError);
        if ((interestRows ?? []).length < 3) return json({ error: "Choose valid BANT interests" }, 400);

        const { error: deleteError } = await userClient
          .from("user_interests")
          .delete()
          .eq("user_id", user.id);
        if (deleteError) return fail(deleteError);

        const { error: insertError } = await userClient
          .from("user_interests")
          .insert((interestRows ?? []).map((row: any) => ({
            user_id: user.id,
            interest_id: row.id
          })));
        if (insertError) return fail(insertError);

        const { data: profile, error: profileError } = await userClient
          .from("profiles")
          .update({ onboarding_step: 3 })
          .eq("id", user.id)
          .select("id,display_name,username,bio,avatar_url,onboarding_completed,onboarding_step")
          .single();
        if (profileError) return fail(profileError);

        return json({ profile, selected: uniqueSlugs });
      }

      case "finish_onboarding": {
        const { data, error } = await userClient
          .from("profiles")
          .update({ onboarding_completed: true, onboarding_step: 4 })
          .eq("id", user.id)
          .select("id,display_name,username,bio,avatar_url,onboarding_completed,onboarding_step")
          .single();
        if (error) return fail(error);
        return json({ profile: data });
      }

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
          .select("id,title,slug,description,category,privacy,status,owner_id,host_id,max_participants,noise_control_enabled,created_at,room_members(user_id,role,left_at,joined_at,is_muted,profiles!room_members_user_id_fkey(id,display_name,username,bio,avatar_url))")
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
        const privacy = typeof body.privacy === "string" ? body.privacy : "public";
        const maxParticipants = Number(body.max_participants ?? 20);
        const noise = Boolean(body.noise_control_enabled);

        const allowedCategories = new Set([
          "Feed", "Gaming", "Anime", "Art", "Philosophy", "Music", "Technology",
          "Movies", "Sports", "Books", "Fashion", "Culture", "Relationships",
          "Business", "Comedy", "Science", "Lifestyle", "Food", "Travel", "General"
        ]);

        if (title.length < 3 || title.length > 80) {
          return json({ error: "Room title must be between 3 and 80 characters" }, 400);
        }
        if (description.length > 280) {
          return json({ error: "Room description must be 280 characters or fewer" }, 400);
        }
        if (!allowedCategories.has(category)) {
          return json({ error: "Invalid room category" }, 400);
        }
        if (privacy !== "public" && privacy !== "private") {
          return json({ error: "Invalid room privacy" }, 400);
        }
        if (!Number.isInteger(maxParticipants) || maxParticipants < 5 || maxParticipants > 100) {
          return json({ error: "Room capacity must be between 5 and 100" }, 400);
        }

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

        const createdRoom = Array.isArray(data) ? data[0] ?? null : data;
        if (privacy === "public" && createdRoom?.id) {
          try {
            const [{ data: friendships }, { data: actor }] = await Promise.all([
              admin
                .from("friendships")
                .select("user_a,user_b")
                .or(`user_a.eq.${user.id},user_b.eq.${user.id}`),
              admin
                .from("profiles")
                .select("display_name,username")
                .eq("id", user.id)
                .maybeSingle()
            ]);

            const friendIds = [...new Set((friendships ?? []).map((row: any) =>
              row.user_a === user.id ? row.user_b : row.user_a
            ).filter(Boolean))];

            if (friendIds.length) {
              const actorName = actor?.display_name ?? actor?.username ?? "Your friend";
              await sendPushToUsers(admin, friendIds, {
                title: "A friend started a BANT room",
                body: `${actorName} started “${title}”. Tap to join.`,
                data: {
                  type: "room_started",
                  room_id: String(createdRoom.id)
                }
              });
            }
          } catch (pushError) {
            console.error("Room push notification failed", pushError);
          }
        }

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

      case "end_room": {
        const roomId = requireString(body.room_id, "room_id");
        const { data, error } = await userClient.rpc("end_room", {
          p_room_id: roomId
        });
        if (error) return fail(error);
        return json({ room: data });
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
        const { data, error } = await userClient.rpc("create_share_room_invite", {
          p_room_id: roomId
        });
        if (error) return fail(error);
        return json({ invite: data });
      }

      case "invite_preview": {
        const token = requireString(body.invite_token, "invite_token");
        const { data, error } = await userClient.rpc("get_room_invite_preview", {
          p_invite_token: token
        });
        if (error) return fail(error);
        const preview = Array.isArray(data) ? data[0] ?? null : data ?? null;
        return json({ preview });
      }

      case "join_invite": {
        const token = requireString(body.invite_token, "invite_token");
        const role = body.role === "listener" ? "listener" : "speaker";
        const { data, error } = await userClient.rpc("join_private_room_with_invite", {
          p_invite_token: token,
          p_role: role
        });
        if (error) return fail(error);
        const membership = Array.isArray(data) ? data[0] ?? null : data ?? null;
        if (!membership?.room_id) return json({ error: "Unable to join invited room" }, 400);
        return json({ membership });
      }

      case "people": {
        const [
          profilesResult,
          friendshipsResult,
          requestsResult,
          blocksResult
        ] = await Promise.all([
          userClient
            .from("profiles")
            .select("id,display_name,username,bio,avatar_url")
            .eq("onboarding_completed", true)
            .neq("id", user.id)
            .order("created_at", { ascending: false })
            .limit(50),
          userClient
            .from("friendships")
            .select("id,user_a,user_b")
            .or(`user_a.eq.${user.id},user_b.eq.${user.id}`),
          userClient
            .from("friend_requests")
            .select("id,sender_id,receiver_id,status")
            .eq("status", "pending")
            .or(`sender_id.eq.${user.id},receiver_id.eq.${user.id}`),
          userClient
            .from("user_blocks")
            .select("blocked_id,profiles!user_blocks_blocked_id_fkey(id,display_name,username,bio,avatar_url)")
            .eq("blocker_id", user.id)
        ]);

        if (profilesResult.error) return fail(profilesResult.error);
        if (friendshipsResult.error) return fail(friendshipsResult.error);
        if (requestsResult.error) return fail(requestsResult.error);
        if (blocksResult.error) return fail(blocksResult.error);

        const blockedIds = new Set(
          (blocksResult.data ?? []).map((row: any) => row.blocked_id)
        );
        const people = (profilesResult.data ?? []).filter(
          (row: any) => !blockedIds.has(row.id)
        );
        const blockedPeople = (blocksResult.data ?? [])
          .map((row: any) => Array.isArray(row.profiles) ? row.profiles[0] : row.profiles)
          .filter(Boolean);
        const friendIds = (friendshipsResult.data ?? []).map((row: any) =>
          row.user_a === user.id ? row.user_b : row.user_a
        );
        const requests = requestsResult.data ?? [];

        return json({
          people,
          friend_ids: friendIds.filter((id: string) => !blockedIds.has(id)),
          incoming_requests: requests.filter((row: any) => row.receiver_id === user.id),
          outgoing_requests: requests.filter((row: any) => row.sender_id === user.id),
          blocked_people: blockedPeople
        });
      }

      case "register_push_token": {
        const token = requireString(body.token, "token").trim();
        const platform = body.platform === "ios"
          ? "ios"
          : body.platform === "android"
            ? "android"
            : "other";

        const { error } = await admin
          .from("device_push_tokens")
          .upsert({
            user_id: user.id,
            token,
            platform,
            updated_at: new Date().toISOString()
          }, { onConflict: "token" });
        if (error) return fail(error);
        return json({ registered: true });
      }

      case "unregister_push_token": {
        const token = requireString(body.token, "token").trim();
        const { error } = await admin
          .from("device_push_tokens")
          .delete()
          .eq("user_id", user.id)
          .eq("token", token);
        if (error) return fail(error);
        return json({ unregistered: true });
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

      case "mark_notifications_read": {
        const { error } = await userClient
          .from("notifications")
          .update({ read_at: new Date().toISOString() })
          .eq("user_id", user.id)
          .is("read_at", null);
        if (error) return fail(error);
        return json({ updated: true });
      }

      case "submit_feedback": {
        const category = typeof body.category === "string" ? body.category : "suggestion";
        const message = requireString(body.message, "message").trim();
        const allowedCategories = new Set(["bug", "feature", "suggestion", "complaint", "other"]);
        if (!allowedCategories.has(category)) {
          return json({ error: "Invalid feedback category" }, 400);
        }
        if (message.length < 5 || message.length > 1200) {
          return json({ error: "Feedback must be between 5 and 1200 characters" }, 400);
        }
        const { error } = await userClient
          .from("feedback")
          .insert({
            user_id: user.id,
            category,
            message
          });
        if (error) return fail(error);
        return json({ submitted: true });
      }

      case "report_user": {
        const targetId = requireString(body.user_id, "user_id");
        const reason = typeof body.reason === "string" ? body.reason : "unsafe";
        const description = typeof body.description === "string"
          ? body.description.trim().slice(0, 1200)
          : "";
        const allowedReasons = new Set(["spam", "harassment", "unsafe", "impersonation", "other"]);
        if (!allowedReasons.has(reason)) {
          return json({ error: "Invalid report reason" }, 400);
        }
        if (targetId === user.id) {
          return json({ error: "You cannot report yourself" }, 400);
        }
        const { error } = await userClient
          .from("reports")
          .insert({
            reporter_id: user.id,
            target_type: "user",
            target_id: targetId,
            reason,
            description: description || null
          });
        if (error) return fail(error);
        return json({ submitted: true });
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

      case "send_friend_request": {
        const receiverId = requireString(body.user_id, "user_id");
        const { data, error } = await userClient.rpc("send_friend_request", {
          p_receiver_id: receiverId
        });
        if (error) return fail(error);

        try {
          const { data: actor } = await admin
            .from("profiles")
            .select("display_name,username")
            .eq("id", user.id)
            .maybeSingle();
          const actorName = actor?.display_name ?? actor?.username ?? "Someone";
          await sendPushToUsers(admin, [receiverId], {
            title: "New BANT friend request",
            body: `${actorName} sent you a friend request.`,
            data: {
              type: "friend_request",
              actor_id: user.id
            }
          });
        } catch (pushError) {
          console.error("Friend request push notification failed", pushError);
        }

        return json({ result: data ?? true });
      }

      case "accept_friend_request": {
        const requestId = requireString(body.request_id, "request_id");
        const { data: request } = await admin
          .from("friend_requests")
          .select("sender_id,receiver_id")
          .eq("id", requestId)
          .maybeSingle();

        const { data, error } = await userClient.rpc("accept_friend_request", {
          p_request_id: requestId
        });
        if (error) return fail(error);

        if (request?.sender_id && request.receiver_id === user.id) {
          try {
            const { data: actor } = await admin
              .from("profiles")
              .select("display_name,username")
              .eq("id", user.id)
              .maybeSingle();
            const actorName = actor?.display_name ?? actor?.username ?? "Your friend";
            await sendPushToUsers(admin, [request.sender_id], {
              title: "Friend request accepted",
              body: `${actorName} accepted your friend request.`,
              data: {
                type: "friend_request_accepted",
                actor_id: user.id
              }
            });
          } catch (pushError) {
            console.error("Friend acceptance push notification failed", pushError);
          }
        }

        return json({ result: data ?? true });
      }
      case "decline_friend_request":
        return rpcBoolean(userClient, "decline_friend_request", {
          p_request_id: requireString(body.request_id, "request_id")
        });
      case "cancel_friend_request":
        return rpcBoolean(userClient, "cancel_friend_request", {
          p_request_id: requireString(body.request_id, "request_id")
        });
      case "block_user":
        return rpcBoolean(userClient, "block_user", { p_blocked_id: requireString(body.user_id, "user_id") });
      case "unblock_user":
        return rpcBoolean(userClient, "unblock_user", { p_blocked_id: requireString(body.user_id, "user_id") });

      case "update_profile": {
        const displayName = requireString(body.display_name, "display_name").trim();
        const username = requireString(body.username, "username").trim().toLowerCase();
        const bio = typeof body.bio === "string" ? body.bio.trim().slice(0, 160) : "";
        const avatarUrl = typeof body.avatar_url === "string" && body.avatar_url.trim()
          ? body.avatar_url.trim()
          : null;

        if (displayName.length < 2 || displayName.length > 60) {
          return json({ error: "Display name must be between 2 and 60 characters" }, 400);
        }
        if (!/^[a-z0-9_]{3,24}$/.test(username)) {
          return json({ error: "Username must be 3-24 characters using lowercase letters, numbers, or underscore." }, 400);
        }

        const { data, error } = await userClient
          .from("profiles")
          .update({
            display_name: displayName,
            username,
            bio: bio || null,
            avatar_url: avatarUrl
          })
          .eq("id", user.id)
          .select("id,display_name,username,bio,avatar_url,onboarding_completed,onboarding_step")
          .single();
        if (error) return fail(error);
        return json({ profile: data });
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

      case "moderate_room_all": {
        const { data, error } = await userClient.rpc("moderate_room_all_members", {
          p_room_id: requireString(body.room_id, "room_id"),
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


type PushPayload = {
  title: string;
  body: string;
  data: Record<string, string>;
};

async function sendPushToUsers(
  admin: any,
  userIds: string[],
  payload: PushPayload
) {
  const projectId = Deno.env.get("FIREBASE_PROJECT_ID");
  const clientEmail = Deno.env.get("FIREBASE_CLIENT_EMAIL");
  const rawPrivateKey = Deno.env.get("FIREBASE_PRIVATE_KEY");

  if (!projectId || !clientEmail || !rawPrivateKey || !userIds.length) {
    return;
  }

  const { data: tokenRows, error: tokenError } = await admin
    .from("device_push_tokens")
    .select("token")
    .in("user_id", userIds);

  if (tokenError) throw tokenError;

  const tokens = [...new Set((tokenRows ?? [])
    .map((row: any) => row.token)
    .filter((token: unknown) => typeof token === "string" && token.length > 0))];

  if (!tokens.length) return;

  const auth = new GoogleAuth({
    credentials: {
      client_email: clientEmail,
      private_key: rawPrivateKey.replace(/\\n/g, "\n")
    },
    scopes: ["https://www.googleapis.com/auth/firebase.messaging"]
  });

  const authClient = await auth.getClient();
  const accessTokenResult = await authClient.getAccessToken();
  const accessToken = typeof accessTokenResult === "string"
    ? accessTokenResult
    : accessTokenResult?.token;

  if (!accessToken) {
    throw new Error("Unable to authorize Firebase Cloud Messaging");
  }

  await Promise.allSettled(tokens.map(async (token) => {
    const response = await fetch(
      `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json"
        },
        body: JSON.stringify({
          message: {
            token,
            notification: {
              title: payload.title,
              body: payload.body
            },
            data: payload.data,
            android: {
              priority: "high",
              notification: {
                channel_id: "bant_social",
                sound: "default"
              }
            },
            apns: {
              payload: {
                aps: {
                  sound: "default",
                  badge: 1
                }
              }
            }
          }
        })
      }
    );

    if (!response.ok) {
      const responseBody = await response.text();
      console.error("FCM send failed", response.status, responseBody);

      if (response.status === 404 || responseBody.includes("UNREGISTERED")) {
        await admin
          .from("device_push_tokens")
          .delete()
          .eq("token", token);
      }
    }
  }));
}

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
