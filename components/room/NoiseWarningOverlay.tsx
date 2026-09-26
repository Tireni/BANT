import { useEffect, useRef, useState } from "react";
import { Animated, StyleSheet, Text, View } from "react-native";
import { hasSupabaseConfig, supabase } from "@/lib/supabase";
import { useTheme } from "@/hooks/useTheme";

type RoomWarning = {
  id: string;
  room_id: string;
  sender_id: string;
  target_user_id?: string | null;
  message: string;
  created_at?: string;
};

export function NoiseWarningOverlay({ roomId, currentUserId }: { roomId?: string; currentUserId?: string }) {
  const theme = useTheme();
  const [warnings, setWarnings] = useState<RoomWarning[]>([]);
  const timersRef = useRef<Set<ReturnType<typeof setTimeout>>>(new Set());

  useEffect(() => {
    if (!hasSupabaseConfig || !roomId || !currentUserId) return;

    const channel = supabase
      .channel(`room-warnings:${roomId}:${currentUserId}`)
      .on("postgres_changes", { event: "INSERT", schema: "public", table: "room_warnings", filter: `room_id=eq.${roomId}` }, (payload) => {
        const warning = payload.new as RoomWarning;
        if (warning.target_user_id && warning.target_user_id !== currentUserId) return;
        const id = warning.id ?? `${Date.now()}-${Math.random()}`;
        setWarnings((current) => [...current, { ...warning, id }]);
        const timer = setTimeout(() => {
          setWarnings((current) => current.filter((item) => item.id !== id));
          timersRef.current.delete(timer);
        }, 3200);
        timersRef.current.add(timer);
      })
      .subscribe();

    return () => {
      timersRef.current.forEach((timer) => clearTimeout(timer));
      timersRef.current.clear();
      void supabase.removeChannel(channel);
    };
  }, [currentUserId, roomId]);

  if (!warnings.length) return null;

  return (
    <View pointerEvents="none" style={styles.container}>
      {warnings.map((warning) => (
        <Animated.View key={warning.id} style={[styles.toast, { backgroundColor: theme.colors.surface, borderColor: theme.colors.warning }]}> 
          <Text style={[styles.symbol, { color: theme.colors.warning }]}>🤫</Text>
          <Text style={[styles.text, { color: theme.colors.text }]}>{warning.message || "Easy on the noise"}</Text>
        </Animated.View>
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    position: "absolute",
    top: 90,
    left: 0,
    right: 0,
    alignItems: "center",
    zIndex: 30,
    pointerEvents: "none"
  },
  toast: {
    marginTop: 8,
    flexDirection: "row",
    alignItems: "center",
    gap: 10,
    borderWidth: 1,
    paddingHorizontal: 16,
    paddingVertical: 10,
    borderRadius: 999,
    shadowColor: "#000",
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.18,
    shadowRadius: 12,
    elevation: 8
  },
  symbol: { fontSize: 22 },
  text: { fontFamily: "PlusJakartaSans_800ExtraBold", fontSize: 13 }
});
