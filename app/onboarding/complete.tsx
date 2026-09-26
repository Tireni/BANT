import { Redirect, router } from "expo-router";
import { CheckCircle2 } from "lucide-react-native";
import { ScrollView, StyleSheet, Text, View } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { BantButton } from "@/components/common/BantButton";
import { OnboardingStep } from "@/components/onboarding/OnboardingStep";
import { useTheme } from "@/hooks/useTheme";
import { useBantStore } from "@/store/useBantStore";

export default function CompleteStep() {
  const theme = useTheme();
  const authenticated = useBantStore((state) => state.authenticated);
  const profile = useBantStore((state) => state.profile);
  const authLoading = useBantStore((state) => state.authLoading);
  const finishOnboarding = useBantStore((state) => state.finishOnboarding);

  if (!authenticated) return <Redirect href="/auth/welcome" />;

  const finish = async () => {
    const ok = await finishOnboarding();
    if (ok) router.replace("/(tabs)/home");
  };

  return (
    <SafeAreaView style={[styles.screen, { backgroundColor: theme.colors.background }]}>
      <ScrollView contentContainerStyle={styles.content}>
        <OnboardingStep step={2} total={2} label="Complete" title="COMPLETE SETUP" subtitle="Review the basics, then enter BANT.">
          <View style={[styles.card, { backgroundColor: theme.colors.surface, borderColor: theme.colors.border }]}>
            <CheckCircle2 color={theme.colors.mint} size={42} />
            <Text style={[styles.title, { color: theme.colors.text }]}>You're ready.</Text>
            <Text style={[styles.copy, { color: theme.colors.secondary }]}>Your profile, status, and interests are saved. You can edit them from your profile later.</Text>
          </View>
          <View style={styles.list}>
            <Summary label="Profile" value={`@${profile?.username ?? "bant"}`} />
            <Summary label="Interests" value="Saved" />
            <Summary label="Status" value="Ready to BANT" />
          </View>
        </OnboardingStep>
      </ScrollView>
      <View style={styles.footer}>
        <BantButton title="Back" variant="ghost" onPress={() => router.push("/onboarding/interests")} style={styles.secondaryButton} />
        <BantButton title="Enter BANT" onPress={finish} loading={authLoading} style={styles.primaryButton} />
      </View>
    </SafeAreaView>
  );
}

function Summary({ label, value }: { label: string; value: string }) {
  const theme = useTheme();
  return (
    <View style={[styles.summary, { backgroundColor: theme.colors.surface, borderColor: theme.colors.border }]}>
      <Text style={[styles.summaryLabel, { color: theme.colors.secondary }]}>{label}</Text>
      <Text style={[styles.summaryValue, { color: theme.colors.text }]}>{value}</Text>
    </View>
  );
}

function occupationLabel(category?: string | null, custom?: string | null) {
  if (category === "job_seeker") return "Job Seeker";
  if (category === "non_student") return "Non-student";
  if (!category) return "Non-student";
  if (category === "other" && custom) return custom;
  return category.replace(/_/g, " ").replace(/\b\w/g, (letter) => letter.toUpperCase());
}

const styles = StyleSheet.create({
  screen: { flex: 1 },
  content: { padding: 20, paddingBottom: 24, width: "100%", maxWidth: 560, alignSelf: "center" },
  card: { borderWidth: 1, borderRadius: 24, padding: 22, alignItems: "center", gap: 10 },
  title: { fontFamily: "PlusJakartaSans_800ExtraBold", fontSize: 24 },
  copy: { fontFamily: "PlusJakartaSans_500Medium", fontSize: 14, lineHeight: 21, textAlign: "center" },
  list: { gap: 10 },
  summary: { borderWidth: 1, borderRadius: 18, padding: 16 },
  summaryLabel: { fontFamily: "PlusJakartaSans_700Bold", fontSize: 11, letterSpacing: 1, textTransform: "uppercase" },
  summaryValue: { fontFamily: "PlusJakartaSans_800ExtraBold", fontSize: 15, marginTop: 4 },
  footer: { width: "100%", maxWidth: 560, alignSelf: "center", paddingHorizontal: 20, paddingBottom: 24, paddingTop: 12, flexDirection: "row", gap: 10 },
  primaryButton: { flex: 1 },
  secondaryButton: { flex: 1 }
});
