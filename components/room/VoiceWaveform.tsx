import { StyleSheet, View } from "react-native";
import Animated, { useAnimatedStyle, useSharedValue, withDelay, withRepeat, withSequence, withTiming } from "react-native-reanimated";
import { useEffect } from "react";
import { useTheme } from "@/hooks/useTheme";

function WaveBar({ delay }: { delay: number }) {
  const theme = useTheme();
  const height = useSharedValue(8);
  useEffect(() => {
    height.value = withDelay(delay, withRepeat(withSequence(withTiming(24, { duration: 300 }), withTiming(9, { duration: 280 }), withTiming(18, { duration: 260 })), -1, true));
  }, [delay, height]);
  const animated = useAnimatedStyle(() => ({ height: height.value }));
  return <Animated.View style={[styles.bar, animated, { backgroundColor: theme.colors.mint }]} />;
}

export function VoiceWaveform() {
  return (
    <View style={styles.wrap}>
      {[0, 90, 180, 270].map((delay) => <WaveBar key={delay} delay={delay} />)}
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: { height: 28, flexDirection: "row", alignItems: "center", gap: 4 },
  bar: { width: 5, borderRadius: 99 }
});
