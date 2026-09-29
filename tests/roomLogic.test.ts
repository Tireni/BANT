import { describe, expect, it } from "vitest";
import {
  MAX_ROOM_PARTICIPANTS,
  MIN_ROOM_PARTICIPANTS,
  DEFAULT_ROOM_PARTICIPANTS,
  ROOM_CAPACITY_OPTIONS,
  clampRoomCapacity,
  isRoomFull,
  isValidRoomCapacity,
  isValidRoomCategory
} from "../lib/roomLogic";

describe("room logic", () => {
  it("validates 100-person SFU room capacity", () => {
    expect(isValidRoomCapacity(MIN_ROOM_PARTICIPANTS)).toBe(true);
    expect(isValidRoomCapacity(20)).toBe(true);
    expect(isValidRoomCapacity(50)).toBe(true);
    expect(isValidRoomCapacity(100)).toBe(true);
    expect(isValidRoomCapacity(4)).toBe(false);
    expect(isValidRoomCapacity(101)).toBe(false);
  });

  it("clamps room capacity to production limits", () => {
    expect(clampRoomCapacity(1)).toBe(MIN_ROOM_PARTICIPANTS);
    expect(clampRoomCapacity(120)).toBe(MAX_ROOM_PARTICIPANTS);
    expect(clampRoomCapacity(0)).toBe(DEFAULT_ROOM_PARTICIPANTS);
  });

  it("offers the intended launch room sizes", () => {
    expect(ROOM_CAPACITY_OPTIONS).toEqual([5, 10, 15, 20, 30, 50, 75, 100]);
  });

  it("validates known categories", () => {
    expect(isValidRoomCategory("Gaming")).toBe(true);
    expect(isValidRoomCategory("Unknown")).toBe(false);
  });

  it("detects full rooms", () => {
    expect(isRoomFull(100, 100)).toBe(true);
    expect(isRoomFull(99, 100)).toBe(false);
  });
});
