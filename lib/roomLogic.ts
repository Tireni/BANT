import { RoomCategory } from "@/types/room";

export const roomCategories: RoomCategory[] = ["Feed", "Gaming", "Anime", "Art", "Philosophy", "Music", "Technology", "Movies", "Sports", "Books", "Fashion", "Culture", "Relationships", "Business", "Comedy", "Science", "Lifestyle", "Food", "Travel", "General"];

export function clampRoomCapacity(value: number) {
  return Math.min(Math.max(Number(value || 20), 5), 100);
}

export function isValidRoomCapacity(value: number) {
  return Number.isInteger(value) && value >= 5 && value <= 100;
}

export function isValidRoomCategory(value: string): value is RoomCategory {
  return roomCategories.includes(value as RoomCategory);
}

export function isRoomFull(participantCount: number, maxParticipants = 20) {
  return participantCount >= maxParticipants;
}
