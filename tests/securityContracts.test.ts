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

  it("enforces the launch voice capacity through a new migration", () => {
    const migration = read("supabase/migrations/017_limited_mesh_voice_capacity.sql").toLowerCase();
    expect(migration).toContain("max_participants between 2 and 8");
    expect(migration).toContain("set max_participants = 8");
  });

  it("keeps room membership inserts on the RPC path", () => {
    const migration = read("supabase/migrations/018_rpc_permission_and_membership_hardening.sql").toLowerCase();
    expect(migration).toContain("room membership inserts go through rpc only");
    expect(migration).toContain("with check (false)");
    expect(migration).toContain("grant execute on function public.join_room(uuid, text) to authenticated");
  });
});

