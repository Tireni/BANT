import { createClient } from "@supabase/supabase-js";
import { describe, expect, it } from "vitest";

const url = process.env.TEST_SUPABASE_URL;
const anonKey = process.env.TEST_SUPABASE_ANON_KEY;
const aEmail = process.env.TEST_USER_A_EMAIL;
const aPassword = process.env.TEST_USER_A_PASSWORD;
const bEmail = process.env.TEST_USER_B_EMAIL;
const bPassword = process.env.TEST_USER_B_PASSWORD;

const configured = Boolean(url && anonKey && aEmail && aPassword && bEmail && bPassword);

describe.skipIf(!configured)("Supabase two-user room integration", () => {
  it("creates, joins, moderates, warns and ends a room", async () => {
    const clientA = createClient(url!, anonKey!, { auth: { persistSession: false } });
    const clientB = createClient(url!, anonKey!, { auth: { persistSession: false } });

    const aLogin = await clientA.auth.signInWithPassword({ email: aEmail!, password: aPassword! });
    const bLogin = await clientB.auth.signInWithPassword({ email: bEmail!, password: bPassword! });
    expect(aLogin.error).toBeNull();
    expect(bLogin.error).toBeNull();
    expect(aLogin.data.user?.id).toBeTruthy();
    expect(bLogin.data.user?.id).toBeTruthy();

    const slug = `integration-${Date.now().toString(36)}`;
    const created = await clientA
      .from("rooms")
      .insert({
        title: "Integration Room",
        slug,
        description: "Automated staging test",
        category: "General",
        privacy: "public",
        host_id: aLogin.data.user!.id,
        owner_id: aLogin.data.user!.id,
        status: "live",
        max_participants: 5,
        noise_control_enabled: true
      })
      .select("id")
      .single();

    expect(created.error).toBeNull();
    const roomId = created.data!.id;

    try {
      const joined = await clientB.rpc("join_room", { p_room_id: roomId, p_role: "speaker" });
      expect(joined.error).toBeNull();

      const duplicateJoin = await clientB.rpc("join_room", { p_room_id: roomId, p_role: "speaker" });
      expect(duplicateJoin.error).toBeNull();

      const members = await clientA
        .from("room_members")
        .select("user_id, is_muted")
        .eq("room_id", roomId)
        .is("left_at", null);
      expect(members.error).toBeNull();
      expect(members.data?.length).toBe(2);

      const muted = await clientA.rpc("moderate_room_members", {
        p_room_id: roomId,
        p_target_user_ids: [bLogin.data.user!.id],
        p_action: "mute"
      });
      expect(muted.error).toBeNull();

      const bMembership = await clientB
        .from("room_members")
        .select("is_muted")
        .eq("room_id", roomId)
        .eq("user_id", bLogin.data.user!.id)
        .single();
      expect(bMembership.error).toBeNull();
      expect(bMembership.data?.is_muted).toBe(true);

      const released = await clientA.rpc("moderate_room_members", {
        p_room_id: roomId,
        p_target_user_ids: [bLogin.data.user!.id],
        p_action: "unmute"
      });
      expect(released.error).toBeNull();

      const warned = await clientA.rpc("send_room_warning", {
        p_room_id: roomId,
        p_target_user_ids: [bLogin.data.user!.id]
      });
      expect(warned.error).toBeNull();

      const ended = await clientA.rpc("end_room", { p_room_id: roomId });
      expect(ended.error).toBeNull();

      const rejected = await clientB.rpc("join_room", { p_room_id: roomId, p_role: "speaker" });
      expect(rejected.error).not.toBeNull();
    } finally {
      await clientA.auth.signOut();
      await clientB.auth.signOut();
    }
  }, 30000);
});
