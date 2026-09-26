import { Redirect, router } from "expo-router";
import { ArrowLeft, RefreshCw } from "lucide-react-native";
import { useEffect, useState } from "react";
import { ActivityIndicator, Pressable, ScrollView, StyleSheet, Text, View } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { BantButton } from "@/components/common/BantButton";
import { useTheme } from "@/hooks/useTheme";
import { onboardingRoute } from "@/lib/onboarding";
import { hasSupabaseConfig, supabase } from "@/lib/supabase";
import { useBantStore } from "@/store/useBantStore";

type AdminProfile = { id: string; display_name: string; username: string; is_admin: boolean; created_at: string };
type AdminRoom = { id: string; title: string; status: string; privacy: string; created_at: string };
type AdminFeedback = { id: string; category: string; message: string; status: string; created_at: string };
type AdminReport = { id: string; target_type: string; reason: string; description: string | null; status: string; created_at: string };

export default function Admin() {
  const theme = useTheme();
  const authenticated = useBantStore((state) => state.authenticated);
  const profile = useBantStore((state) => state.profile);
  const [checking, setChecking] = useState(true);
  const [isAdmin, setIsAdmin] = useState(false);
  const [profiles, setProfiles] = useState<AdminProfile[]>([]);
  const [rooms, setRooms] = useState<AdminRoom[]>([]);
  const [feedback, setFeedback] = useState<AdminFeedback[]>([]);
  const [reports, setReports] = useState<AdminReport[]>([]);
  const [error, setError] = useState<string | null>(null);

  const load = async () => {
    if (!hasSupabaseConfig || !profile?.id) {
      setChecking(false);
      setError("Admin needs Supabase setup.");
      return;
    }
    setChecking(true);
    setError(null);
    const { data: me, error: meError } = await supabase.from("profiles").select("is_admin").eq("id", profile.id).maybeSingle();
    if (meError || !me?.is_admin) {
      setIsAdmin(false);
      setChecking(false);
      setError(meError?.message ?? "You are not an admin.");
      return;
    }
    setIsAdmin(true);
    const [profileRows, roomRows, feedbackRows, reportRows] = await Promise.all([
      supabase.from("profiles").select("id, display_name, username, is_admin, created_at").order("created_at", { ascending: false }).limit(50),
      supabase.from("rooms").select("id, title, status, privacy, created_at").order("created_at", { ascending: false }).limit(50),
      supabase.from("feedback").select("id, category, message, status, created_at").order("created_at", { ascending: false }).limit(50),
      supabase.from("reports").select("id, target_type, reason, description, status, created_at").order("created_at", { ascending: false }).limit(50)
    ]);
    const firstError = profileRows.error ?? roomRows.error ?? feedbackRows.error ?? reportRows.error;
    if (firstError) setError(firstError.message);
    setProfiles(profileRows.data ?? []);
    setRooms(roomRows.data ?? []);
    setFeedback(feedbackRows.data ?? []);
    setReports(reportRows.data ?? []);
    setChecking(false);
  };

  useEffect(() => {
    void load();
  }, [profile?.id]);

  if (!authenticated) return <Redirect href="/auth/welcome" />;
  if (!profile?.onboarding_completed) return <Redirect href={onboardingRoute(profile) as any} />;

  const updateFeedback = async (id: string, status: "reviewing" | "closed") => {
    await supabase.from("feedback").update({ status }).eq("id", id);
    await load();
  };
  const updateReport = async (id: string, status: "reviewing" | "resolved" | "dismissed") => {
    await supabase.from("reports").update({ status }).eq("id", id);
    await load();
  };

  return (
    <SafeAreaView style={[styles.screen, { backgroundColor: theme.colors.background }]} edges={["top"]}>
      <ScrollView contentContainerStyle={styles.content}>
        <View style={styles.header}>
          <Pressable onPress={() => router.back()} style={styles.icon}><ArrowLeft color={theme.colors.text} size={24} /></Pressable>
          <View style={{ flex: 1 }}>
            <Text style={[styles.title, { color: theme.colors.text }]}>Admin</Text>
            <Text style={[styles.sub, { color: theme.colors.secondary }]}>Reports, feedback, users, and rooms.</Text>
          </View>
          <Pressable onPress={load} style={styles.icon}><RefreshCw color={theme.colors.text} size={21} /></Pressable>
        </View>
        {checking ? <View style={styles.loading}><ActivityIndicator color={theme.colors.blue} /></View> : null}
        {error ? <Text style={[styles.error, { color: theme.colors.danger }]}>{error}</Text> : null}
        {isAdmin ? (
          <>
            <Section title="Feedback" count={feedback.length}>
              {feedback.map((item) => <AdminCard key={item.id} title={`${item.category} - ${item.status}`} body={item.message} date={item.created_at}><BantButton title="Review" variant="ghost" onPress={() => updateFeedback(item.id, "reviewing")} /><BantButton title="Close" onPress={() => updateFeedback(item.id, "closed")} /></AdminCard>)}
            </Section>
            <Section title="Reports" count={reports.length}>
              {reports.map((item) => <AdminCard key={item.id} title={`${item.target_type} - ${item.reason} - ${item.status}`} body={item.description ?? "No description"} date={item.created_at}><BantButton title="Review" variant="ghost" onPress={() => updateReport(item.id, "reviewing")} /><BantButton title="Resolve" onPress={() => updateReport(item.id, "resolved")} /><BantButton title="Dismiss" variant="danger" onPress={() => updateReport(item.id, "dismissed")} /></AdminCard>)}
            </Section>
            <Section title="Users" count={profiles.length}>
              {profiles.map((item) => <AdminCard key={item.id} title={`${item.display_name} @${item.username}`} body={item.is_admin ? "Admin" : "User"} date={item.created_at} />)}
            </Section>
            <Section title="Rooms" count={rooms.length}>
              {rooms.map((item) => <AdminCard key={item.id} title={`${item.title} - ${item.status}`} body={item.privacy} date={item.created_at} />)}
            </Section>
          </>
        ) : null}
      </ScrollView>
    </SafeAreaView>
  );
}

