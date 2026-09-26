import { ReactNode } from "react";
import { StyleSheet, Text, View } from "react-native";
import { useTheme } from "@/hooks/useTheme";

const labels = ["Profile", "Interests", "Complete"];

export function OnboardingStep({ step, total = 2, label, title, subtitle, children }: { step: number; total?: number; label?: string; title: string; subtitle: string; children: ReactNode }) {
  const theme = useTheme();
  const resolvedLabel = label ?? labels[Math.min(step - 1, labels.length - 1)];

  return (
    <View style={styles.wrap}>
      <View style={styles.progressTop}>
        <Text style={[styles.stepText, { color: theme.colors.blue }]}>{`${step} of ${total}`}</Text>
        <Text style={[styles.stepLabel, { color: theme.colors.muted }]}>{resolvedLabel}</Text>
      </View>
      <View style={styles.progressTrack}>
        {Array.from({ length: total }, (_, index) => index + 1).map((item) => (
          <View key={item} style={[styles.progressDot, { backgroundColor: item <= step ? theme.colors.blue : theme.colors.border }]} />
        ))}
      </View>
      <View style={styles.header}>
        <Text style={[styles.title, { color: theme.colors.text }]}>{title}</Text>
        <Text style={[styles.subtitle, { color: theme.colors.secondary }]}>{subtitle}</Text>
      </View>
      {children}
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: { gap: 18 },
  progressTop: { flexDirection: "row", justifyContent: "space-between", alignItems: "center" },
  stepText: { fontFamily: "PlusJakartaSans_800ExtraBold", fontSize: 12, textTransform: "uppercase", letterSpacing: 1.1 },
  stepLabel: { fontFamily: "PlusJakartaSans_800ExtraBold", fontSize: 12, textTransform: "uppercase", letterSpacing: 1.1 },
  progressTrack: { flexDirection: "row", gap: 8 },
  progressDot: { flex: 1, height: 5, borderRadius: 999 },
  header: { gap: 8 },
  title: { fontFamily: "PlusJakartaSans_800ExtraBold", fontSize: 28, lineHeight: 34, maxWidth: 520 },
  subtitle: { fontFamily: "PlusJakartaSans_500Medium", fontSize: 15, lineHeight: 22, maxWidth: 520 }
});
