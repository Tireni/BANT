import Animated, { FadeInDown, FadeOutDown } from "react-native-reanimated";
import { StyleSheet, Text } from "react-native";
import { useEffect } from "react";
import { useTheme } from "@/hooks/useTheme";
import { useBantStore } from "@/store/useBantStore";

export function Toast() {
  const theme = useTheme();
  const toast = useBantStore((state) => state.toast);
  const setToast = useBantStore((state) => state.setToast);
  useEffect(() => {
    if (!toast) return;
    const timer = setTimeout(() => setToast(null), 2600);
    return () => clearTimeout(timer);
  }, [toast, setToast]);
  if (!toast) return null;
  return (
    <Animated.View entering={FadeInDown.duration(180)} exiting={FadeOutDown.duration(160)} style={[styles.toast, { backgroundColor: theme.colors.text }]}>
      <Text style={[styles.text, { color: theme.colors.background }]}>{toast}</Text>
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  toast: { position: "absolute", left: 20, right: 20, bottom: 104, borderRadius: 18, padding: 14, zIndex: 50, alignItems: "center" },
  text: { fontFamily: "PlusJakartaSans_700Bold", fontSize: 14 }
});
