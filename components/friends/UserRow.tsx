import { Pressable, StyleSheet, Text, View } from "react-native";
import { BantAvatar } from "@/components/common/BantAvatar";
import { useTheme } from "@/hooks/useTheme";
import { User } from "@/types/user";

export function UserRow({ user, action, onPress }: { user: User; action?: string; onPress?: () => void }) {
  const theme = useTheme();
  return (
    <View style={[styles.row, { borderColor: theme.colors.border }]}>
      <BantAvatar user={user} />
      <View style={styles.mid}>
        <Text style={[styles.name, { color: theme.colors.text }]}>{user.name}</Text>
        <Text style={[styles.meta, { color: theme.colors.secondary }]}>@{user.username}</Text>
      </View>
      {action ? (
        <Pressable onPress={onPress} style={[styles.action, { backgroundColor: theme.colors.soft }]}>
          <Text style={[styles.actionText, { color: theme.colors.blue }]}>{action}</Text>
        </Pressable>
      ) : null}
    </View>
  );
}

const styles = StyleSheet.create({
  row: { flexDirection: "row", alignItems: "center", gap: 12, paddingVertical: 14, borderBottomWidth: 1 },
  mid: { flex: 1 },
  name: { fontFamily: "PlusJakartaSans_800ExtraBold", fontSize: 15 },
  meta: { fontFamily: "PlusJakartaSans_500Medium", fontSize: 12, marginTop: 2 },
  action: { minHeight: 38, justifyContent: "center", borderRadius: 14, paddingHorizontal: 12 },
  actionText: { fontFamily: "PlusJakartaSans_800ExtraBold", fontSize: 12 }
});
