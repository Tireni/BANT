import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";

const root = join(__dirname, "..");

function read(path: string) {
  return readFileSync(join(root, path), "utf8");
}

describe("security contracts", () => {
  it("does not call the insecure username-to-email lookup from active app code", () => {
    const activeFiles = [
      "store/useBantStore.ts",
      "app/auth/sign-in.tsx",
      "lib/authHelpers.ts"
    ].map(read).join("\n");

    expect(activeFiles).not.toContain("login_username_lookup");
    expect(activeFiles).not.toContain("Username or email");
  });

  it("disables the old username lookup through a new additive migration", () => {
    const migration = read("supabase/migrations/016_disable_insecure_username_lookup.sql").toLowerCase();
    expect(migration).toContain("revoke all on function public.login_username_lookup(text) from anon");
    expect(migration).toContain("drop function if exists public.login_username_lookup(text)");
  });

  it("supersedes the old mesh capacity with a 100-person SFU migration", () => {
    const migration = read("supabase/migrations/019_100_person_sfu_rooms_and_feed.sql").toLowerCase();
    expect(migration).toContain("max_participants between 5 and 100");
    expect(migration).toContain("get_live_room_feed");
  });

  it("keeps LiveKit secrets server-side", () => {
    const tokenFunction = read("supabase/functions/livekit-token/index.ts");
    expect(tokenFunction).toContain("LIVEKIT_API_SECRET");
    expect(tokenFunction).not.toContain("EXPO_PUBLIC_LIVEKIT_API_SECRET");
  });

  it("keeps room membership inserts on the RPC path", () => {
    const migration = read("supabase/migrations/018_rpc_permission_and_membership_hardening.sql").toLowerCase();
    expect(migration).toContain("room membership inserts go through rpc only");
    expect(migration).toContain("with check (false)");
    expect(migration).toContain("grant execute on function public.join_room(uuid, text) to authenticated");
  });

  it("forces sensitive social and invite writes through RPCs", () => {
    const migration = read("supabase/migrations/023_authoritative_mutation_paths.sql").toLowerCase();
    expect(migration).toContain("friend request inserts go through rpc only");
    expect(migration).toContain("room invite inserts go through rpc only");
    expect(migration).toContain("block inserts go through rpc only");
    expect(migration).toContain("grant update (left_at)");
  });


  it("forces room creation through the authoritative RPC", () => {
    const migration = read("supabase/migrations/024_authoritative_room_creation.sql").toLowerCase();
    const store = read("store/useBantStore.ts");
    expect(migration).toContain("create or replace function public.create_room");
    expect(migration).toContain("revoke insert on table public.rooms from authenticated");
    expect(migration).toContain("room creation goes through rpc only");
    expect(store).toContain('supabase.rpc("create_room"');
    expect(store).not.toContain('.from("rooms")\n        .insert');
  });

  it("disambiguates room member profile relationships", () => {
    const store = read("store/useBantStore.ts");
    const tokenFunction = read("supabase/functions/livekit-token/index.ts");
    expect(store).toContain("profiles!room_members_user_id_fkey");
    expect(tokenFunction).toContain("profiles!room_members_user_id_fkey");
  });


  it("exposes only safe public invite preview metadata", () => {
    const migration = read("supabase/migrations/025_public_invite_preview.sql").toLowerCase();
    expect(migration).toContain("get_room_invite_preview");
    expect(migration).toContain("grant execute on function public.get_room_invite_preview(text) to anon");
    expect(migration).not.toContain("invitee_user_id");
  });

  it("scopes avatar writes to the authenticated user's folder", () => {
    const migration = read("supabase/migrations/021_avatar_storage_security.sql").toLowerCase();
    expect(migration).toContain("(storage.foldername(name))[1] = auth.uid()::text");
    expect(migration).toContain("image/webp");
  });
});

