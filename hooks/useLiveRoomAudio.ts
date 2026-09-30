import { useCallback, useEffect, useState } from "react";
import { Platform } from "react-native";
import { LocalAudioTrack, Room, RoomEvent, Track, createLocalAudioTrack } from "livekit-client";
import { LiveKitTokenResponse, liveKitTokenErrorMessage } from "@/lib/livekitConfig";
import { hasSupabaseConfig, supabase } from "@/lib/supabase";

type VoiceStatus = "idle" | "requesting" | "connected" | "reconnecting" | "error";

type VoiceSnapshot = {
  roomId: string | null;
  status: VoiceStatus;
  selfMuted: boolean;
  error: string | null;
  remoteCount: number;
};

let activeRoom: Room | null = null;
let activeRoomId: string | null = null;
let localAudioTrack: LocalAudioTrack | null = null;
let starting = false;
let selfMuted = false;
let lastAdminMuted = false;
let snapshot: VoiceSnapshot = {
  roomId: null,
  status: "idle",
  selfMuted: false,
  error: null,
  remoteCount: 0
};
const remoteAudioElements = new Map<string, HTMLMediaElement[]>();
const subscribers = new Set<(next: VoiceSnapshot) => void>();

function publish(next: Partial<VoiceSnapshot>) {
  snapshot = { ...snapshot, ...next };
  subscribers.forEach((listener) => listener(snapshot));
}

async function applyMute() {
  if (!localAudioTrack) return;
  if (selfMuted || lastAdminMuted) await localAudioTrack.mute();
  else await localAudioTrack.unmute();
}

async function stopGlobalVoice() {
  localAudioTrack?.stop();
  localAudioTrack = null;

  remoteAudioElements.forEach((elements) => elements.forEach((element) => element.remove()));
  remoteAudioElements.clear();

  const room = activeRoom;
  activeRoom = null;
  activeRoomId = null;
  starting = false;

  if (room) {
    room.removeAllListeners();
    await room.disconnect();
  }

  publish({
    roomId: null,
    status: "idle",
    remoteCount: 0,
    error: null
  });
}

async function startGlobalVoice(roomId: string) {
  if (starting) return;
  if (activeRoom && activeRoomId === roomId && ["requesting", "connected", "reconnecting"].includes(snapshot.status)) return;

  if (activeRoom && activeRoomId !== roomId) {
    await stopGlobalVoice();
  }

  if (!hasSupabaseConfig) {
    publish({ status: "error", error: "Supabase env vars are required for room audio." });
    return;
  }

  starting = true;
  activeRoomId = roomId;
  publish({ roomId, status: "requesting", error: null });

  try {
    const { data, error: tokenError } = await supabase.functions.invoke<LiveKitTokenResponse>("livekit-token", {
      body: { room_id: roomId }
    });

    if (tokenError || !data?.token || !data.url) {
      let detail = tokenError?.message ?? "Unable to create room audio token";
      const context = (tokenError as any)?.context;
      if (context && typeof context.clone === "function") {
        try {
          const payload = await context.clone().json();
          if (typeof payload?.error === "string" && payload.error.trim()) detail = payload.error;
        } catch {
          // Keep transport error when body is unavailable.
        }
      }
      throw new Error(detail);
    }

    const room = new Room({ adaptiveStream: true, dynacast: true });
    activeRoom = room;

    room
      .on(RoomEvent.ParticipantConnected, () => {
        if (activeRoom !== room) return;
        publish({ remoteCount: room.remoteParticipants.size });
      })
      .on(RoomEvent.ParticipantDisconnected, () => {
        if (activeRoom !== room) return;
        publish({ remoteCount: room.remoteParticipants.size });
      })
      .on(RoomEvent.TrackSubscribed, (track) => {
        if (track.kind !== Track.Kind.Audio || typeof document === "undefined") return;
        const element = track.attach();
        element.autoplay = true;
        element.setAttribute("playsinline", "true");
        document.body.appendChild(element);
        const trackKey = track.sid ?? track.mediaStreamTrack.id;
        remoteAudioElements.set(trackKey, [element]);
      })
      .on(RoomEvent.TrackUnsubscribed, (track) => {
        track.detach().forEach((element) => element.remove());
        const trackKey = track.sid ?? track.mediaStreamTrack.id;
        remoteAudioElements.delete(trackKey);
      })
      .on(RoomEvent.Reconnecting, () => {
        if (activeRoom === room) publish({ status: "reconnecting" });
      })
      .on(RoomEvent.Reconnected, () => {
        if (activeRoom === room) publish({ status: "connected" });
      })
      .on(RoomEvent.Disconnected, () => {
        if (activeRoom !== room) return;
        activeRoom = null;
        activeRoomId = null;
        localAudioTrack = null;
        publish({ roomId: null, status: "idle", remoteCount: 0 });
      });

    await room.connect(data.url, data.token);

    const audioTrack = await createLocalAudioTrack({
      echoCancellation: true,
      noiseSuppression: true
    });
    localAudioTrack = audioTrack;
    await room.localParticipant.publishTrack(audioTrack);
    await applyMute();

    publish({
      roomId,
      status: "connected",
      remoteCount: room.remoteParticipants.size,
      error: null
    });
  } catch (err) {
    await stopGlobalVoice();
    publish({
      status: "error",
      error: err instanceof Error ? liveKitTokenErrorMessage(err.message) : "Unable to connect to room audio."
    });
  } finally {
    starting = false;
  }
}

export function useLiveRoomAudio({ roomId, adminMuted = false }: { roomId?: string; adminMuted?: boolean }) {
  const [state, setState] = useState(snapshot);
  const supported = Platform.OS === "web";
  const isThisRoom = Boolean(roomId && state.roomId === roomId);

  useEffect(() => {
    subscribers.add(setState);
    setState(snapshot);
    return () => {
      subscribers.delete(setState);
    };
  }, []);

  useEffect(() => {
    lastAdminMuted = adminMuted;
    void applyMute().catch(() => {
      publish({ error: "Unable to update microphone state." });
    });
  }, [adminMuted]);

  const start = useCallback(async () => {
    if (!roomId) {
      publish({ status: "error", error: "Join the room before starting voice." });
      return;
    }
    if (!supported) {
      publish({ status: "error", error: "Live room audio is currently available on the BANT web app." });
      return;
    }
    await startGlobalVoice(roomId);
  }, [roomId, supported]);

  const stop = useCallback(async () => {
    if (!roomId || activeRoomId === roomId) {
      await stopGlobalVoice();
    }
  }, [roomId]);

  const toggleMute = useCallback(() => {
    selfMuted = !selfMuted;
    publish({ selfMuted });
    void applyMute().catch(() => {
      publish({ error: "Unable to update microphone state." });
    });
  }, []);

  return {
    status: isThisRoom ? state.status : "idle" as VoiceStatus,
    connected: isThisRoom && state.status === "connected",
    muted: selfMuted || adminMuted,
    selfMuted,
    adminMuted,
    remoteCount: isThisRoom ? state.remoteCount : 0,
    error: isThisRoom ? state.error : null,
    supported,
    start,
    stop,
    toggleMute
  };
}
