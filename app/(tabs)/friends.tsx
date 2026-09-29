import { router } from "expo-router";
import { useEffect, useMemo, useState } from "react";
import { ActivityIndicator, Pressable, ScrollView, StyleSheet, Text, View } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { BantInput } from "@/components/common/BantInput";
import { EmptyState } from "@/components/common/EmptyState";
import { UserRow } from "@/components/friends/UserRow";
import { useTheme } from "@/hooks/useTheme";
import { useBantStore } from "@/store/useBantStore";

export default function Friends() {
  const theme = useTheme();
  const people = useBantStore((state) => state.people);
  const friendIds = useBantStore((state) => state.friendIds);
  const notifications = useBantStore((state) => state.notifications);
  const loading = useBantStore((state) => state.peopleLoading);
  const loadPeople = useBantStore((state) => state.loadPeople);
  const sendFriendRequest = useBantStore((state) => state.sendFriendRequest);
  const acceptFriendRequest = useBantStore((state) => state.acceptFriendRequest);
  const declineFriendRequest = useBantStore((state) => state.declineFriendRequest);
  const cancelFriendRequest = useBantStore((state) => state.cancelFriendRequest);
  const joinRoomWithInviteId = useBantStore((state) => state.joinRoomWithInviteId);
  const friendshipState = useBantStore((state) => state.friendshipState);
  const loadNotifications = useBantStore((state) => state.loadNotifications);
  const markNotificationsRead = useBantStore((state) => state.markNotificationsRead);
  const [tab, setTab] = useState<"Discover" | "Friends" | "Notifications">("Discover");
  const [query, setQuery] = useState("");
  useEffect(() => {
    void loadPeople();
    void loadNotifications();
  }, [loadNotifications, loadPeople]);
  useEffect(() => {
    if (tab === "Notifications") void markNotificationsRead();
  }, [markNotificationsRead, tab]);
  const users = useMemo(() => {
    const source = tab === "Friends" ? people.filter((user) => friendIds.includes(user.id)) : people;
    return source.filter((user) => `${user.name} ${user.username}`.toLowerCase().includes(query.toLowerCase()));
  }, [friendIds, people, query, tab]);
  return (
    <SafeAreaView style={[styles.screen, { backgroundColor: theme.colors.background }]} edges={["top"]}>
      <View style={styles.header}>
        <Text style={[styles.title, { color: theme.colors.text }]}>People</Text>
        {tab !== "Notifications" ? <BantInput placeholder="Search people" value={query} onChangeText={setQuery} /> : null}
        <View style={[styles.tabs, { backgroundColor: theme.colors.soft }]}>
          {(["Discover", "Friends", "Notifications"] as const).map((item) => <Pressable key={item} onPress={() => setTab(item)} style={[styles.tab, tab === item && { backgroundColor: theme.colors.blue }]}><Text style={[styles.tabText, { color: tab === item ? "#fff" : theme.colors.secondary }]}>{item}</Text></Pressable>)}
        </View>
      </View>
      <ScrollView contentContainerStyle={styles.list}>
        {tab === "Notifications" ? (
          notifications.length ? notifications.map((item) => {
            const action = item.type === "friend_request" ? (
              <View style={styles.requestActions}>
                <Pressable onPress={() => item.targetId && void acceptFriendRequest(item.targetId)} style={[styles.inlineAction, { backgroundColor: theme.colors.blue }]}>
                  <Text style={[styles.inlineActionText, { color: "#fff" }]}>Accept</Text>
                </Pressable>
                <Pressable onPress={() => item.targetId && void declineFriendRequest(item.targetId)} style={[styles.inlineAction, { backgroundColor: theme.colors.soft }]}>
                  <Text style={[styles.inlineActionText, { color: theme.colors.text }]}>Decline</Text>
                </Pressable>
              </View>
            ) : item.type === "room_invite" ? (
              <View style={styles.requestActions}>
                <Pressable
                  onPress={() => item.targetId && void joinRoomWithInviteId(item.targetId).then((roomId) => roomId && router.push(`/room/${roomId}`))}
                  style={[styles.inlineAction, { backgroundColor: theme.colors.blue }]}
                >
                  <Text style={[styles.inlineActionText, { color: "#fff" }]}>Join</Text>
                </Pressable>
              </View>
            ) : null;
            return (
              <View key={item.id} style={[styles.notification, { borderColor: theme.colors.border, backgroundColor: theme.colors.surface }]}> 
                <Text style={[styles.notificationText, { color: theme.colors.text }]}>{item.body}</Text>
                <Text style={[styles.notificationMeta, { color: theme.colors.secondary }]}>{new Date(item.createdAt).toLocaleString()}</Text>
                {action}
              </View>
            );
          }) : <EmptyState title="No notifications yet." body="Friend requests and room activity will show here." action="Explore rooms" onPress={() => router.push("/(tabs)/rooms")} />
        ) : loading ? (
          <View style={styles.loading}><ActivityIndicator color={theme.colors.blue} /><Text style={[styles.loadingText, { color: theme.colors.secondary }]}>Loading people...</Text></View>
        ) : users.length ? (
          users.map((user) => {
            const state = friendshipState(user.id);
            const action = state === "friends" ? "Friends" : state === "pending_received" ? "Accept" : state === "pending_sent" ? "Request sent" : "Add friend";
            const onPress = () => {
              if (state === "friends") return;
              if (state === "pending_received") void acceptFriendRequest(user.id);
              else if (state === "pending_sent") void cancelFriendRequest(user.id);
              else void sendFriendRequest(user.id);
            };
            return <UserRow key={user.id} user={user} action={action} onPress={onPress} />;
          })
        ) : <EmptyState title="BANT is better with people." body="Add friends and jump into rooms together." action="Explore rooms" onPress={() => router.push("/(tabs)/rooms")} />}
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1 },
  header: { padding: 20, gap: 12, maxWidth: 640, width: "100%", alignSelf: "center" },
  title: { fontFamily: "PlusJakartaSans_800ExtraBold", fontSize: 30 },
  tabs: { flexDirection: "row", padding: 4, borderRadius: 16, gap: 4 },
  tab: { flex: 1, minHeight: 42, borderRadius: 12, alignItems: "center", justifyContent: "center" },
  tabText: { fontFamily: "PlusJakartaSans_800ExtraBold", fontSize: 13 },
  list: { paddingHorizontal: 20, paddingBottom: 110, maxWidth: 640, width: "100%", alignSelf: "center" },
  loading: { minHeight: 180, alignItems: "center", justifyContent: "center", gap: 10 },
  loadingText: { fontFamily: "PlusJakartaSans_700Bold", fontSize: 13 },
  notification: { borderWidth: 1, borderRadius: 18, padding: 16, marginBottom: 10 },
  notificationText: { fontFamily: "PlusJakartaSans_800ExtraBold", fontSize: 14, lineHeight: 20 },
  notificationMeta: { fontFamily: "PlusJakartaSans_500Medium", fontSize: 12, marginTop: 6 },
  requestActions: { flexDirection: "row", gap: 8, marginTop: 12 },
  inlineAction: { minHeight: 34, borderRadius: 10, paddingHorizontal: 12, justifyContent: "center" },
  inlineActionText: { fontFamily: "PlusJakartaSans_800ExtraBold", fontSize: 12 }
});
