import { StyleSheet, Text, View } from "react-native";
import Animated, { useAnimatedStyle, useSharedValue, withRepeat, withSequence, withTiming } from "react-native-reanimated";
import { useEffect } from "react";
import { BantAvatar } from "@/components/common/BantAvatar";
import { useTheme } from "@/hooks/useTheme";
import { User } from "@/types/user";
import { VoiceWaveform } from "./VoiceWaveform";

export function SpeakerAvatar({ user, active }: { user: User; active: boolean }) {
  const theme = useTheme();
  const scale = useSharedValue(1);
  useEffect(() => {
    if (!active) {
      scale.value = withTiming(1);
      return;
    }
    scale.value = withRepeat(withSequence(withTiming(1.08, { duration: 700 }), withTiming(1, { duration: 700 })), -1, false);
  }, [active, scale]);
  const animated = useAnimatedStyle(() => ({ transform: [{ scale: scale.value }] }));
  return (
    <View style={styles.wrap}>
      <Animated.View style={[styles.ring, active && { borderColor: theme.colors.mint, borderWidth: 3 }, animated]}>
        <BantAvatar user={user} size={72} />
      </Animated.View>
      <Text style={[styles.name, { color: theme.colors.text }]} numberOfLines={1}>{user.name.split(" ")[0]}</Text>
      {active ? <VoiceWaveform /> : <Text style={[styles.status, { color: theme.colors.muted }]}>speaker</Text>}
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: { width: 96, alignItems: "center", gap: 6 },
  ring: { padding: 4, borderRadius: 99, borderWidth: 3, borderColor: "transparent" },
  name: { fontFamily: "PlusJakartaSans_700Bold", fontSize: 13 },
  status: { fontFamily: "PlusJakartaSans_500Medium", fontSize: 11 }
});
