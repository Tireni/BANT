import { Redirect } from "expo-router";
import { Image, StyleSheet, View } from "react-native";
import Animated, { FadeIn, useAnimatedStyle, useSharedValue, withDelay, withRepeat, withSequence, withTiming } from "react-native-reanimated";
import { useEffect, useState } from "react";
import { useTheme } from "@/hooks/useTheme";
import { onboardingRoute } from "@/lib/onboarding";
import { useBantStore } from "@/store/useBantStore";

const logo = require("../assets/brand/bant-logo-reverse.png");

function Dot({ delay }: { delay: number }) {
  const theme = useTheme();
  const opacity = useSharedValue(0.3);
  useEffect(() => {
    opacity.value = withDelay(delay, withRepeat(withSequence(withTiming(1, { duration: 280 }), withTiming(0.3, { duration: 280 })), -1, true));
  }, [delay, opacity]);
  const animated = useAnimatedStyle(() => ({ opacity: opacity.value }));
  return <Animated.View style={[styles.dot, animated, { backgroundColor: theme.colors.mint }]} />;
}

export default function Splash() {
  const theme = useTheme();
  const authenticated = useBantStore((state) => state.authenticated);
  const profile = useBantStore((state) => state.profile);
  const ready = useSharedValue(false);
  const [go, setGo] = useState(false);
  useEffect(() => {
    const timer = setTimeout(() => {
      ready.value = true;
      setGo(true);
    }, 1300);
    return () => clearTimeout(timer);
  }, [ready]);
  if (go) {
    if (!authenticated) return <Redirect href="/auth/welcome" />;
    if (!profile?.onboarding_completed) return <Redirect href={onboardingRoute(profile) as any} />;
    return <Redirect href="/(tabs)/home" />;
  }
  return (
    <View style={[styles.splash, { backgroundColor: theme.colors.background }]}>
      <Animated.View entering={FadeIn.duration(300)} style={styles.center}>
        <View style={[styles.logoShell, { backgroundColor: theme.colors.blue }]}>
          <Image source={logo} resizeMode="contain" style={styles.logo} />
        </View>
        <View style={styles.dots}><Dot delay={0} /><Dot delay={160} /><Dot delay={320} /></View>
      </Animated.View>
    </View>
  );
}

const styles = StyleSheet.create({
  splash: { flex: 1, alignItems: "center", justifyContent: "center" },
  center: { alignItems: "center" },
  logoShell: { width: 164, height: 92, borderRadius: 28, alignItems: "center", justifyContent: "center", overflow: "hidden" },
  logo: { width: 150, height: 78 },
  dots: { flexDirection: "row", gap: 8, marginTop: 20 },
  dot: { width: 8, height: 8, borderRadius: 99 }
});
