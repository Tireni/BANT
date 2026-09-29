import { router } from "expo-router";
import { Bell, Info, MessageSquare, Shield, Sparkles, Tags, UserRound } from "lucide-react-native";
import { ReactNode, useEffect, useState } from "react";
import { Pressable, ScrollView, StyleSheet, Text, TextInput, View } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { BantAvatar } from "@/components/common/BantAvatar";
import { BantButton } from "@/components/common/BantButton";
import { BantInput } from "@/components/common/BantInput";
import { BottomSheet } from "@/components/common/BottomSheet";
import { ThemeToggle } from "@/components/common/ThemeToggle";
import { useTheme } from "@/hooks/useTheme";
import { hasSupabaseConfig, supabase } from "@/lib/supabase";
import { useBantStore } from "@/store/useBantStore";

export default function Profile() {
  const theme = useTheme();
  const user = useBantStore((state) => state.currentUser);
  const friendIds = useBantStore((state) => state.friendIds);
  const notifications = useBantStore((state) => state.notifications);
  const rooms = useBantStore((state) => state.rooms);
  const resetClientState = useBantStore((state) => state.resetClientState);
  const signOut = useBantStore((state) => state.signOut);
  const updateProfile = useBantStore((state) => state.updateProfile);
  const loadPeople = useBantStore((state) => state.loadPeople);
  const loadNotifications = useBantStore((state) => state.loadNotifications);
  const setToast = useBantStore((state) => state.setToast);
  const [editOpen, setEditOpen] = useState(false);
  const [feedbackOpen, setFeedbackOpen] = useState(false);
  const [displayName, setDisplayName] = useState(user?.name ?? "");
  const [username, setUsername] = useState(user?.username ?? "");
  const [bio, setBio] = useState(user?.bio ?? "");
  const [feedbackCategory, setFeedbackCategory] = useState<"bug" | "feature" | "suggestion" | "complaint" | "other">("suggestion");
  const [feedbackMessage, setFeedbackMessage] = useState("");
  const [saving, setSaving] = useState(false);
  const [submittingFeedback, setSubmittingFeedback] = useState(false);

  useEffect(() => {
    void loadPeople();
    void loadNotifications();
  }, [loadNotifications, loadPeople]);

  useEffect(() => {
    if (!user) return;
    setDisplayName(user.name);
    setUsername(user.username);
    setBio(user.bio);
  }, [user]);

  if (!user) return null;

  const unread = notifications.filter((item) => !item.readAt).length;
  const saveProfile = async () => {
    setSaving(true);
    const ok = await updateProfile({ displayName, username, bio });
    setSaving(false);
    if (ok) setEditOpen(false);
  };
  const activeRoomCount = rooms.filter((room) => room.currentUserRole).length;
  const submitFeedback = async () => {
    if (!hasSupabaseConfig || !user.id) {
      setToast("Feedback needs Supabase setup");
      return;
    }
    setSubmittingFeedback(true);
    const { error } = await supabase.from("feedback").insert({
      user_id: user.id,
      category: feedbackCategory,
      message: feedbackMessage.trim()
    });
    setSubmittingFeedback(false);
    if (error) {
      setToast(error.message);
      return;
    }
    setFeedbackMessage("");
    setFeedbackOpen(false);
    setToast("Feedback submitted");
  };

  return (
    <SafeAreaView style={[styles.screen, { backgroundColor: theme.colors.background }]} edges={["top"]}>
      <ScrollView contentContainerStyle={styles.content}>
        <View style={[styles.profile, { backgroundColor: theme.colors.surface, borderColor: theme.colors.border }]}>
          <BantAvatar user={user} size={86} />
          <Text style={[styles.name, { color: theme.colors.text }]}>{user.name}</Text>
          <Text style={[styles.meta, { color: theme.colors.secondary }]}>@{user.username}</Text>
          {user.bio ? <Text style={[styles.bio, { color: theme.colors.secondary }]}>{user.bio}</Text> : null}
          <BantButton title="Edit profile" variant="ghost" onPress={() => setEditOpen(true)} style={{ marginTop: 8 }} />
        </View>
        <View style={styles.stats}>
          <Stat label="Friends" value={String(friendIds.length)} />
          <Stat label="Active rooms" value={String(activeRoomCount)} />
          <Stat label="Live rooms" value={String(rooms.filter((room) => room.isLive).length)} />
        </View>
        <Card title="Appearance"><ThemeToggle /></Card>
        <SettingsRow icon={<UserRound size={20} color={theme.colors.blue} />} title="Profile setup" onPress={() => router.push("/onboarding/profile")} />
        <SettingsRow icon={<Tags size={20} color={theme.colors.blue} />} title="Interests" onPress={() => router.push("/onboarding/interests")} />
        <SettingsRow icon={<Bell size={20} color={theme.colors.blue} />} title={`Notifications${unread ? ` (${unread})` : ""}`} onPress={() => router.push("/(tabs)/friends")} />
        <SettingsRow icon={<MessageSquare size={20} color={theme.colors.blue} />} title="Send feedback" onPress={() => setFeedbackOpen(true)} />
        <SettingsRow icon={<Shield size={20} color={theme.colors.blue} />} title="Safety" onPress={() => setToast("Safety tools need backend support before launch")} />
        <SettingsRow icon={<Info size={20} color={theme.colors.blue} />} title="About BANT" onPress={() => setToast("A safe place to just talk")} />
        <BantButton title="Log out" variant="ghost" onPress={async () => { await signOut(); router.replace("/auth/welcome"); }} />
        <BantButton title="Reset client state" variant="danger" onPress={async () => { await resetClientState(); router.replace("/auth/welcome"); }} />
      </ScrollView>
      <BottomSheet visible={editOpen} onClose={() => setEditOpen(false)}>
        <Text style={[styles.sheetTitle, { color: theme.colors.text }]}>Edit profile</Text>
        <View style={styles.form}>
          <BantInput placeholder="Display name" value={displayName} onChangeText={setDisplayName} />
          <BantInput placeholder="Username" value={username} onChangeText={setUsername} autoCapitalize="none" />
          <BantInput placeholder="Bio" value={bio} onChangeText={setBio} multiline maxLength={160} />
          <BantButton title="Save profile" onPress={saveProfile} loading={saving} />
        </View>
      </BottomSheet>
      <BottomSheet visible={feedbackOpen} onClose={() => setFeedbackOpen(false)}>
        <Text style={[styles.sheetTitle, { color: theme.colors.text }]}>Send feedback</Text>
        <Text style={[styles.sheetLabel, { color: theme.colors.muted }]}>CATEGORY</Text>
        <View style={styles.feedbackCategories}>
          {(["bug", "feature", "suggestion", "complaint", "other"] as const).map((category) => (
            <Pressable key={category} onPress={() => setFeedbackCategory(category)} style={[styles.categoryChip, { backgroundColor: feedbackCategory === category ? theme.colors.blue : theme.colors.soft, borderColor: feedbackCategory === category ? theme.colors.blue : theme.colors.border }]}>
              <Text style={[styles.categoryText, { color: feedbackCategory === category ? "#fff" : theme.colors.secondary }]}>{category}</Text>
            </Pressable>
          ))}
        </View>
        <TextInput
          value={feedbackMessage}
          onChangeText={setFeedbackMessage}
          placeholder="Tell us what to improve"
          placeholderTextColor={theme.colors.muted}
          selectionColor={theme.colors.blue}
          multiline
          maxLength={1200}
          style={[styles.feedbackInput, { color: theme.colors.text, borderColor: theme.colors.border, backgroundColor: theme.colors.background }]}
        />
        <BantButton title="Submit feedback" onPress={submitFeedback} loading={submittingFeedback} style={{ marginTop: 12 }} />
      </BottomSheet>
    </SafeAreaView>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  const theme = useTheme();
  return <View style={[styles.stat, { backgroundColor: theme.colors.surface, borderColor: theme.colors.border }]}><Text style={[styles.statValue, { color: theme.colors.text }]}>{value}</Text><Text style={[styles.statLabel, { color: theme.colors.secondary }]}>{label}</Text></View>;
}

function Card({ title, children }: { title: string; children: ReactNode }) {
  const theme = useTheme();
  return <View style={[styles.card, { backgroundColor: theme.colors.surface, borderColor: theme.colors.border }]}><Text style={[styles.cardTitle, { color: theme.colors.text }]}>{title}</Text>{children}</View>;
}

function SettingsRow({ icon, title, onPress }: { icon: ReactNode; title: string; onPress: () => void }) {
  const theme = useTheme();
  return <Pressable onPress={onPress} style={[styles.row, { backgroundColor: theme.colors.surface, borderColor: theme.colors.border }]}>{icon}<Text style={[styles.rowText, { color: theme.colors.text }]}>{title}</Text><Sparkles size={18} color={theme.colors.muted} /></Pressable>;
}

const styles = StyleSheet.create({
  screen: { flex: 1 },
  content: { padding: 20, paddingBottom: 110, gap: 14, maxWidth: 640, width: "100%", alignSelf: "center" },
  profile: { borderWidth: 1, borderRadius: 26, alignItems: "center", padding: 22 },
  name: { fontFamily: "PlusJakartaSans_800ExtraBold", fontSize: 23, marginTop: 12 },
  meta: { fontFamily: "PlusJakartaSans_500Medium", fontSize: 13, marginTop: 4, textAlign: "center" },
  bio: { fontFamily: "PlusJakartaSans_500Medium", fontSize: 13, lineHeight: 19, marginTop: 10, textAlign: "center" },
  stats: { flexDirection: "row", gap: 10 },
  stat: { flex: 1, borderWidth: 1, borderRadius: 18, padding: 14 },
  statValue: { fontFamily: "PlusJakartaSans_800ExtraBold", fontSize: 20 },
  statLabel: { fontFamily: "PlusJakartaSans_600SemiBold", fontSize: 11, marginTop: 4 },
  card: { borderWidth: 1, borderRadius: 20, padding: 16, gap: 12 },
  cardTitle: { fontFamily: "PlusJakartaSans_800ExtraBold", fontSize: 16 },
  row: { borderWidth: 1, borderRadius: 18, padding: 16, flexDirection: "row", alignItems: "center", gap: 12 },
  rowText: { flex: 1, fontFamily: "PlusJakartaSans_800ExtraBold", fontSize: 15 },
  sheetTitle: { fontFamily: "PlusJakartaSans_800ExtraBold", fontSize: 22, marginBottom: 12 },
  sheetLabel: { fontFamily: "PlusJakartaSans_800ExtraBold", fontSize: 11, letterSpacing: 1.1, marginBottom: 8 },
  form: { gap: 12 },
  feedbackCategories: { flexDirection: "row", flexWrap: "wrap", gap: 8, marginBottom: 12 },
  categoryChip: { borderWidth: 1, borderRadius: 999, paddingHorizontal: 12, paddingVertical: 8 },
  categoryText: { fontFamily: "PlusJakartaSans_800ExtraBold", fontSize: 12, textTransform: "capitalize" },
  feedbackInput: { minHeight: 112, borderWidth: 1, borderRadius: 16, padding: 12, textAlignVertical: "top", fontFamily: "PlusJakartaSans_500Medium", fontSize: 14, outlineStyle: "none" as never }
});
