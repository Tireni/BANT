export type FriendState = "none" | "pending_sent" | "pending_received" | "friends";

export function friendshipStateFor(userId: string, input: { friendIds: string[]; incomingIds: string[]; outgoingIds: string[] }): FriendState {
  if (input.friendIds.includes(userId)) return "friends";
  if (input.incomingIds.includes(userId)) return "pending_received";
  if (input.outgoingIds.includes(userId)) return "pending_sent";
  return "none";
}
