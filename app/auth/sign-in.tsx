import AsyncStorage from "@react-native-async-storage/async-storage";
import { router } from "expo-router";
import { Mail } from "lucide-react-native";
import { useState } from "react";
import { KeyboardAvoidingView, Platform, Pressable, StyleSheet, Text, View } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { BantButton } from "@/components/common/BantButton";
import { BantInput } from "@/components/common/BantInput";
import { useTheme } from "@/hooks/useTheme";
import { onboardingRoute } from "@/lib/onboarding";
import { PENDING_INVITE_TOKEN_KEY } from "@/lib/roomInvites";
import { useBantStore } from "@/store/useBantStore";

export default function SignIn() {
  const theme = useTheme();
  const signUp = useBantStore((state) => state.signUp);
  const signIn = useBantStore((state) => state.signIn);
  const signInWithGoogle = useBantStore((state) => state.signInWithGoogle);
  const authLoading = useBantStore((state) => state.authLoading);
  const profile = useBantStore((state) => state.profile);
  const setToast = useBantStore((state) => state.setToast);
  const [mode, setMode] = useState<"signup" | "login">("signup");
  const [displayName, setDisplayName] = useState("");
  const [username, setUsername] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const enter = async () => {
    if (!email.trim() || !password.trim()) {
      setToast(mode === "login" ? "Enter your username or email and password" : "Enter email and password");
      return;
    }
    if (mode === "signup" && (!displayName.trim() || !username.trim())) {
      setToast("Enter name and username");
      return;
    }
    const ok = mode === "signup"
      ? await signUp({ email: email.trim(), password, displayName: displayName.trim(), username: username.trim() })
      : await signIn({ email: email.trim(), password });
    if (ok) {
      const pendingInvite = await AsyncStorage.getItem(PENDING_INVITE_TOKEN_KEY);
      const nextProfile = useBantStore.getState().profile ?? profile;
      if (pendingInvite && nextProfile?.onboarding_completed) {
        router.replace(`/invite/${pendingInvite}`);
        return;
      }
      router.replace(onboardingRoute(nextProfile) as any);
    }
  };
  return (
    <SafeAreaView style={[styles.screen, { backgroundColor: theme.colors.background }]}>
      <KeyboardAvoidingView behavior={Platform.OS === "ios" ? "padding" : undefined} style={styles.wrap}>
        <View>
          <Text style={[styles.title, { color: theme.colors.text }]}>Welcome to BANT</Text>
          <Text style={[styles.body, { color: theme.colors.secondary }]}>Your campus conversations start here.</Text>
        </View>
        <View style={[styles.switcher, { backgroundColor: theme.colors.soft }]}>
          {(["signup", "login"] as const).map((item) => (
            <Pressable key={item} onPress={() => setMode(item)} style={[styles.switchItem, mode === item && { backgroundColor: theme.colors.blue }]}>
              <Text style={[styles.switchText, { color: mode === item ? "#fff" : theme.colors.secondary }]}>{item === "signup" ? "Create account" : "Log in"}</Text>
            </Pressable>
          ))}
        </View>
        {mode === "signup" ? (
          <>
            <BantInput placeholder="Display name" value={displayName} onChangeText={setDisplayName} />
            <BantInput placeholder="Username" autoCapitalize="none" value={username} onChangeText={setUsername} />
          </>
        ) : null}
        <BantInput placeholder={mode === "login" ? "Username or email" : "Email"} autoCapitalize="none" keyboardType={mode === "login" ? "default" : "email-address"} value={email} onChangeText={setEmail} />
        <BantInput placeholder="Password" secureTextEntry value={password} onChangeText={setPassword} />
        <BantButton title={mode === "signup" ? "Create account" : "Log in"} icon={<Mail size={20} color="#fff" />} loading={authLoading} onPress={enter} />
        <BantButton title="Continue with Google" loading={authLoading} onPress={signInWithGoogle} />
        <Text style={[styles.link, { color: theme.colors.blue }]}></Text>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1 },
  wrap: { flex: 1, paddingHorizontal: 20, paddingVertical: 24, justifyContent: "center", gap: 14, width: "100%", maxWidth: 480, alignSelf: "center" },
  title: { fontFamily: "PlusJakartaSans_800ExtraBold", fontSize: 30, lineHeight: 36 },
  body: { fontFamily: "PlusJakartaSans_500Medium", fontSize: 15, lineHeight: 22, marginTop: 8 },
  switcher: { flexDirection: "row", borderRadius: 16, padding: 4, gap: 4 },
  switchItem: { flex: 1, minHeight: 44, borderRadius: 12, alignItems: "center", justifyContent: "center" },
  switchText: { fontFamily: "PlusJakartaSans_800ExtraBold", fontSize: 13 },
  link: { textAlign: "center", fontFamily: "PlusJakartaSans_800ExtraBold", fontSize: 14, marginTop: 4 }
});
