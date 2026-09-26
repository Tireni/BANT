import { StyleSheet, Text, View } from "react-native";
import { BantButton } from "./BantButton";
import { useTheme } from "@/hooks/useTheme";

export function EmptyState({ title, body, action, onPress }: { title: string; body: string; action?: string; onPress?: () => void }) {
  const theme = useTheme();
  return (
    <View style={[styles.wrap, { backgroundColor: theme.colors.surface, borderColor: theme.colors.border }]}>
      <Text style={[styles.title, { color: theme.colors.text }]}>{title}</Text>
      <Text style={[styles.body, { color: theme.colors.secondary }]}>{body}</Text>
      {action && onPress ? <BantButton title={action} onPress={onPress} style={{ marginTop: 16 }} /> : null}
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: { borderWidth: 1, borderRadius: 22, padding: 22, alignItems: "center" },
  title: { fontFamily: "PlusJakartaSans_800ExtraBold", fontSize: 18 },
  body: { textAlign: "center", fontFamily: "PlusJakartaSans_500Medium", fontSize: 14, lineHeight: 21, marginTop: 8 }
});
