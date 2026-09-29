import { describe, expect, it } from "vitest";
import { liveKitTokenErrorMessage } from "../lib/livekitConfig";

describe("LiveKit config", () => {
  it("maps configuration failures to a safe user message", () => {
    expect(liveKitTokenErrorMessage("LiveKit is not configured")).toBe("Room audio is not configured yet.");
  });

  it("maps ended rooms safely", () => {
    expect(liveKitTokenErrorMessage("This room has ended")).toBe("This room has ended.");
  });

  it("does not expose arbitrary server errors", () => {
    expect(liveKitTokenErrorMessage("LIVEKIT_API_SECRET=super-secret")).toBe("Unable to connect to room audio.");
  });
});
