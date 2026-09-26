import { Pressable, StyleSheet, Text } from "react-native";
import { useTheme } from "@/hooks/useTheme";

export function CategoryChip({ label, selected, onPress }: { label: string; selected: boolean; onPress: () => void }) {
  const theme = useTheme();
  return (
    <Pressable onPress={onPress} style={[styles.chip, { backgroundColor: selected ? theme.colors.blue : theme.colors.surface, borderColor: selected ? theme.colors.blue : theme.colors.border }]}>
      <Text style={[styles.text, { color: selected ? "#fff" : theme.colors.secondary }]}>{label}</Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  chip: { borderWidth: 1, borderRadius: 999, paddingHorizontal: 14, minHeight: 38, justifyContent: "center" },
  text: { fontFamily: "PlusJakartaSans_800ExtraBold", fontSize: 13 }
});
