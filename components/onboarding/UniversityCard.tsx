import { Pressable, StyleSheet, Text, View } from "react-native";
import { CheckCircle2, GraduationCap } from "lucide-react-native";
import { useTheme } from "@/hooks/useTheme";
import { University } from "@/types/university";

export function UniversityCard({ university, selected, onPress }: { university: University; selected: boolean; onPress: () => void }) {
  const theme = useTheme();
  return (
    <Pressable onPress={onPress} style={[styles.card, { backgroundColor: selected ? theme.colors.soft : theme.colors.surface, borderColor: selected ? theme.colors.blue : theme.colors.border }]}>
      <GraduationCap size={22} color={selected ? theme.colors.blue : theme.colors.secondary} />
      <View style={{ flex: 1 }}>
        <Text style={[styles.name, { color: theme.colors.text }]}>{university.name}</Text>
        <Text style={[styles.location, { color: theme.colors.secondary }]}>{university.location}</Text>
      </View>
      {selected ? <CheckCircle2 size={22} color={theme.colors.blue} /> : null}
    </Pressable>
  );
}

const styles = StyleSheet.create({
  card: { borderWidth: 1.5, borderRadius: 18, padding: 14, flexDirection: "row", alignItems: "center", gap: 12 },
  name: { fontFamily: "PlusJakartaSans_800ExtraBold", fontSize: 14 },
  location: { fontFamily: "PlusJakartaSans_500Medium", fontSize: 12, marginTop: 2 }
});
