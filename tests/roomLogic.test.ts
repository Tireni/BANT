import { describe, expect, it } from "vitest";
import { MAX_MESH_VOICE_PARTICIPANTS, clampRoomCapacity, isRoomFull, isValidRoomCapacity, isValidRoomCategory } from "../lib/roomLogic";

describe("room logic", () => {
  it("validates room capacity", () => {
    expect(isValidRoomCapacity(2)).toBe(true);
    expect(isValidRoomCapacity(MAX_MESH_VOICE_PARTICIPANTS)).toBe(true);
    expect(isValidRoomCapacity(1)).toBe(false);
    expect(isValidRoomCapacity(MAX_MESH_VOICE_PARTICIPANTS + 1)).toBe(false);
  });

  it("clamps room capacity to launch limits", () => {
    expect(clampRoomCapacity(1)).toBe(2);
    expect(clampRoomCapacity(120)).toBe(MAX_MESH_VOICE_PARTICIPANTS);
    expect(clampRoomCapacity(6)).toBe(6);
  });

  it("validates known categories", () => {
    expect(isValidRoomCategory("Gaming")).toBe(true);
    expect(isValidRoomCategory("Unknown")).toBe(false);
  });

  it("detects full rooms", () => {
    expect(isRoomFull(20, 20)).toBe(true);
    expect(isRoomFull(19, 20)).toBe(false);
  });
});
