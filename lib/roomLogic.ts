import { RoomCategory } from "@/types/room";

export const roomCategories: RoomCategory[] = ["Feed", "Gaming", "Anime", "Art", "Philosophy", "Music", "Technology", "Movies", "Sports", "Books", "Fashion", "Culture", "Relationships", "Business", "Comedy", "Science", "Lifestyle", "Food", "Travel", "General"];

export const MAX_MESH_VOICE_PARTICIPANTS = 8;
export const MIN_ROOM_PARTICIPANTS = 2;

export function clampRoomCapacity(value: number) {
  return Math.min(Math.max(Number(value || MAX_MESH_VOICE_PARTICIPANTS), MIN_ROOM_PARTICIPANTS), MAX_MESH_VOICE_PARTICIPANTS);
}

export function isValidRoomCapacity(value: number) {
  return Number.isInteger(value) && value >= MIN_ROOM_PARTICIPANTS && value <= MAX_MESH_VOICE_PARTICIPANTS;
}

export function isValidRoomCategory(value: string): value is RoomCategory {
  return roomCategories.includes(value as RoomCategory);
}

export function isRoomFull(participantCount: number, maxParticipants = 20) {
  return participantCount >= maxParticipants;
}
