import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { Platform } from "react-native";
import { hasSupabaseConfig, supabase } from "@/lib/supabase";
import { buildRtcConfig } from "@/lib/voiceConfig";

type VoiceStatus = "idle" | "requesting" | "connected" | "error";
type SignalKind = "offer" | "answer" | "ice" | "leave";

type VoiceSignal = {
  room_id: string;
  sender_id: string;
  recipient_id: string;
  kind: SignalKind;
  payload: Record<string, unknown>;
};

export function useRoomVoice({ roomId, currentUserId, peerIds, adminMuted = false }: { roomId?: string; currentUserId?: string; peerIds: string[]; adminMuted?: boolean }) {
  const [status, setStatus] = useState<VoiceStatus>("idle");
  const [muted, setMuted] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [remoteCount, setRemoteCount] = useState(0);
  const localStreamRef = useRef<MediaStream | null>(null);
  const peersRef = useRef<Map<string, RTCPeerConnection>>(new Map());
  const remoteAudioRef = useRef<Map<string, HTMLAudioElement>>(new Map());
  const peerIdsRef = useRef<string[]>([]);
  const connectedPeerIdsRef = useRef<Set<string>>(new Set());

  const uniquePeerIds = useMemo(() => Array.from(new Set(peerIds.filter((id) => id && id !== currentUserId))).sort(), [currentUserId, peerIds]);
  const supported = Platform.OS === "web"
    && typeof navigator !== "undefined"
    && Boolean(navigator.mediaDevices?.getUserMedia)
    && typeof RTCPeerConnection !== "undefined";

  const sendSignal = useCallback(async (recipientId: string, kind: SignalKind, payload: Record<string, unknown>) => {
    if (!roomId || !currentUserId || !hasSupabaseConfig) return;
    try {
      const { error } = await supabase.from("voice_signals").insert({
        room_id: roomId,
        sender_id: currentUserId,
        recipient_id: recipientId,
        kind,
        payload
      });
      if (error) {
        setError(error.message);
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : "Voice signaling failed.");
    }
  }, [currentUserId, roomId]);

  const closePeer = useCallback((peerId: string) => {
    peersRef.current.get(peerId)?.close();
    peersRef.current.delete(peerId);
    connectedPeerIdsRef.current.delete(peerId);
    const audio = remoteAudioRef.current.get(peerId);
    if (audio) {
      audio.pause();
      audio.srcObject = null;
      audio.remove();
    }
    remoteAudioRef.current.delete(peerId);
    setRemoteCount(remoteAudioRef.current.size);
  }, []);

  const createPeer = useCallback((peerId: string) => {
    const existing = peersRef.current.get(peerId);
    if (existing) return existing;
    const stream = localStreamRef.current;
    if (!stream) return null;
    const peer = new RTCPeerConnection(buildRtcConfig());
    stream.getTracks().forEach((track) => peer.addTrack(track, stream));
    peer.onicecandidate = (event) => {
      if (event.candidate) {
        void sendSignal(peerId, "ice", event.candidate.toJSON() as Record<string, unknown>);
      }
    };
    peer.ontrack = (event) => {
      if (Platform.OS !== "web" || typeof document === "undefined") return;
      const [remoteStream] = event.streams;
      if (!remoteStream) return;
      let audio = remoteAudioRef.current.get(peerId);
      if (!audio) {
        audio = document.createElement("audio");
        audio.autoplay = true;
        audio.muted = false;
        audio.setAttribute("playsinline", "true");
        document.body.appendChild(audio);
        remoteAudioRef.current.set(peerId, audio);
      }
      audio.srcObject = remoteStream;
      void audio.play().catch(() => {
        setError("Try voice again if your browser blocks audio playback.");
      });
      connectedPeerIdsRef.current.add(peerId);
      setRemoteCount(remoteAudioRef.current.size);
    };
    peer.onconnectionstatechange = () => {
      if (["failed", "disconnected", "closed"].includes(peer.connectionState)) closePeer(peerId);
    };
    peersRef.current.set(peerId, peer);
    return peer;
  }, [closePeer, sendSignal]);

  const startOffer = useCallback(async (peerId: string) => {
    const peer = createPeer(peerId);
    if (!peer) return;
    if (peer.signalingState !== "stable") return;
    const offer = await peer.createOffer();
    await peer.setLocalDescription(offer);
    await sendSignal(peerId, "offer", { type: offer.type, sdp: offer.sdp });
  }, [createPeer, sendSignal]);

  const handleSignal = useCallback(async (signal: VoiceSignal) => {
    if (!currentUserId || signal.recipient_id !== currentUserId || signal.sender_id === currentUserId) return;
    if (signal.kind === "leave") {
      closePeer(signal.sender_id);
      return;
    }
    const peer = createPeer(signal.sender_id);
    if (!peer) return;
    if (signal.kind === "offer") {
      await peer.setRemoteDescription(new RTCSessionDescription(signal.payload as unknown as RTCSessionDescriptionInit));
      const answer = await peer.createAnswer();
      await peer.setLocalDescription(answer);
      await sendSignal(signal.sender_id, "answer", { type: answer.type, sdp: answer.sdp });
      return;
    }
    if (signal.kind === "answer") {
      if (peer.signalingState === "stable") {
        await peer.setRemoteDescription(new RTCSessionDescription(signal.payload as unknown as RTCSessionDescriptionInit));
      } else {
        await peer.setRemoteDescription(new RTCSessionDescription(signal.payload as unknown as RTCSessionDescriptionInit));
      }
      return;
    }
    if (signal.kind === "ice") {
      await peer.addIceCandidate(new RTCIceCandidate(signal.payload)).catch(() => {});
    }
  }, [closePeer, createPeer, currentUserId, sendSignal]);

  const start = useCallback(async () => {
    if (!roomId || !currentUserId) {
      setError("Join the room before starting voice.");
      setStatus("error");
      return;
    }
    if (!hasSupabaseConfig) {
      setError("Real voice needs Supabase env vars and the Phase 3 migration.");
      setStatus("error");
      return;
    }
    if (!supported) {
      setError("This browser does not support web microphone voice rooms.");
      setStatus("error");
      return;
    }
    try {
      setStatus("requesting");
      setError(null);
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true, video: false });
      localStreamRef.current = stream;
      stream.getAudioTracks().forEach((track) => {
        track.enabled = !muted && !adminMuted;
      });
      setStatus("connected");
      peerIdsRef.current = uniquePeerIds;
      uniquePeerIds.forEach((peerId) => {
        const peer = peersRef.current.get(peerId);
        if (peer && peer.signalingState !== "stable") return;
        void startOffer(peerId).catch((err) => setError(err instanceof Error ? err.message : "Unable to start voice connection."));
      });
    } catch (err) {
      setStatus("error");
      setError(err instanceof Error ? err.message : "Microphone permission was denied.");
    }
  }, [adminMuted, currentUserId, muted, roomId, startOffer, supported, uniquePeerIds]);

  const stop = useCallback(() => {
    peerIdsRef.current.forEach((peerId) => void sendSignal(peerId, "leave", {}));
    peersRef.current.forEach((peer) => peer.close());
    peersRef.current.clear();
    remoteAudioRef.current.forEach((audio) => {
      audio.pause();
      audio.srcObject = null;
      audio.remove();
    });
    remoteAudioRef.current.clear();
    localStreamRef.current?.getTracks().forEach((track) => track.stop());
    localStreamRef.current = null;
    setRemoteCount(0);
    setStatus("idle");
  }, [sendSignal]);

  const toggleMute = useCallback(() => {
    if (adminMuted) {
      localStreamRef.current?.getAudioTracks().forEach((track) => {
        track.enabled = false;
      });
      setMuted(true);
      return;
    }
    const next = !muted;
    localStreamRef.current?.getAudioTracks().forEach((track) => {
      track.enabled = !next;
    });
    setMuted(next);
  }, [adminMuted, muted]);

  useEffect(() => {
    localStreamRef.current?.getAudioTracks().forEach((track) => {
      track.enabled = !muted && !adminMuted;
    });
    if (adminMuted) setMuted(true);
  }, [adminMuted, muted]);

  useEffect(() => {
    if (status !== "connected" || !roomId || !currentUserId) return;
    const channel = supabase
      .channel(`voice-signals:${roomId}:${currentUserId}`)
      .on("postgres_changes", { event: "INSERT", schema: "public", table: "voice_signals", filter: `room_id=eq.${roomId}` }, (payload) => {
        void handleSignal(payload.new as VoiceSignal).catch((err) => {
          setError(err instanceof Error ? err.message : "Voice signaling failed.");
        });
      })
      .subscribe();
    return () => {
      void supabase.removeChannel(channel);
    };
  }, [currentUserId, handleSignal, roomId, status]);

  useEffect(() => {
    if (status !== "connected" || !currentUserId) return;
    peerIdsRef.current = uniquePeerIds;
    uniquePeerIds.forEach((peerId) => {
      const peer = peersRef.current.get(peerId);
      if (peer && peer.signalingState !== "stable") return;
      void startOffer(peerId).catch((err) => setError(err instanceof Error ? err.message : "Unable to start voice connection."));
    });
  }, [currentUserId, startOffer, status, uniquePeerIds]);

  useEffect(() => {
    return () => stop();
  }, [stop]);

  return {
    status,
    muted,
    adminMuted,
    error,
    remoteCount,
    supported,
    start,
    stop,
    toggleMute
  };
}
