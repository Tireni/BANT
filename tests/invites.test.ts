import { describe, expect, it } from "vitest";
import { PENDING_INVITE_TOKEN_KEY } from "../lib/roomInvites";

describe("invite helpers", () => {
  it("uses a stable pending invite key", () => {
    expect(PENDING_INVITE_TOKEN_KEY).toBe("bant-pending-invite-token");
  });
});
