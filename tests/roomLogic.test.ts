import { describe, expect, it } from "vitest";
import { clampRoomCapacity, isRoomFull, isValidRoomCapacity, isValidRoomCategory } from "../lib/roomLogic";

describe("room logic", () => {
  it("validates room capacity", () => {
    expect(isValidRoomCapacity(5)).toBe(true);
    expect(isValidRoomCapacity(100)).toBe(true);
    expect(isValidRoomCapacity(4)).toBe(false);
    expect(isValidRoomCapacity(101)).toBe(false);
  });

  it("clamps room capacity to launch limits", () => {
    expect(clampRoomCapacity(2)).toBe(5);
    expect(clampRoomCapacity(120)).toBe(100);
    expect(clampRoomCapacity(20)).toBe(20);
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
