import { router } from "expo-router";
import { Bell } from "lucide-react-native";
import { ReactNode, useEffect } from "react";
import { Image, Pressable, ScrollView, StyleSheet, Text, View } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { BantAvatar } from "@/components/common/BantAvatar";
import { BantButton } from "@/components/common/BantButton";
import { EmptyState } from "@/components/common/EmptyState";
import { RoomCard } from "@/components/room/RoomCard";
import { useTheme } from "@/hooks/useTheme";
import { useBantStore } from "@/store/useBantStore";

const mascot = require("../../assets/brand/bant-mascot.png");

export default function Home() {
  const theme = useTheme();
  const rooms = useBantStore((state) => state.rooms);
  const loadRooms = useBantStore((state) => state.loadRooms);
  const user = useBantStore((state) => state.currentUser);
  const notifications = useBantStore((state) => state.notifications);
  useEffect(() => {
    void loadRooms();
  }, [loadRooms]);
  const publicRooms = rooms.filter((room) => room.privacy === "public");
  const liveNow = publicRooms.slice(0, 5);
  const popular = [...publicRooms].sort((a, b) => b.participantCount - a.participantCount).slice(0, 6);
  const newest = publicRooms.slice(0, 6);
  const unread = notifications.filter((item) => !item.readAt).length;
  if (!user) return null;
  return (
    <SafeAreaView style={[styles.screen, { backgroundColor: theme.colors.background }]} edges={["top"]}>
      <ScrollView contentContainerStyle={styles.content} showsVerticalScrollIndicator={false}>
        <View style={styles.topbar}>
          <Image source={mascot} style={styles.logo} resizeMode="contain" />
          <Text style={[styles.pill, { backgroundColor: theme.colors.soft, color: theme.colors.blue }]}>BANT</Text>
          <View style={styles.right}>
            <Pressable onPress={() => router.push("/(tabs)/friends")} style={styles.bellButton}>
              <Bell size={22} color={theme.colors.secondary} />
              {unread ? <View style={[styles.badge, { backgroundColor: theme.colors.danger }]}><Text style={styles.badgeText}>{unread > 9 ? "9+" : unread}</Text></View> : null}
            </Pressable>
            <BantAvatar user={user} size={38} />
          </View>
        </View>
        <View>
          <Text style={[styles.greeting, { color: theme.colors.text }]}>What's happening, {user.name.split(" ")[0]}?</Text>
          <Text style={[styles.sub, { color: theme.colors.secondary }]}>Find the room for your mood.</Text>
        </View>
        <Section title="LIVE NOW" horizontal>
          {liveNow.length ? liveNow.map((room) => <RoomCard key={room.id} room={room} onPress={() => router.push(`/room/${room.id}`)} />) : <EmptyState title="Nothing live right now." body="Start a room." action="Start a room" onPress={() => router.push("/room/create")} />}
        </Section>
        <View style={[styles.start, { backgroundColor: theme.colors.blue }]}>
          <Text style={styles.startTitle}>Got something to say?</Text>
          <Text style={styles.startBody}>Start a room and invite people who get it.</Text>
          <BantButton title="Start a room" variant="secondary" onPress={() => router.push("/room/create")} />
        </View>
        <Section title="POPULAR">
          {popular.map((room) => <RoomCard key={room.id} room={room} onPress={() => router.push(`/room/${room.id}`)} />)}
        </Section>
        <Section title="NEW">
          {newest.map((room) => <RoomCard key={room.id} room={room} onPress={() => router.push(`/room/${room.id}`)} />)}
        </Section>
      </ScrollView>
    </SafeAreaView>
  );
}

function Section({ title, children, horizontal }: { title: string; children: ReactNode; horizontal?: boolean }) {
  const theme = useTheme();
  return (
    <View style={styles.section}>
      <Text style={[styles.sectionTitle, { color: theme.colors.muted }]}>{title}</Text>
      {horizontal ? <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.horizontal}>{children}</ScrollView> : <View style={styles.vertical}>{children}</View>}
    </View>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1 },
  content: { padding: 20, paddingBottom: 110, gap: 26, maxWidth: 640, width: "100%", alignSelf: "center" },
  topbar: { height: 54, flexDirection: "row", alignItems: "center", justifyContent: "space-between" },
  logo: { width: 46, height: 46 },
  pill: { overflow: "hidden", borderRadius: 999, paddingHorizontal: 14, paddingVertical: 8, fontFamily: "PlusJakartaSans_800ExtraBold", fontSize: 12 },
  right: { flexDirection: "row", alignItems: "center", gap: 14 },
  bellButton: { width: 38, height: 38, alignItems: "center", justifyContent: "center", position: "relative" },
  badge: { position: "absolute", top: 1, right: 0, minWidth: 16, height: 16, borderRadius: 8, alignItems: "center", justifyContent: "center", paddingHorizontal: 3 },
  badgeText: { color: "#fff", fontFamily: "PlusJakartaSans_800ExtraBold", fontSize: 9 },
  greeting: { fontFamily: "PlusJakartaSans_800ExtraBold", fontSize: 28, lineHeight: 34 },
  sub: { fontFamily: "PlusJakartaSans_500Medium", fontSize: 15, marginTop: 6 },
  section: { gap: 12 },
  sectionTitle: { fontFamily: "PlusJakartaSans_800ExtraBold", fontSize: 12, letterSpacing: 1.2 },
  horizontal: { gap: 12, paddingRight: 20 },
  vertical: { gap: 12 },
  start: { borderRadius: 24, padding: 20, gap: 10 },
  startTitle: { color: "#fff", fontFamily: "PlusJakartaSans_800ExtraBold", fontSize: 21 },
  startBody: { color: "rgba(255,255,255,0.86)", fontFamily: "PlusJakartaSans_500Medium", fontSize: 14, lineHeight: 20 }
});
