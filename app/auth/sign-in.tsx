import { useLocalSearchParams } from "expo-router";
import { KeyboardAvoidingView, Platform, StyleSheet, Text, View } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { BantButton } from "@/components/common/BantButton";
import { useTheme } from "@/hooks/useTheme";
import { useBantStore } from "@/store/useBantStore";

export default function SignIn() {
  const theme = useTheme();
  useLocalSearchParams<{ mode?: string }>();
  const signInWithGoogle = useBantStore((state) => state.signInWithGoogle);
  const signInWithApple = useBantStore((state) => state.signInWithApple);
  const authLoading = useBantStore((state) => state.authLoading);
  const continueWith = async (provider: "google" | "apple") => {
    if (provider === "google") {
      await signInWithGoogle();
    } else {
      await signInWithApple();
    }
  };
  return (
    <SafeAreaView style={[styles.screen, { backgroundColor: theme.colors.background }]}>
      <KeyboardAvoidingView behavior={Platform.OS === "ios" ? "padding" : undefined} style={styles.wrap}>
        <View>
          <Text style={[styles.title, { color: theme.colors.text }]}>Welcome to BANT</Text>
          <Text style={[styles.body, { color: theme.colors.secondary }]}>Find your people. Join the conversation.</Text>
        </View>
        <View style={[styles.providerCard, { backgroundColor: theme.colors.surface, borderColor: theme.colors.border }]}>
          <Text style={[styles.providerTitle, { color: theme.colors.text }]}>Continue with</Text>
          <BantButton title="Continue with Google" loading={authLoading} onPress={() => void continueWith("google")} />
          <BantButton title="Continue with Apple" variant="ghost" loading={authLoading} onPress={() => void continueWith("apple")} />
          <Text style={[styles.providerNote, { color: theme.colors.secondary }]}>
            Email and password sign-up is temporarily unavailable.
          </Text>
        </View>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1 },
  wrap: { flex: 1, paddingHorizontal: 20, paddingVertical: 24, justifyContent: "center", gap: 14, width: "100%", maxWidth: 480, alignSelf: "center" },
  title: { fontFamily: "PlusJakartaSans_800ExtraBold", fontSize: 30, lineHeight: 36 },
  body: { fontFamily: "PlusJakartaSans_500Medium", fontSize: 15, lineHeight: 22, marginTop: 8 },
  providerCard: { borderWidth: 1, borderRadius: 20, padding: 16, gap: 12 },
  providerTitle: { fontFamily: "PlusJakartaSans_800ExtraBold", fontSize: 16, textAlign: "center" },
  providerNote: { fontFamily: "PlusJakartaSans_500Medium", fontSize: 12, lineHeight: 18, textAlign: "center", marginTop: 2 }
});
