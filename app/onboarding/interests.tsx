import { Redirect, router } from "expo-router";
import { Check } from "lucide-react-native";
import { useEffect, useState } from "react";
import { Pressable, ScrollView, StyleSheet, Text, View } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { BantButton } from "@/components/common/BantButton";
import { OnboardingStep } from "@/components/onboarding/OnboardingStep";
import { defaultInterests } from "@/data/interests";
import { useTheme } from "@/hooks/useTheme";
import { hasSupabaseConfig, supabase } from "@/lib/supabase";
import { useBantStore } from "@/store/useBantStore";

export default function InterestsStep() {
  const theme = useTheme();
  const authenticated = useBantStore((state) => state.authenticated);
  const profile = useBantStore((state) => state.profile);
  const authLoading = useBantStore((state) => state.authLoading);
  const saveOnboardingInterests = useBantStore((state) => state.saveOnboardingInterests);
  const setToast = useBantStore((state) => state.setToast);
  const [selected, setSelected] = useState<string[]>([]);

  useEffect(() => {
    let mounted = true;
    async function loadSavedInterests() {
      if (!profile?.id || !hasSupabaseConfig) return;
      const { data } = await supabase
        .from("user_interests")
        .select("interests(slug)")
        .eq("user_id", profile.id);
      if (!mounted) return;
      const slugs = (data ?? [])
        .map((row: any) => Array.isArray(row.interests) ? row.interests[0]?.slug : row.interests?.slug)
        .filter(Boolean);
      setSelected(slugs);
    }
    void loadSavedInterests();
    return () => {
      mounted = false;
    };
  }, [profile?.id]);

  if (!authenticated) return <Redirect href="/auth/welcome" />;

  const toggle = (slug: string) => {
    setSelected((items) => items.includes(slug) ? items.filter((item) => item !== slug) : [...items, slug]);
  };

  const save = async () => {
    if (selected.length < 3) {
      setToast("Choose at least 3 interests");
      return;
    }
    const ok = await saveOnboardingInterests(selected);
    if (ok) router.push("/onboarding/complete");
  };

  return (
    <SafeAreaView style={[styles.screen, { backgroundColor: theme.colors.background }]}>
      <ScrollView contentContainerStyle={styles.content}>
        <OnboardingStep step={2} total={2} title="PICK YOUR INTERESTS" subtitle="Choose at least 3 so your feed feels like you.">
          <View style={styles.grid}>
            {defaultInterests.map((interest) => {
              const active = selected.includes(interest.slug);
              return (
                <Pressable
                  key={interest.slug}
                  accessibilityRole="button"
                  accessibilityState={{ selected: active }}
                  onPress={() => toggle(interest.slug)}
                  style={[styles.interest, { backgroundColor: active ? theme.colors.blue : theme.colors.surface, borderColor: active ? theme.colors.blue : theme.colors.border }]}
                >
                  <Text style={[styles.interestText, { color: active ? "#fff" : theme.colors.text }]}>{interest.name}</Text>
                  {active ? <Check color="#fff" size={18} /> : null}
                </Pressable>
              );
            })}
          </View>
          <Text style={[styles.count, { color: selected.length >= 3 ? theme.colors.mint : theme.colors.secondary }]}>
            {selected.length}/3 selected
          </Text>
        </OnboardingStep>
      </ScrollView>
      <View style={styles.footer}>
        <BantButton title="Back" variant="ghost" onPress={() => router.push("/onboarding/profile")} style={styles.secondaryButton} />
        <BantButton title="Continue" onPress={save} loading={authLoading} style={styles.primaryButton} />
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1 },
  content: { padding: 20, paddingBottom: 24, width: "100%", maxWidth: 560, alignSelf: "center" },
  grid: { flexDirection: "row", flexWrap: "wrap", gap: 10 },
  interest: { minHeight: 52, borderWidth: 1, borderRadius: 16, paddingHorizontal: 14, flexDirection: "row", alignItems: "center", gap: 8 },
  interestText: { fontFamily: "PlusJakartaSans_800ExtraBold", fontSize: 14 },
  count: { fontFamily: "PlusJakartaSans_800ExtraBold", fontSize: 13 },
  footer: { width: "100%", maxWidth: 560, alignSelf: "center", paddingHorizontal: 20, paddingBottom: 24, paddingTop: 12, flexDirection: "row", gap: 10 },
  primaryButton: { flex: 1 },
  secondaryButton: { flex: 1 }
});
