import { Redirect, router } from "expo-router";
import { ArrowLeft } from "lucide-react-native";
import { useState } from "react";
import { KeyboardAvoidingView, Platform, Pressable, ScrollView, StyleSheet, Text, View } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { BantButton } from "@/components/common/BantButton";
import { BantInput } from "@/components/common/BantInput";
import { CategoryChip } from "@/components/common/CategoryChip";
import { PrivacySelector } from "@/components/room/PrivacySelector";
import { useTheme } from "@/hooks/useTheme";
import { onboardingRoute } from "@/lib/onboarding";
import { useBantStore } from "@/store/useBantStore";
import { RoomCategory, RoomPrivacy } from "@/types/room";

const categories: RoomCategory[] = ["Feed", "Gaming", "Anime", "Art", "Philosophy", "Music", "Technology", "Movies", "Sports", "Books", "Fashion", "Culture", "Relationships", "Business", "Comedy", "Science", "Lifestyle", "Food", "Travel", "General"];

export default function CreateRoom() {
  const theme = useTheme();
  const authenticated = useBantStore((state) => state.authenticated);
  const profile = useBantStore((state) => state.profile);
  const createRoom = useBantStore((state) => state.createRoom);
  const setToast = useBantStore((state) => state.setToast);
  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [category, setCategory] = useState<RoomCategory>("General");
  const [privacy, setPrivacy] = useState<RoomPrivacy>("public");
  const [maxParticipants, setMaxParticipants] = useState<number>(20);
  const [noiseControlEnabled, setNoiseControlEnabled] = useState<boolean>(false);
  const [joinRule, setJoinRule] = useState<"Everyone" | "Friends only">("Everyone");
  const [creating, setCreating] = useState(false);
  if (!authenticated) return <Redirect href="/auth/welcome" />;
  if (!profile?.onboarding_completed) return <Redirect href={onboardingRoute(profile) as any} />;
  const start = async () => {
    if (!title.trim()) {
      setToast("Name the room first");
      return;
    }
    if (maxParticipants < 5 || maxParticipants > 100) {
      setToast("Choose a room size between 5 and 100 participants");
      return;
    }
    setCreating(true);
    const room = createRoom({ title: title.trim(), description: description.trim(), category, privacy, joinRule, maxParticipants, noiseControl: noiseControlEnabled });
    const created = await room;
    setCreating(false);
    if (created) router.replace(`/room/${created.id}`);
  };
  return (
    <SafeAreaView style={[styles.screen, { backgroundColor: theme.colors.background }]} edges={["top"]}>
      <KeyboardAvoidingView behavior={Platform.OS === "ios" ? "padding" : undefined} style={styles.keyboard}>
        <View style={styles.header}>
          <Pressable onPress={() => router.back()} style={styles.icon}><ArrowLeft color={theme.colors.text} size={24} /></Pressable>
          <Text style={[styles.title, { color: theme.colors.text }]}>Start a room</Text>
        </View>
        <ScrollView contentContainerStyle={styles.content}>
          <View style={styles.field}>
            <Text style={[styles.label, { color: theme.colors.text }]}>Room name</Text>
            <BantInput placeholder="What are we talking about?" value={title} onChangeText={setTitle} />
          </View>
          <View style={styles.field}>
            <Text style={[styles.label, { color: theme.colors.text }]}>Optional description</Text>
            <BantInput placeholder="Give people a reason to join..." value={description} onChangeText={setDescription} multiline />
          </View>
          <View style={styles.field}>
            <Text style={[styles.label, { color: theme.colors.text }]}>Category</Text>
            <View style={styles.chips}>{categories.map((item) => <CategoryChip key={item} label={item} selected={category === item} onPress={() => setCategory(item)} />)}</View>
          </View>
          <View style={styles.field}>
            <Text style={[styles.label, { color: theme.colors.text }]}>Privacy</Text>
            <PrivacySelector value={privacy} onChange={setPrivacy} />
          </View>
          <View style={styles.field}>
            <Text style={[styles.label, { color: theme.colors.text }]}>Maximum participants</Text>
            <View style={[styles.selectWrap, { backgroundColor: theme.colors.surface, borderColor: theme.colors.border }]}>
              <Text style={[styles.selectValue, { color: theme.colors.text }]}>{maxParticipants}</Text>
              <View style={styles.selectOptions}>
                {[5, 10, 15, 20, 30, 50, 75, 100].map((value) => (
                  <Pressable key={value} onPress={() => setMaxParticipants(value)} style={[styles.option, { backgroundColor: maxParticipants === value ? theme.colors.blue : theme.colors.background, borderColor: maxParticipants === value ? theme.colors.blue : theme.colors.border }]}>
                    <Text style={[styles.optionText, { color: maxParticipants === value ? "#fff" : theme.colors.text }]}>{value}</Text>
                  </Pressable>
                ))}
              </View>
            </View>
          </View>
          <View style={styles.field}>
            <Text style={[styles.label, { color: theme.colors.text }]}>Noise Control</Text>
            <Pressable onPress={() => setNoiseControlEnabled((value) => !value)} style={[styles.toggle, { backgroundColor: noiseControlEnabled ? theme.colors.mint : theme.colors.surface, borderColor: theme.colors.border }]}>
              <Text style={[styles.toggleText, { color: noiseControlEnabled ? "#0b1f1f" : theme.colors.text }]}>{noiseControlEnabled ? "ON" : "OFF"}</Text>
            </Pressable>
            <Text style={[styles.helpText, { color: theme.colors.secondary }]}>When enabled, the host can send quiet warnings to participants.</Text>
          </View>
          {privacy === "public" ? (
            <View style={styles.field}>
              <Text style={[styles.label, { color: theme.colors.text }]}>Who can join?</Text>
              <View style={styles.joinRules}>{(["Everyone", "Friends only"] as const).map((item) => <Pressable key={item} onPress={() => setJoinRule(item)} style={[styles.rule, { backgroundColor: joinRule === item ? theme.colors.blue : theme.colors.surface, borderColor: joinRule === item ? theme.colors.blue : theme.colors.border }]}><Text style={[styles.ruleText, { color: joinRule === item ? "#fff" : theme.colors.secondary }]}>{item}</Text></Pressable>)}</View>
            </View>
          ) : null}
        </ScrollView>
        <View style={styles.footer}><BantButton title="Start room" onPress={start} loading={creating} style={styles.button} /></View>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1 },
  keyboard: { flex: 1, width: "100%" },
  header: { padding: 16, flexDirection: "row", alignItems: "center", gap: 8, maxWidth: 560, width: "100%", alignSelf: "center" },
  icon: { width: 44, height: 44, alignItems: "center", justifyContent: "center" },
  title: { fontFamily: "PlusJakartaSans_800ExtraBold", fontSize: 24 },
  content: { padding: 20, paddingBottom: 24, gap: 22, maxWidth: 560, width: "100%", alignSelf: "center" },
  field: { gap: 10 },
  label: { fontFamily: "PlusJakartaSans_800ExtraBold", fontSize: 15 },
  chips: { flexDirection: "row", flexWrap: "wrap", gap: 8 },
  joinRules: { flexDirection: "row", gap: 10 },
  rule: { flex: 1, minHeight: 48, borderRadius: 16, borderWidth: 1, alignItems: "center", justifyContent: "center" },
  ruleText: { fontFamily: "PlusJakartaSans_800ExtraBold", fontSize: 13 },
  selectWrap: { borderWidth: 1, borderRadius: 18, padding: 12, gap: 10 },
  selectValue: { fontFamily: "PlusJakartaSans_800ExtraBold", fontSize: 18 },
  selectOptions: { flexDirection: "row", flexWrap: "wrap", gap: 8 },
  option: { minWidth: 54, borderRadius: 12, borderWidth: 1, paddingHorizontal: 10, paddingVertical: 8, alignItems: "center" },
  optionText: { fontFamily: "PlusJakartaSans_800ExtraBold", fontSize: 12 },
  toggle: { minHeight: 52, borderWidth: 1, borderRadius: 16, paddingHorizontal: 14, justifyContent: "center" },
  toggleText: { fontFamily: "PlusJakartaSans_800ExtraBold", fontSize: 14 },
  helpText: { fontFamily: "PlusJakartaSans_500Medium", fontSize: 12, lineHeight: 18 },
  footer: { width: "100%", maxWidth: 560, alignSelf: "center", paddingHorizontal: 20, paddingBottom: 24, paddingTop: 12 },
  button: { width: "100%" }
});
