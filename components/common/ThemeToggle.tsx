import { Pressable, StyleSheet, Text, View } from "react-native";
import { useTheme } from "@/hooks/useTheme";
import { useBantStore } from "@/store/useBantStore";

const options = ["system", "light", "dark"] as const;

export function ThemeToggle() {
  const theme = useTheme();
  const selected = useBantStore((state) => state.themePreference);
  const setTheme = useBantStore((state) => state.setTheme);
  return (
    <View style={[styles.wrap, { backgroundColor: theme.colors.soft }]}>
      {options.map((item) => (
        <Pressable key={item} onPress={() => setTheme(item)} style={[styles.item, selected === item && { backgroundColor: theme.colors.blue }]}>
          <Text style={[styles.text, { color: selected === item ? "#fff" : theme.colors.secondary }]}>{item}</Text>
        </Pressable>
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: { flexDirection: "row", borderRadius: 16, padding: 4, gap: 4 },
  item: { flex: 1, minHeight: 42, alignItems: "center", justifyContent: "center", borderRadius: 12 },
  text: { textTransform: "capitalize", fontFamily: "PlusJakartaSans_700Bold", fontSize: 13 }
});
