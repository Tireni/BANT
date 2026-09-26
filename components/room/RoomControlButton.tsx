import { ReactNode } from "react";
import { Pressable, StyleSheet, Text } from "react-native";
import { useTheme } from "@/hooks/useTheme";

export function RoomControlButton({ label, icon, onPress, danger, active }: { label: string; icon: ReactNode; onPress: () => void; danger?: boolean; active?: boolean }) {
  const theme = useTheme();
  const color = danger ? theme.colors.danger : active ? theme.colors.blue : theme.colors.text;
  return (
    <Pressable onPress={onPress} style={[styles.button, { backgroundColor: active ? theme.colors.mintSoft : theme.colors.soft }]}>
      {icon}
      <Text style={[styles.label, { color }]}>{label}</Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  button: { minWidth: 58, minHeight: 54, borderRadius: 16, alignItems: "center", justifyContent: "center", gap: 4, paddingHorizontal: 8 },
  label: { fontFamily: "PlusJakartaSans_700Bold", fontSize: 10 }
});
