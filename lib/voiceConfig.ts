import { MAX_MESH_VOICE_PARTICIPANTS } from "@/lib/roomLogic";

type TurnEnv = Record<string, string | undefined> & {
  EXPO_PUBLIC_TURN_URL?: string;
  EXPO_PUBLIC_TURN_USERNAME?: string;
  EXPO_PUBLIC_TURN_CREDENTIAL?: string;
};

export function buildIceServers(env: TurnEnv = process.env): RTCIceServer[] {
  const iceServers: RTCIceServer[] = [{ urls: "stun:stun.l.google.com:19302" }];
  const turnUrl = env.EXPO_PUBLIC_TURN_URL?.trim();
  if (!turnUrl) return iceServers;

  iceServers.push({
    urls: turnUrl,
    username: env.EXPO_PUBLIC_TURN_USERNAME?.trim() || undefined,
    credential: env.EXPO_PUBLIC_TURN_CREDENTIAL?.trim() || undefined
  });
  return iceServers;
}

export function buildRtcConfig(env: TurnEnv = process.env): RTCConfiguration {
  return { iceServers: buildIceServers(env) };
}

export function voicePeerIdsFor(currentUserId: string | undefined, participantIds: string[], limit = MAX_MESH_VOICE_PARTICIPANTS) {
  const uniqueIds = Array.from(new Set(participantIds.filter(Boolean)));
  const voiceSlotIds = uniqueIds.slice(0, limit);
  return voiceSlotIds.filter((id) => id !== currentUserId);
}

