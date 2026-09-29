import { RoomCategory } from "@/types/room";

export const roomCategories: RoomCategory[] = ["Feed", "Gaming", "Anime", "Art", "Philosophy", "Music", "Technology", "Movies", "Sports", "Books", "Fashion", "Culture", "Relationships", "Business", "Comedy", "Science", "Lifestyle", "Food", "Travel", "General"];

export const MAX_ROOM_PARTICIPANTS = 100;
export const MIN_ROOM_PARTICIPANTS = 5;
export const DEFAULT_ROOM_PARTICIPANTS = 20;
export const ROOM_CAPACITY_OPTIONS = [5, 10, 15, 20, 30, 50, 75, 100] as const;

export function clampRoomCapacity(value: number) {
  return Math.min(Math.max(Number(value || DEFAULT_ROOM_PARTICIPANTS), MIN_ROOM_PARTICIPANTS), MAX_ROOM_PARTICIPANTS);
}

export function isValidRoomCapacity(value: number) {
  return Number.isInteger(value) && value >= MIN_ROOM_PARTICIPANTS && value <= MAX_ROOM_PARTICIPANTS;
}

export function isValidRoomCategory(value: string): value is RoomCategory {
  return roomCategories.includes(value as RoomCategory);
}

export function isRoomFull(participantCount: number, maxParticipants = 20) {
  return participantCount >= maxParticipants;
}
