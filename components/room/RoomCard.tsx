import { Pressable, StyleSheet, Text, View } from "react-native";
import { Lock, Mic2, Users } from "lucide-react-native";
import { BantAvatar } from "@/components/common/BantAvatar";
import { useTheme } from "@/hooks/useTheme";
import { Room } from "@/types/room";
import { VoiceWaveform } from "./VoiceWaveform";

export function RoomCard({ room, onPress, rejoin = false }: { room: Room; onPress: () => void; rejoin?: boolean }) {
  const theme = useTheme();
  const speakers = (room.speakers ?? []).slice(0, 3);
  return (
    <Pressable onPress={onPress} style={({ pressed }) => [styles.card, { backgroundColor: theme.colors.surface, borderColor: theme.colors.border }, pressed && { transform: [{ scale: 0.985 }] }]}>
      <View style={styles.top}>
        <Text style={[styles.badge, { color: theme.colors.blue, backgroundColor: theme.colors.soft }]}>{room.category}</Text>
        {room.privacy === "private" ? <Lock size={16} color={theme.colors.secondary} /> : null}
      </View>
      <Text style={[styles.title, { color: theme.colors.text }]}>{room.title}</Text>
      <Text style={[styles.desc, { color: theme.colors.secondary }]} numberOfLines={2}>{room.description}</Text>
      <View style={styles.footer}>
        <View style={styles.stack}>
          {speakers.map((user, index) => <View key={user.id} style={{ marginLeft: index ? -12 : 0 }}><BantAvatar user={user} size={34} /></View>)}
        </View>
        <View style={styles.meta}><Mic2 size={15} color={theme.colors.mint} /><Text style={[styles.metaText, { color: theme.colors.secondary }]}>{room.speakerCount ?? room.speakerIds?.length ?? 0} talking</Text></View>
        <View style={styles.meta}><Users size={15} color={theme.colors.blue} /><Text style={[styles.metaText, { color: theme.colors.secondary }]}>{room.participantCount ?? 0} here</Text></View>
        <View style={styles.join}><VoiceWaveform /><Text style={[styles.joinText, { color: theme.colors.blue }]}>{rejoin ? "Rejoin" : "Open"}</Text></View>
      </View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  card: { borderWidth: 1, borderRadius: 22, padding: 16, gap: 10, minWidth: 250 },
  top: { flexDirection: "row", justifyContent: "space-between", alignItems: "center" },
  badge: { overflow: "hidden", borderRadius: 99, paddingHorizontal: 10, paddingVertical: 5, fontFamily: "PlusJakartaSans_800ExtraBold", fontSize: 11 },
  title: { fontFamily: "PlusJakartaSans_800ExtraBold", fontSize: 18 },
  desc: { fontFamily: "PlusJakartaSans_500Medium", fontSize: 13, lineHeight: 18 },
  footer: { flexDirection: "row", alignItems: "center", gap: 10, flexWrap: "wrap" },
  stack: { flexDirection: "row", alignItems: "center" },
  meta: { flexDirection: "row", alignItems: "center", gap: 4 },
  metaText: { fontFamily: "PlusJakartaSans_600SemiBold", fontSize: 12 },
  join: { marginLeft: "auto", flexDirection: "row", alignItems: "center", gap: 8 },
  joinText: { fontFamily: "PlusJakartaSans_800ExtraBold", fontSize: 13 }
});
