import AsyncStorage from "@react-native-async-storage/async-storage";
import { Redirect, router, useLocalSearchParams } from "expo-router";
import { useEffect, useMemo, useState } from "react";
import { ActivityIndicator, Linking, Platform, StyleSheet, Text, View } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { BantButton } from "@/components/common/BantButton";
import { useTheme } from "@/hooks/useTheme";
import { onboardingRoute } from "@/lib/onboarding";
import { PENDING_INVITE_TOKEN_KEY } from "@/lib/roomInvites";
import { hasSupabaseConfig, supabase } from "@/lib/supabase";
import { useBantStore } from "@/store/useBantStore";

type InvitePreview = {
  room_id: string;
  room_title: string;
  room_description: string;
  room_category: string;
  room_privacy: string;
  room_status: string;
  invite_status: string;
};

export default function InviteRoute() {
  const { token } = useLocalSearchParams<{ token: string }>();
  const inviteToken = useMemo(() => Array.isArray(token) ? token[0] : token, [token]);
  const theme = useTheme();
  const hydrated = useBantStore((state) => state.hydrated);
  const authenticated = useBantStore((state) => state.authenticated);
  const profile = useBantStore((state) => state.profile);
  const joinRoomWithInvite = useBantStore((state) => state.joinRoomWithInvite);
  const [preview, setPreview] = useState<InvitePreview | null>(null);
  const [loadingPreview, setLoadingPreview] = useState(true);
  const [joining, setJoining] = useState(false);
  const [joinAttempted, setJoinAttempted] = useState(false);
  const [appOpenAttempted, setAppOpenAttempted] = useState(false);

  useEffect(() => {
    if (!inviteToken || !hasSupabaseConfig) {
      setLoadingPreview(false);
      return;
    }
    let active = true;
    void supabase.rpc("get_room_invite_preview", { p_invite_token: inviteToken }).then(({ data }) => {
      if (!active) return;
      const row = Array.isArray(data) ? data[0] : data;
      setPreview(row ?? null);
      setLoadingPreview(false);
      if (Platform.OS === "web" && typeof document !== "undefined" && row?.room_title) {
        document.title = `${row.room_title} | BANT`;
      }
    });
    return () => {
      active = false;
    };
  }, [inviteToken]);

  useEffect(() => {
    if (!inviteToken || !authenticated || !profile?.onboarding_completed || joining || joinAttempted) return;
    if (preview && (preview.invite_status !== "active" || preview.room_status !== "live")) return;
    setJoining(true);
    setJoinAttempted(true);
    void joinRoomWithInvite(inviteToken).then(async (roomId) => {
      setJoining(false);
      if (!roomId) return;
      await AsyncStorage.removeItem(PENDING_INVITE_TOKEN_KEY);
      router.replace(`/room/${roomId}`);
    });
  }, [authenticated, inviteToken, joinAttempted, joinRoomWithInvite, joining, preview, profile?.onboarding_completed]);

  if (!hydrated) {
    return (
      <SafeAreaView style={[styles.screen, { backgroundColor: theme.colors.background }]}>
        <ActivityIndicator color={theme.colors.blue} />
      </SafeAreaView>
    );
  }

  if (authenticated && !profile?.onboarding_completed) return <Redirect href={onboardingRoute(profile) as any} />;

  const expired = preview?.invite_status === "expired";
  const invalid = !loadingPreview && !preview;
  const unavailable = invalid || Boolean(preview && (preview.invite_status !== "active" || preview.room_status !== "live"));

  const openInBantApp = async () => {
    if (!inviteToken) return;

    const deepLink = `bant://invite/${inviteToken}`;

    if (Platform.OS === "web" && typeof window !== "undefined") {
      const fallback = `${window.location.origin}/invite/${inviteToken}`;
      const ua = window.navigator.userAgent || "";
      const isAndroid = /Android/i.test(ua);

      if (isAndroid) {
        const intentUrl =
          `intent://invite/${inviteToken}#Intent;` +
          `scheme=bant;` +
          `package=com.bant.app.bant_mobile;` +
          `S.browser_fallback_url=${encodeURIComponent(fallback)};` +
          `end`;
        window.location.href = intentUrl;
        return;
      }

      window.location.href = deepLink;
      return;
    }

    await Linking.openURL(deepLink);
  };

  useEffect(() => {
    if (
      Platform.OS !== "web" ||
      !inviteToken ||
      appOpenAttempted ||
      typeof window === "undefined"
    ) {
      return;
    }

    const ua = window.navigator.userAgent || "";
    if (!/Android/i.test(ua)) return;

    setAppOpenAttempted(true);

    const timer = window.setTimeout(() => {
      void openInBantApp();
    }, 450);

    return () => window.clearTimeout(timer);
  }, [appOpenAttempted, inviteToken]);

  const continueToAuth = async (mode: "login" | "signup") => {
    if (!inviteToken) return;
    await AsyncStorage.setItem(PENDING_INVITE_TOKEN_KEY, inviteToken);
    router.push({ pathname: "/auth/sign-in", params: { mode } } as any);
  };

  return (
    <SafeAreaView style={[styles.screen, { backgroundColor: theme.colors.background }]}>
      <View style={[styles.card, { backgroundColor: theme.colors.surface, borderColor: theme.colors.border }]}>
        {loadingPreview || joining ? <ActivityIndicator color={theme.colors.blue} /> : null}
        <Text style={[styles.eyebrow, { color: theme.colors.blue }]}>BANT ROOM INVITE</Text>
        <Text style={[styles.title, { color: theme.colors.text }]}>
          {preview?.room_title ?? (loadingPreview ? "Opening room..." : "Room invite")}
        </Text>
        {preview?.room_category ? (
          <Text style={[styles.meta, { color: theme.colors.secondary }]}>
            {preview.room_category} · {preview.room_privacy === "private" ? "Private room" : "Public room"}
          </Text>
        ) : null}
        <Text style={[styles.body, { color: theme.colors.secondary }]}>
          {preview?.room_description || "Join the conversation on BANT."}
        </Text>

        {Platform.OS === "web" && !unavailable ? (
          <View style={styles.appActions}>
            <BantButton title="Open in BANT app" onPress={() => void openInBantApp()} />
            <Text style={[styles.appHint, { color: theme.colors.secondary }]}>
              If BANT is installed, this opens the app and takes you straight to the invited room.
            </Text>
          </View>
        ) : null}

        {unavailable ? (
          <Text style={[styles.status, { color: theme.colors.danger }]}>
            {invalid ? "This invite is invalid." : expired ? "This invite has expired." : "This invite is no longer available."}
          </Text>
        ) : authenticated ? (
          <Text style={[styles.status, { color: theme.colors.mint }]}>
            {joining ? "Joining you to the room..." : "Your BANT session is active. Joining room..."}
          </Text>
        ) : (
          <View style={styles.actions}>
            <Text style={[styles.status, { color: theme.colors.secondary }]}>
              Already use BANT? Log in and you will return straight to this room. New here? Create an account and this invite will stay waiting for you.
            </Text>
            <BantButton title="Log in and join room" onPress={() => void continueToAuth("login")} />
            <BantButton title="Create account and join" variant="ghost" onPress={() => void continueToAuth("signup")} />
          </View>
        )}

        {joinAttempted && !joining && authenticated ? (
          <BantButton title="Back to rooms" variant="ghost" onPress={() => router.replace("/(tabs)/rooms")} />
        ) : null}
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, alignItems: "center", justifyContent: "center", padding: 20 },
  card: { width: "100%", maxWidth: 480, gap: 14, alignItems: "center", borderWidth: 1, borderRadius: 24, padding: 24 },
  eyebrow: { fontFamily: "PlusJakartaSans_800ExtraBold", fontSize: 11, letterSpacing: 1.2 },
  title: { fontFamily: "PlusJakartaSans_800ExtraBold", fontSize: 28, lineHeight: 34, textAlign: "center" },
  meta: { fontFamily: "PlusJakartaSans_700Bold", fontSize: 12, textAlign: "center" },
  body: { fontFamily: "PlusJakartaSans_500Medium", fontSize: 14, lineHeight: 21, textAlign: "center" },
  status: { fontFamily: "PlusJakartaSans_600SemiBold", fontSize: 13, lineHeight: 19, textAlign: "center" },
  actions: { width: "100%", gap: 10, marginTop: 4 },
  appActions: { width: "100%", gap: 8, marginTop: 4 },
  appHint: { fontFamily: "PlusJakartaSans_500Medium", fontSize: 12, lineHeight: 17, textAlign: "center" }
});
