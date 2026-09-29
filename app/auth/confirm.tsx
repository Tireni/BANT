import { router, useLocalSearchParams } from "expo-router";
import { useEffect, useState } from "react";
import { ActivityIndicator, StyleSheet, Text, View } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { BantButton } from "@/components/common/BantButton";
import { useTheme } from "@/hooks/useTheme";
import { onboardingRoute } from "@/lib/onboarding";
import { supabase } from "@/lib/supabase";
import { useBantStore } from "@/store/useBantStore";

const allowedTypes = new Set(["signup", "invite", "magiclink", "recovery", "email_change", "email"]);

export default function ConfirmEmail() {
  const theme = useTheme();
  const { token_hash, type } = useLocalSearchParams<{ token_hash?: string; type?: string }>();
  const hydrate = useBantStore((state) => state.hydrate);
  const [status, setStatus] = useState<"checking" | "success" | "error">("checking");

  useEffect(() => {
    const tokenHash = Array.isArray(token_hash) ? token_hash[0] : token_hash;
    const otpType = Array.isArray(type) ? type[0] : type;
    if (!tokenHash || !otpType || !allowedTypes.has(otpType)) {
      setStatus("error");
      return;
    }

    void supabase.auth.verifyOtp({
      token_hash: tokenHash,
      type: otpType as any
    }).then(async ({ error }) => {
      if (error) {
        setStatus("error");
        return;
      }
      await hydrate();
      const profile = useBantStore.getState().profile;
      setStatus("success");
      setTimeout(() => router.replace(onboardingRoute(profile) as any), 250);
    });
  }, [hydrate, token_hash, type]);

  return (
    <SafeAreaView style={[styles.screen, { backgroundColor: theme.colors.background }]}>
      <View style={[styles.card, { backgroundColor: theme.colors.surface, borderColor: theme.colors.border }]}>
        {status === "checking" ? <ActivityIndicator color={theme.colors.blue} /> : null}
        <Text style={[styles.title, { color: theme.colors.text }]}>
          {status === "checking" ? "Confirming your email..." : status === "success" ? "Email confirmed" : "Confirmation link unavailable"}
        </Text>
        <Text style={[styles.body, { color: theme.colors.secondary }]}>
          {status === "checking"
            ? "BANT is verifying your email securely."
            : status === "success"
              ? "Your BANT account is ready."
              : "This confirmation link is invalid or has expired."}
        </Text>
        {status === "error" ? <BantButton title="Go to login" onPress={() => router.replace("/auth/sign-in?mode=login")} /> : null}
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, alignItems: "center", justifyContent: "center", padding: 20 },
  card: { width: "100%", maxWidth: 440, borderWidth: 1, borderRadius: 24, padding: 24, gap: 14, alignItems: "center" },
  title: { fontFamily: "PlusJakartaSans_800ExtraBold", fontSize: 24, textAlign: "center" },
  body: { fontFamily: "PlusJakartaSans_500Medium", fontSize: 14, lineHeight: 21, textAlign: "center" }
});
