export type RoomCategory = "Feed" | "Gaming" | "Anime" | "Art" | "Philosophy" | "Music" | "Technology" | "Movies" | "Sports" | "Books" | "Fashion" | "Culture" | "Relationships" | "Business" | "Comedy" | "Science" | "Lifestyle" | "Food" | "Travel" | "General";
export type RoomPrivacy = "public" | "private";

export type Room = {
  id: string;
  title: string;
  slug: string;
  description: string;
  category: RoomCategory;
  privacy: RoomPrivacy;
  speakerIds: string[];
  listenerIds: string[];
  participantCount: number;
  speakerCount?: number;
  maxParticipants?: number;
  noiseControlEnabled?: boolean;
  isLive: boolean;
  ownerId?: string;
  speakers?: import("./user").User[];
  listeners?: import("./user").User[];
  currentUserRole?: "owner" | "host" | "speaker" | "listener";
  mutedUserIds?: string[];
  currentUserAdminMuted?: boolean;
};
