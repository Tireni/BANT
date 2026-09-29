import { describe, expect, it } from "vitest";
import { friendshipStateFor } from "../lib/friendship";

describe("friendship state", () => {
  const state = {
    friendIds: ["friend"],
    incomingIds: ["incoming"],
    outgoingIds: ["outgoing"]
  };

  it("resolves friend state precedence", () => {
    expect(friendshipStateFor("friend", state)).toBe("friends");
    expect(friendshipStateFor("incoming", state)).toBe("pending_received");
    expect(friendshipStateFor("outgoing", state)).toBe("pending_sent");
    expect(friendshipStateFor("none", state)).toBe("none");
  });
});
