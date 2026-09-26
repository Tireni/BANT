import { router } from "expo-router";
import { Plus } from "lucide-react-native";
import { useEffect, useMemo, useState } from "react";
import { Pressable, ScrollView, StyleSheet, Text, View } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { CategoryChip } from "@/components/common/CategoryChip";
import { BantInput } from "@/components/common/BantInput";
import { EmptyState } from "@/components/common/EmptyState";
import { RoomCard } from "@/components/room/RoomCard";
import { useTheme } from "@/hooks/useTheme";
import { useBantStore } from "@/store/useBantStore";

const categories = ["Feed", "Gaming", "Anime", "Art", "Philosophy", "Music", "Technology", "Movies", "Sports", "Books", "Fashion", "Culture", "Relationships", "Business", "Comedy", "Science", "Lifestyle", "Food", "Travel", "General"];

export default function Rooms() {
  const theme = useTheme();
  const rooms = useBantStore((state) => state.rooms);
  const loadRooms = useBantStore((state) => state.loadRooms);
  const campus = useBantStore((state) => state.selectedUniversity);
  const [query, setQuery] = useState("");
  const [category, setCategory] = useState("For You");
  const [filter, setFilter] = useState("Live");
  useEffect(() => {
    void loadRooms();
  }, [loadRooms]);
  const filtered = useMemo(() => {
    const visible = rooms.filter((room) => {
      if (room.privacy === "private") return false;
      if (category === "Feed") {
        return `${room.title} ${room.description}`.toLowerCase().includes(query.toLowerCase());
      }
      if (room.category !== category) return false;
      return `${room.title} ${room.description}`.toLowerCase().includes(query.toLowerCase());
    });
    if (filter === "Popular") return [...visible].sort((a, b) => b.participantCount - a.participantCount);
    if (filter === "New") return [...visible].reverse();
    return visible.filter((room) => room.isLive);
  }, [rooms, category, campus?.name, query, filter]);
  return (
    <SafeAreaView style={[styles.screen, { backgroundColor: theme.colors.background }]} edges={["top"]}>
      <View style={styles.header}>
        <Text style={[styles.title, { color: theme.colors.text }]}>Explore rooms</Text>
        <BantInput placeholder="Search conversations" value={query} onChangeText={setQuery} />
        <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.chips}>{categories.map((item) => <CategoryChip key={item} label={item} selected={category === item} onPress={() => setCategory(item)} />)}</ScrollView>
        <View style={styles.filters}>{["Live", "Popular", "New"].map((item) => <Pressable key={item} onPress={() => setFilter(item)} style={[styles.filter, { backgroundColor: filter === item ? theme.colors.blue : theme.colors.soft }]}><Text style={[styles.filterText, { color: filter === item ? "#fff" : theme.colors.secondary }]}>{item}</Text></Pressable>)}</View>
      </View>
      <ScrollView contentContainerStyle={styles.list} showsVerticalScrollIndicator={false}>
        {filtered.length ? filtered.map((room) => <RoomCard key={room.id} room={room} onPress={() => router.push(`/room/${room.id}`)} />) : <EmptyState title="Quiet here for now." body="Start the conversation." action="Start a room" onPress={() => router.push("/room/create")} />}
      </ScrollView>
      <Pressable onPress={() => router.push("/room/create")} style={[styles.fab, { backgroundColor: theme.colors.blue }, theme.shadow]}><Plus color="#fff" size={28} /></Pressable>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1 },
  header: { padding: 20, gap: 12, maxWidth: 640, width: "100%", alignSelf: "center" },
  title: { fontFamily: "PlusJakartaSans_800ExtraBold", fontSize: 30 },
  chips: { gap: 8 },
  filters: { flexDirection: "row", gap: 8 },
  filter: { minHeight: 36, paddingHorizontal: 14, borderRadius: 999, justifyContent: "center" },
  filterText: { fontFamily: "PlusJakartaSans_800ExtraBold", fontSize: 12 },
  list: { paddingHorizontal: 20, paddingBottom: 110, gap: 12, maxWidth: 640, width: "100%", alignSelf: "center" },
  fab: { position: "absolute", right: 22, bottom: 88, width: 58, height: 58, borderRadius: 29, alignItems: "center", justifyContent: "center" }
});
