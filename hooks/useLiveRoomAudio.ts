import { useCallback, useEffect, useRef, useState } from "react";
import { Platform } from "react-native";
import { LocalAudioTrack, Room, RoomEvent, Track, createLocalAudioTrack } from "livekit-client";
import { LiveKitTokenResponse, liveKitTokenErrorMessage } from "@/lib/livekitConfig";
import { hasSupabaseConfig, supabase } from "@/lib/supabase";

type VoiceStatus = "idle" | "requesting" | "connected" | "reconnecting" | "error";

export function useLiveRoomAudio({ roomId, adminMuted = false }: { roomId?: string; adminMuted?: boolean }) {
  const [status, setStatus] = useState<VoiceStatus>("idle");
  const [selfMuted, setSelfMuted] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [remoteParticipantCount, setRemoteParticipantCount] = useState(0);
  const roomRef = useRef<Room | null>(null);
  const localAudioRef = useRef<LocalAudioTrack | null>(null);
  const remoteAudioElementsRef = useRef<Map<string, HTMLMediaElement[]>>(new Map());

  const supported = Platform.OS === "web";
  const effectiveMuted = selfMuted || adminMuted;

  const applyEffectiveMute = useCallback(async () => {
    const track = localAudioRef.current;
    if (!track) return;
    if (selfMuted || adminMuted) {
      await track.mute();
      return;
    }
    await track.unmute();
  }, [adminMuted, selfMuted]);

  const stop = useCallback(async () => {
    localAudioRef.current?.stop();
    localAudioRef.current = null;
    remoteAudioElementsRef.current.forEach((elements) => elements.forEach((element) => element.remove()));
    remoteAudioElementsRef.current.clear();
    const room = roomRef.current;
    roomRef.current = null;
    if (room) {
      room.removeAllListeners();
      await room.disconnect();
    }
    setRemoteParticipantCount(0);
    setStatus("idle");
  }, []);

  const start = useCallback(async () => {
    if (!roomId) {
      setError("Join the room before starting voice.");
      setStatus("error");
      return;
    }
    if (!supported) {
      setError("Live room audio is web-ready in this MVP. Native audio needs a development build validation.");
      setStatus("error");
      return;
    }
    if (!hasSupabaseConfig) {
      setError("Supabase env vars are required for room audio.");
      setStatus("error");
      return;
    }
    if (roomRef.current && status === "connected") return;

    try {
      setStatus("requesting");
      setError(null);
      const { data, error: tokenError } = await supabase.functions.invoke<LiveKitTokenResponse>("livekit-token", {
        body: { room_id: roomId }
      });
      if (tokenError || !data?.token || !data.url) {
        throw new Error(liveKitTokenErrorMessage(tokenError?.message));
      }

      const room = new Room({ adaptiveStream: true, dynacast: true });
      roomRef.current = room;
      room
        .on(RoomEvent.ParticipantConnected, () => setRemoteParticipantCount(room.remoteParticipants.size))
.on(RoomEvent.ParticipantDisconnected, () => setRemoteParticipantCount(room.remoteParticipants.size))
        .on(RoomEvent.TrackSubscribed, (track) => {
          if (track.kind !== Track.Kind.Audio || typeof document === "undefined") return;
          const element = track.attach();
          element.autoplay = true;
          element.setAttribute("playsinline", "true");
          document.body.appendChild(element);
          const trackKey = track.sid ?? track.mediaStreamTrack.id;
          remoteAudioElementsRef.current.set(trackKey, [element]);
        })
        .on(RoomEvent.TrackUnsubscribed, (track) => {
          track.detach().forEach((element) => element.remove());
          const trackKey = track.sid ?? track.mediaStreamTrack.id;
          remoteAudioElementsRef.current.delete(trackKey);
        })
        .on(RoomEvent.Reconnecting, () => setStatus("reconnecting"))
        .on(RoomEvent.Reconnected, () => setStatus("connected"))
        .on(RoomEvent.Disconnected, () => {
          setRemoteParticipantCount(0);
          setStatus("idle");
        });

      await room.connect(data.url, data.token);
      const audioTrack = await createLocalAudioTrack({ echoCancellation: true, noiseSuppression: true });
      localAudioRef.current = audioTrack;
      await room.localParticipant.publishTrack(audioTrack);
      if (effectiveMuted) await audioTrack.mute();
      setRemoteParticipantCount(room.remoteParticipants.size);
      setStatus("connected");
    } catch (err) {
      await stop();
      setStatus("error");
      setError(err instanceof Error ? liveKitTokenErrorMessage(err.message) : "Unable to connect to room audio.");
    }
  }, [effectiveMuted, roomId, status, stop, supported]);

  const toggleMute = useCallback(() => {
    setSelfMuted((value) => !value);
  }, []);

  useEffect(() => {
    void applyEffectiveMute().catch(() => {
      setError("Unable to update microphone state.");
    });
  }, [applyEffectiveMute]);

  useEffect(() => {
    return () => {
      void stop();
    };
  }, [stop]);

  return {
    status,
    connected: status === "connected",
    muted: effectiveMuted,
    selfMuted,
    adminMuted,
    remoteCount: remoteParticipantCount,
    error,
    supported,
    start,
    stop,
    toggleMute
  };
}

