import { useCallback, useEffect, useState } from "react";
import { hasSupabaseConfig, supabase } from "@/lib/supabase";

export type RoomMessage = {
  id: string;
  roomId: string;
  senderId: string;
  senderName: string;
  body: string;
  createdAt: string;
};

type MessageRow = {
  id: string;
  room_id: string;
  sender_id: string;
  body: string;
  created_at: string;
  profiles?: { display_name: string; username: string } | { display_name: string; username: string }[] | null;
};

export function useRoomChat(roomId?: string, currentUserId?: string) {
  const [messages, setMessages] = useState<RoomMessage[]>([]);
  const [loading, setLoading] = useState(false);
  const [sending, setSending] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const loadMessages = useCallback(async () => {
    if (!roomId || !currentUserId) return;
    if (!hasSupabaseConfig) {
      setMessages([]);
      setError("Chat needs Supabase env vars and the Phase 4 migration.");
      return;
    }
    setLoading(true);
    setError(null);
    const { data, error: loadError } = await supabase
      .from("room_messages")
      .select("id, room_id, sender_id, body, created_at, profiles(display_name, username)")
      .eq("room_id", roomId)
      .order("created_at", { ascending: true })
      .limit(80);
    if (loadError) {
      setError(loadError.message);
      setLoading(false);
      return;
    }
    setMessages((data ?? []).map(shapeMessage));
    setLoading(false);
  }, [currentUserId, roomId]);

  const sendMessage = useCallback(async (body: string) => {
    if (!roomId || !currentUserId) return false;
    const trimmed = body.trim();
    if (!trimmed) {
      setError("Type a message first.");
      return false;
    }
    if (trimmed.length > 500) {
      setError("Keep messages under 500 characters.");
      return false;
    }
    if (!hasSupabaseConfig) {
      setError("Chat needs Supabase env vars and the Phase 4 migration.");
      return false;
    }
    setSending(true);
    setError(null);
    const { error: sendError } = await supabase.from("room_messages").insert({
      room_id: roomId,
      sender_id: currentUserId,
      body: trimmed
    });
    setSending(false);
    if (sendError) {
      setError(sendError.message);
      return false;
    }
    return true;
  }, [currentUserId, roomId]);

  useEffect(() => {
    void loadMessages();
  }, [loadMessages]);

  useEffect(() => {
    if (!roomId || !currentUserId || !hasSupabaseConfig) return;
    const channel = supabase
      .channel(`room-messages:${roomId}`)
      .on("postgres_changes", { event: "INSERT", schema: "public", table: "room_messages", filter: `room_id=eq.${roomId}` }, () => {
        void loadMessages();
      })
      .subscribe();
    return () => {
      void supabase.removeChannel(channel);
    };
  }, [currentUserId, loadMessages, roomId]);

  return { messages, loading, sending, error, sendMessage, reload: loadMessages };
}

function shapeMessage(row: MessageRow): RoomMessage {
  const profile = Array.isArray(row.profiles) ? row.profiles[0] : row.profiles;
  return {
    id: row.id,
    roomId: row.room_id,
    senderId: row.sender_id,
    senderName: profile?.display_name ?? profile?.username ?? "BANT user",
    body: row.body,
    createdAt: row.created_at
  };
}