function Section({ title, count, children }: { title: string; count: number; children: React.ReactNode }) {
  const theme = useTheme();
  return <View style={styles.section}><Text style={[styles.sectionTitle, { color: theme.colors.muted }]}>{title.toUpperCase()} ({count})</Text><View style={styles.sectionList}>{children}</View></View>;
}

function AdminCard({ title, body, date, children }: { title: string; body: string; date: string; children?: React.ReactNode }) {
  const theme = useTheme();
  return (
    <View style={[styles.card, { backgroundColor: theme.colors.surface, borderColor: theme.colors.border }]}>
      <Text style={[styles.cardTitle, { color: theme.colors.text }]}>{title}</Text>
      <Text style={[styles.cardBody, { color: theme.colors.secondary }]}>{body}</Text>
      <Text style={[styles.cardDate, { color: theme.colors.muted }]}>{new Date(date).toLocaleString()}</Text>
      {children ? <View style={styles.actions}>{children}</View> : null}
    </View>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1 },
  content: { padding: 20, paddingBottom: 80, gap: 18, maxWidth: 760, width: "100%", alignSelf: "center" },
  header: { flexDirection: "row", alignItems: "center", gap: 12 },
  icon: { width: 44, height: 44, alignItems: "center", justifyContent: "center" },
  title: { fontFamily: "PlusJakartaSans_800ExtraBold", fontSize: 30 },
  sub: { fontFamily: "PlusJakartaSans_500Medium", fontSize: 13, marginTop: 2 },
  loading: { minHeight: 120, alignItems: "center", justifyContent: "center" },
  error: { fontFamily: "PlusJakartaSans_800ExtraBold", fontSize: 14 },
  section: { gap: 10 },
  sectionTitle: { fontFamily: "PlusJakartaSans_800ExtraBold", fontSize: 12, letterSpacing: 1.2 },
  sectionList: { gap: 10 },
  card: { borderWidth: 1, borderRadius: 18, padding: 14, gap: 6 },
  cardTitle: { fontFamily: "PlusJakartaSans_800ExtraBold", fontSize: 15 },
  cardBody: { fontFamily: "PlusJakartaSans_500Medium", fontSize: 13, lineHeight: 18 },
  cardDate: { fontFamily: "PlusJakartaSans_600SemiBold", fontSize: 11 },
  actions: { flexDirection: "row", flexWrap: "wrap", gap: 8, marginTop: 8 }
});
