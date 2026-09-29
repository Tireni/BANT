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
  const [warnings, setWarnings] = useState<RoomWarning[]>([]);
  const seenRef = useRef<Set<string>>(new Set());
  const timersRef = useRef<Set<ReturnType<typeof setTimeout>>>(new Set());

  useEffect(() => {
    if (!hasSupabaseConfig || !roomId || !currentUserId) return;

    const channel = supabase
      .channel(`room-warnings:${roomId}:${currentUserId}`)
      .on("postgres_changes", { event: "INSERT", schema: "public", table: "room_warnings", filter: `room_id=eq.${roomId}` }, (payload) => {
        const warning = payload.new as RoomWarning;
        if (warning.target_user_id && warning.target_user_id !== currentUserId) return;
        const id = warning.id ?? `${Date.now()}-${Math.random()}`;
        if (seenRef.current.has(id)) return;
        seenRef.current.add(id);
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
      seenRef.current.clear();
      void supabase.removeChannel(channel);
    };
  }, [currentUserId, roomId]);

  if (!warnings.length) return null;

  return (
    <View pointerEvents="none" style={styles.container}>
      {warnings.map((warning) => <WarningToast key={warning.id} warning={warning} />)}
    </View>
  );
}

function WarningToast({ warning }: { warning: RoomWarning }) {
  const theme = useTheme();
  const progress = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    Animated.spring(progress, {
      toValue: 1,
      friction: 7,
      tension: 80,
      useNativeDriver: true
    }).start();
  }, [progress]);

  return (
    <Animated.View
      style={[
        styles.toast,
        {
          backgroundColor: theme.colors.surface,
          borderColor: theme.colors.warning,
          opacity: progress,
          transform: [
            { translateY: progress.interpolate({ inputRange: [0, 1], outputRange: [-18, 0] }) },
            { scale: progress.interpolate({ inputRange: [0, 1], outputRange: [0.94, 1] }) }
          ]
        }
      ]}
    >
      <Text style={[styles.symbol, { color: theme.colors.warning }]}>{"\uD83E\uDD2B"}</Text>
      <Text style={[styles.text, { color: theme.colors.text }]}>{warning.message || "Easy on the noise"}</Text>
    </Animated.View>
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
