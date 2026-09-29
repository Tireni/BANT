export type User = {
  id: string;
  name: string;
  username: string;
  avatarColor: string;
  avatar_url?: string | null;
  bio: string;
  online: boolean;
  roomId?: string;
};
