import { describe, expect, it } from "vitest";
import { buildIceServers, voicePeerIdsFor } from "../lib/voiceConfig";

describe("voice config", () => {
  it("uses STUN by default", () => {
    expect(buildIceServers({})).toEqual([{ urls: "stun:stun.l.google.com:19302" }]);
  });

  it("adds TURN only when configured", () => {
    expect(buildIceServers({
      EXPO_PUBLIC_TURN_URL: "turn:turn.example.com:3478",
      EXPO_PUBLIC_TURN_USERNAME: "bant",
      EXPO_PUBLIC_TURN_CREDENTIAL: "secret"
    })).toEqual([
      { urls: "stun:stun.l.google.com:19302" },
      { urls: "turn:turn.example.com:3478", username: "bant", credential: "secret" }
    ]);
  });

  it("limits mesh peers and excludes the current user", () => {
    const ids = ["u1", "u2", "u3", "u4", "u5", "u6", "u7", "u8", "u9"];
    expect(voicePeerIdsFor("u1", ids)).toEqual(["u2", "u3", "u4", "u5", "u6", "u7", "u8"]);
  });
});

