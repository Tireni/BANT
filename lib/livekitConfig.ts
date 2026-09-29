export type LiveKitTokenResponse = {
  token: string;
  url: string;
  roomName: string;
  participantIdentity: string;
};

export function liveKitTokenErrorMessage(message?: string) {
  const value = (message ?? "").toLowerCase();
  if (value.includes("not configured")) return "Room audio is not configured yet.";
  if (value.includes("ended") || value.includes("not live")) return "This room has ended.";
  if (value.includes("member") || value.includes("access")) return "You don't have access to this room.";
  if (value.includes("auth")) return "Sign in first.";
  return "Unable to connect to room audio.";
}
