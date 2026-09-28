import AsyncStorage from "@react-native-async-storage/async-storage";
import { Redirect, router, useLocalSearchParams } from "expo-router";
import { useEffect, useState } from "react";
import { ActivityIndicator, StyleSheet, Text, View } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { BantButton } from "@/components/common/BantButton";
import { useTheme } from "@/hooks/useTheme";
import { onboardingRoute } from "@/lib/onboarding";
import { PENDING_INVITE_TOKEN_KEY } from "@/lib/roomInvites";
import { useBantStore } from "@/store/useBantStore";

export default function InviteRoute() {
  const { token } = useLocalSearchParams<{ token: string }>();
  const theme = useTheme();
  const authenticated = useBantStore((state) => state.authenticated);
  const profile = useBantStore((state) => state.profile);
  const joinRoomWithInvite = useBantStore((state) => state.joinRoomWithInvite);
  const [joining, setJoining] = useState(false);
  const [done, setDone] = useState(false);

  useEffect(() => {
    const inviteToken = Array.isArray(token) ? token[0] : token;
    if (!inviteToken) return;
    if (!authenticated) {
      void AsyncStorage.setItem(PENDING_INVITE_TOKEN_KEY, inviteToken).then(() => router.replace("/auth/welcome"));
      return;
    }
    if (!profile?.onboarding_completed) return;
    setJoining(true);
    void joinRoomWithInvite(inviteToken).then(async (roomId) => {
      setJoining(false);
      setDone(true);
      if (!roomId) return;
      await AsyncStorage.removeItem(PENDING_INVITE_TOKEN_KEY);
      router.replace(`/room/${roomId}`);
    });
  }, [authenticated, joinRoomWithInvite, profile?.onboarding_completed, token]);

  if (authenticated && !profile?.onboarding_completed) return <Redirect href={onboardingRoute(profile) as any} />;

  return (
    <SafeAreaView style={[styles.screen, { backgroundColor: theme.colors.background }]}>
      <View style={styles.card}>
        {joining ? <ActivityIndicator color={theme.colors.blue} /> : null}
        <Text style={[styles.title, { color: theme.colors.text }]}>{joining ? "Joining room..." : done ? "Invite checked" : "Opening invite..."}</Text>
        <Text style={[styles.body, { color: theme.colors.secondary }]}>BANT is validating this invite with the server.</Text>
        {done && !joining ? <BantButton title="Back to rooms" variant="ghost" onPress={() => router.replace("/(tabs)/rooms")} /> : null}
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, alignItems: "center", justifyContent: "center", padding: 20 },
  card: { width: "100%", maxWidth: 420, gap: 14, alignItems: "center" },
  title: { fontFamily: "PlusJakartaSans_800ExtraBold", fontSize: 24, textAlign: "center" },
  body: { fontFamily: "PlusJakartaSans_500Medium", fontSize: 14, lineHeight: 20, textAlign: "center" }
});
