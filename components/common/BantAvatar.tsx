import { Image, StyleSheet, Text, View } from "react-native";
import { User } from "@/types/user";

export function BantAvatar({ user, size = 42 }: { user: User; size?: number }) {
  const initials = user.name.split(" ").map((part) => part[0]).slice(0, 2).join("");

  if (user.avatar_url) {
    return (
      <Image
        source={{ uri: user.avatar_url }}
        style={[styles.avatar, { width: size, height: size, borderRadius: size / 2, backgroundColor: user.avatarColor }]}
      />
    );
  }

  return (
    <View style={[styles.avatar, { width: size, height: size, borderRadius: size / 2, backgroundColor: user.avatarColor }]}>
      <Text style={[styles.text, { fontSize: Math.max(13, size * 0.34) }]}>{initials}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  avatar: { alignItems: "center", justifyContent: "center" },
  text: { color: "#fff", fontFamily: "PlusJakartaSans_800ExtraBold" }
});
