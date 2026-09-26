import { Pressable, StyleSheet, Text, View } from "react-native";
import { Globe2, Lock } from "lucide-react-native";
import { useTheme } from "@/hooks/useTheme";
import { RoomPrivacy } from "@/types/room";

export function PrivacySelector({ value, onChange }: { value: RoomPrivacy; onChange: (value: RoomPrivacy) => void }) {
  const theme = useTheme();
  return (
    <View style={styles.grid}>
      {(["public", "private"] as const).map((item) => {
        const selected = value === item;
        const Icon = item === "public" ? Globe2 : Lock;
        return (
          <Pressable key={item} onPress={() => onChange(item)} style={[styles.card, { backgroundColor: selected ? theme.colors.mintSoft : theme.colors.surface, borderColor: selected ? theme.colors.mint : theme.colors.border }]}>
            <Icon size={22} color={selected ? theme.colors.blue : theme.colors.secondary} />
            <Text style={[styles.title, { color: theme.colors.text }]}>{item === "public" ? "Public" : "Private"}</Text>
            <Text style={[styles.body, { color: theme.colors.secondary }]}>{item === "public" ? "Anyone can discover and join." : "Only people with an invitation can join."}</Text>
          </Pressable>
        );
      })}
    </View>
  );
}

const styles = StyleSheet.create({
  grid: { flexDirection: "row", gap: 12 },
  card: { flex: 1, borderWidth: 1.5, borderRadius: 18, padding: 14, minHeight: 130, gap: 8 },
  title: { fontFamily: "PlusJakartaSans_800ExtraBold", fontSize: 15 },
  body: { fontFamily: "PlusJakartaSans_500Medium", fontSize: 12, lineHeight: 17 }
});
