import { router } from "expo-router";
import { Image, StyleSheet, Text, View } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { BantButton } from "@/components/common/BantButton";
import { useTheme } from "@/hooks/useTheme";

const mascot = require("../../assets/brand/bant-mascot.png");

export default function Welcome() {
  const theme = useTheme();
  return (
    <SafeAreaView style={[styles.screen, { backgroundColor: theme.colors.background }]}>
      <View style={styles.main}>
        <Image source={mascot} resizeMode="contain" style={styles.logo} />
        <Text style={[styles.brand, { color: theme.colors.blue }]}>BANT</Text>
        <Text style={[styles.headline, { color: theme.colors.text }]}>Discover live rooms.{"\n"}Meet people you vibe with.</Text>
        <Text style={[styles.body, { color: theme.colors.secondary }]}>Talk, share interests, build friendships, and create your own room.</Text>
      </View>
      <View style={styles.actions}>
        <BantButton title="Join BANT" onPress={() => router.push("/auth/sign-in")} />
        <BantButton title="I already have an account" variant="ghost" onPress={() => router.push("/auth/sign-in")} />
        <Text style={[styles.footer, { color: theme.colors.muted }]}>Built for real conversation.</Text>
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, padding: 20, justifyContent: "space-between" },
  main: { width: "100%", maxWidth: 520, alignSelf: "center", alignItems: "center", paddingTop: 50 },
  logo: { width: 104, height: 104 },
  brand: { fontFamily: "PlusJakartaSans_800ExtraBold", fontSize: 22, marginTop: 8 },
  headline: { textAlign: "center", fontFamily: "PlusJakartaSans_800ExtraBold", fontSize: 32, lineHeight: 38, marginTop: 22, maxWidth: 480 },
  body: { textAlign: "center", fontFamily: "PlusJakartaSans_500Medium", fontSize: 15, lineHeight: 22, marginTop: 12, maxWidth: 420 },
  actions: { width: "100%", maxWidth: 420, alignSelf: "center", gap: 12 },
  footer: { textAlign: "center", fontFamily: "PlusJakartaSans_600SemiBold", fontSize: 13, paddingVertical: 10 }
});
