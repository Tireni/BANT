import * as Clipboard from "expo-clipboard";
import * as Sharing from "expo-sharing";
import { Redirect, router, useLocalSearchParams } from "expo-router";
import { ArrowLeft, Flag, Hand, Lock, Mic, MicOff, MoreHorizontal, Send, Share2, Users, Volume2, X } from "lucide-react-native";
import { useEffect, useMemo, useState } from "react";
import { ActivityIndicator, Pressable, ScrollView, StyleSheet, Text, TextInput, View } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { BottomSheet } from "@/components/common/BottomSheet";
import { BantButton } from "@/components/common/BantButton";
import { ParticipantGrid } from "@/components/room/ParticipantGrid";
import { RoomControlButton } from "@/components/room/RoomControlButton";
import { SpeakerAvatar } from "@/components/room/SpeakerAvatar";
import { NoiseWarningOverlay } from "@/components/room/NoiseWarningOverlay";
import { UserRow } from "@/components/friends/UserRow";
import { useRoomChat } from "@/hooks/useRoomChat";
import { useRoomSimulation } from "@/hooks/useRoomSimulation";
import { useRoomVoice } from "@/hooks/useRoomVoice";
import { useTheme } from "@/hooks/useTheme";
import { onboardingRoute } from "@/lib/onboarding";
import { hasSupabaseConfig, supabase } from "@/lib/supabase";
import { useBantStore } from "@/store/useBantStore";

export default function RoomScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const theme = useTheme();
  const authenticated = useBantStore((state) => state.authenticated);
  const profile = useBantStore((state) => state.profile);
  const rooms = useBantStore((state) => state.rooms);
  const followingIds = useBantStore((state) => state.followingIds);
  const followUser = useBantStore((state) => state.followUser);
  const unfollowUser = useBantStore((state) => state.unfollowUser);
  const setToast = useBantStore((state) => state.setToast);
  const joinRoom = useBantStore((state) => state.joinRoom);
  const leaveRoom = useBantStore((state) => state.leaveRoom);
  const loadRooms = useBantStore((state) => state.loadRooms);
  const room = rooms.find((item) => item.id === id);
  const { activeSpeakerId, participantCount, activity } = useRoomSimulation(room);
  const [handRaised, setHandRaised] = useState(false);
  const [peopleOpen, setPeopleOpen] = useState(false);
  const [inviteOpen, setInviteOpen] = useState(false);
  const [menuOpen, setMenuOpen] = useState(false);
  const [reportOpen, setReportOpen] = useState(false);
  const [reportReason, setReportReason] = useState<"spam" | "harassment" | "unsafe" | "impersonation" | "other">("unsafe");
  const [reportDescription, setReportDescription] = useState("");
  const [reporting, setReporting] = useState(false);
  const [messageDraft, setMessageDraft] = useState("");
  const [moderationMode, setModerationMode] = useState(false);
  const [moderationAction, setModerationAction] = useState<"mute" | "warn" | null>(null);
  const [selectedUserIds, setSelectedUserIds] = useState<string[]>([]);
  const speakers = useMemo(() => room?.speakers ?? [], [room]);
  const listeners = useMemo(() => room?.listeners ?? [], [room]);
  const voicePeerIds = useMemo(() => [...speakers, ...listeners].map((user) => user.id), [listeners, speakers]);
  const voice = useRoomVoice({ roomId: room?.id, currentUserId: profile?.id, peerIds: voicePeerIds });
  const chat = useRoomChat(room?.id, profile?.id);
  useEffect(() => {
    if (!room || !profile?.id) return;
    if (room.currentUserRole) {
      if (voice.status === "idle" && voice.supported) {
        void voice.start();
      }
      return;
    }
    void joinRoom(room.id, room.ownerId === profile.id ? "speaker" : "listener").then((joined) => {
      if (joined && voice.supported) {
        void voice.start();
      }
    });
  }, [joinRoom, profile?.id, room, voice.start, voice.status, voice.supported]);
  useEffect(() => {
    if (!hasSupabaseConfig || !room?.id) return;
    const channel = supabase
      .channel(`room-members:${room.id}`)
      .on("postgres_changes", { event: "*", schema: "public", table: "room_members", filter: `room_id=eq.${room.id}` }, () => {
        void loadRooms();
      })
      .subscribe();
    return () => {
      void supabase.removeChannel(channel);
    };
  }, [loadRooms, room?.id]);
  const redirectHref = !authenticated ? "/auth/welcome" : !profile?.onboarding_completed ? (onboardingRoute(profile) as any) : null;
  const inviteLink = room ? `https://bant.app/r/${room.slug}` : "";
  const copy = async () => {
    if (!room) return;
    await Clipboard.setStringAsync(inviteLink);
    setToast("Invite link copied");
  };
  const leave = async () => {
    if (!room) return;
    voice.stop();
    await leaveRoom(room.id);
    router.replace("/(tabs)/rooms");
  };
  const toggleVoice = async () => {
    if (voice.status === "idle" || voice.status === "error") {
      await voice.start();
      return;
    }
    if (voice.status === "connected") voice.toggleMute();
  };
  const sendChatMessage = async () => {
    const sent = await chat.sendMessage(messageDraft);
    if (sent) setMessageDraft("");
  };
  const submitReport = async () => {
    if (!hasSupabaseConfig || !profile?.id || !room) {
      setToast("Reports need Supabase setup");
      return;
    }
    setReporting(true);
    const { error } = await supabase.from("reports").insert({
      reporter_id: profile.id,
      target_type: "room",
      target_id: room.id,
      reason: reportReason,
      description: reportDescription.trim() || null
    });
    setReporting(false);
    if (error) {
      setToast(error.message);
      return;
    }
    setReportDescription("");
    setReportOpen(false);
    setToast("Report submitted");
  };
  const voiceLabel = voice.status === "requesting" ? "Joining" : voice.status === "connected" ? voice.muted ? "Muted" : "Mic" : "Mic";
  const allParticipants = useMemo(() => [...(speakers ?? []), ...(listeners ?? [])], [listeners, speakers]);
  const isOwner = Boolean(profile && room && (room.ownerId === profile.id || room.currentUserRole === "host" || room.speakerIds.includes(profile.id)));

  const sendWarning = async (targetUserId?: string) => {
    if (!hasSupabaseConfig || !profile?.id || !room?.id) return;
    const payload: { room_id: string; sender_id: string; message: string; target_user_id?: string | null } = {
      room_id: room.id,
      sender_id: profile.id,
      message: "Easy on the noise"
    };
    if (targetUserId) payload.target_user_id = targetUserId;
    const { error } = await supabase.from("room_warnings").insert(payload);
    if (error) {
      setToast(error.message);
      return;
    }
    setSelectedUserIds([]);
    setModerationMode(false);
    setModerationAction(null);
  };

  const warnSelected = async () => {
    if (!selectedUserIds.length) return;
    await Promise.all(selectedUserIds.map((userId) => sendWarning(userId)));
  };

  const muteParticipants = async (targetUserIds?: string[]) => {
    if (!room || !profile?.id || !hasSupabaseConfig) return;
    const isOwner = room.ownerId === profile.id;
    if (!isOwner) return;
    const ids = (targetUserIds && targetUserIds.length ? targetUserIds : allParticipants.map((user) => user.id).filter((userId) => userId !== room.ownerId)).filter(Boolean);
    if (!ids.length) return;
    const { error } = await supabase
      .from("room_members")
      .update({ is_muted: true, muted_by_owner: profile.id, muted_at: new Date().toISOString() })
      .in("user_id", ids)
      .eq("room_id", room.id);
    if (error) {
      setToast(error.message);
      return;
    }
    setSelectedUserIds([]);
    setModerationMode(false);
    setModerationAction(null);
    setToast("Participants muted");
  };

  const endRoom = async () => {
    if (!hasSupabaseConfig || !profile?.id || !room?.id) return;
    const { error } = await supabase.from("rooms").update({ status: "ended" }).eq("id", room.id);
    if (error) {
      setToast(error.message);
      return;
    }
    router.replace("/(tabs)/rooms");
  };

  const roomContent = room ? (
    <SafeAreaView style={[styles.screen, { backgroundColor: theme.colors.background }]} edges={["top"]}>
      <NoiseWarningOverlay roomId={room?.id} currentUserId={profile?.id} />
      <View style={styles.header}>
        <Pressable onPress={() => router.back()} style={styles.icon}><ArrowLeft color={theme.colors.text} size={24} /></Pressable>
        <View style={styles.headerTitle}>
          <Text style={[styles.title, { color: theme.colors.text }]} numberOfLines={1}>{room.title}</Text>
          <Text style={[styles.privacy, { color: theme.colors.secondary }]}>{room.category} · {participantCount} / {room.maxParticipants ?? 20}</Text>
        </View>
        {isOwner ? <View style={[styles.hostBadge, { backgroundColor: theme.colors.soft }]}><Text style={[styles.hostBadgeText, { color: theme.colors.warning }]}>HOST</Text></View> : null}
        <Pressable onPress={() => setMenuOpen(true)} style={styles.icon}><MoreHorizontal color={theme.colors.text} size={24} /></Pressable>
      </View>
      <ScrollView contentContainerStyle={styles.content}>
        <View style={[styles.intro, { backgroundColor: theme.colors.surface, borderColor: theme.colors.border }]}>
          <View style={styles.introTop}>
            {room.privacy === "private" ? <Lock size={14} color={theme.colors.blue} /> : <Volume2 size={14} color={theme.colors.blue} />}
            <Text style={[styles.category, { color: theme.colors.blue }]}>{room.privacy === "private" ? "Private" : "Public"}</Text>
            {room.noiseControlEnabled ? <Text style={[styles.category, { color: theme.colors.warning }]}>Noise Control 🤫</Text> : null}
          </View>
          <Text style={[styles.description, { color: theme.colors.secondary }]}>{room.description || "Live room discussion."}</Text>
          {activity ? <Text style={[styles.activity, { color: theme.colors.mint }]}>{activity}</Text> : null}
          <Text style={[styles.activity, { color: voice.status === "connected" ? theme.colors.mint : theme.colors.secondary }]}>
            {voice.status === "connected" ? `Voice live${voice.remoteCount ? ` · ${voice.remoteCount} connected` : ""}` : voice.error ?? "Live audio is ready as soon as you enter."}
          </Text>
        </View>

        {isOwner ? (
          <View style={styles.moderationBar}>
            <Pressable onPress={() => setModerationMode((value) => !value)} style={[styles.moderationButton, { backgroundColor: moderationMode ? theme.colors.warning : theme.colors.soft }]}>
              <Text style={[styles.moderationButtonText, { color: moderationMode ? "#fff" : theme.colors.text }]}>Moderate</Text>
            </Pressable>
            <Pressable onPress={() => sendWarning()} style={[styles.moderationButton, { backgroundColor: theme.colors.warning }]}>
              <Text style={[styles.moderationButtonText, { color: "#fff" }]}>Warn Everyone 🤫</Text>
            </Pressable>
          </View>
        ) : null}

        <View style={[styles.participantsPanel, { backgroundColor: theme.colors.surface, borderColor: theme.colors.border }]}>
          <Text style={[styles.section, { color: theme.colors.muted }]}>ROOM</Text>
          <ParticipantGrid
            users={allParticipants}
            selectedUserIds={selectedUserIds}
            onToggleUser={(userId) => {
              if (!moderationMode) return;
              setSelectedUserIds((current) => current.includes(userId) ? current.filter((id) => id !== userId) : [...current, userId]);
            }}
            moderationMode={moderationMode}
            roomOwnerId={room.ownerId}
            currentUserId={profile?.id}
            onWarnSelected={warnSelected}
            noiseControlEnabled={Boolean(room.noiseControlEnabled)}
            mutedUserIds={[]}
          />
        </View>
        <Text style={[styles.section, { color: theme.colors.muted }]}>CHAT</Text>
        <View style={[styles.chatCard, { backgroundColor: theme.colors.surface, borderColor: theme.colors.border }]}>
          <View style={styles.messages}>
            {chat.loading ? (
              <View style={styles.chatState}><ActivityIndicator color={theme.colors.blue} /><Text style={[styles.chatStateText, { color: theme.colors.secondary }]}>Loading messages...</Text></View>
            ) : chat.messages.length ? (
              chat.messages.slice(-8).map((message) => {
                const mine = message.senderId === profile?.id;
                return (
                  <View key={message.id} style={[styles.messageBubble, mine ? styles.messageMine : styles.messageOther, { backgroundColor: mine ? theme.colors.blue : theme.colors.soft }]}>
                    <Text style={[styles.messageName, { color: mine ? "#fff" : theme.colors.blue }]}>{mine ? "You" : message.senderName}</Text>
                    <Text style={[styles.messageBody, { color: mine ? "#fff" : theme.colors.text }]}>{message.body}</Text>
                  </View>
                );
              })
            ) : (
              <Text style={[styles.chatStateText, { color: theme.colors.secondary }]}>No messages yet. Start the room chat.</Text>
            )}
          </View>
          {chat.error ? <Text style={[styles.chatError, { color: theme.colors.danger }]}>{chat.error}</Text> : null}
          <View style={[styles.composer, { borderColor: theme.colors.border, backgroundColor: theme.colors.background }]}>
            <TextInput
              value={messageDraft}
              onChangeText={setMessageDraft}
              placeholder="Message the room"
              placeholderTextColor={theme.colors.muted}
              selectionColor={theme.colors.blue}
              multiline
              maxLength={500}
              style={[styles.composerInput, { color: theme.colors.text }]}
            />
            <Pressable disabled={chat.sending} onPress={sendChatMessage} style={[styles.sendButton, { backgroundColor: theme.colors.blue }, chat.sending && { opacity: 0.6 }]}>
              {chat.sending ? <ActivityIndicator color="#fff" /> : <Send size={18} color="#fff" />}
            </Pressable>
          </View>
        </View>
      </ScrollView>
      <View style={[styles.controls, { backgroundColor: theme.colors.surface, borderColor: theme.colors.border }]}>
        {isOwner ? (
          <>
            <RoomControlButton label="Mute" active={false} onPress={() => { setModerationAction("mute"); setModerationMode(true); setSelectedUserIds([]); }} icon={<MicOff size={20} color={theme.colors.text} />} />
            <RoomControlButton label="Moderate" active={moderationMode} onPress={() => { setModerationAction("mute"); setModerationMode(true); setSelectedUserIds([]); }} icon={<Users size={20} color={theme.colors.text} />} />
            {room.noiseControlEnabled ? <RoomControlButton label="Noise 🤫" active={moderationAction === "warn"} onPress={() => { setModerationAction("warn"); setModerationMode(true); setSelectedUserIds([]); }} icon={<Volume2 size={20} color={theme.colors.warning} />} /> : null}
            <RoomControlButton label="End Room" danger onPress={endRoom} icon={<X size={20} color={theme.colors.danger} />} />
          </>
        ) : (
          <>
            <RoomControlButton label={voiceLabel} active={voice.status === "connected"} onPress={toggleVoice} icon={voice.muted ? <MicOff size={20} color={theme.colors.blue} /> : <Mic size={20} color={voice.status === "connected" ? theme.colors.blue : theme.colors.text} />} />
            <RoomControlButton label={handRaised ? "Raised" : "Hand"} active={handRaised} onPress={() => { setHandRaised(!handRaised); setToast("Hand raised"); }} icon={<Hand size={20} color={handRaised ? theme.colors.blue : theme.colors.text} />} />
            <RoomControlButton label="People" onPress={() => setPeopleOpen(true)} icon={<Users size={20} color={theme.colors.text} />} />
            <RoomControlButton label="Invite" onPress={() => setInviteOpen(true)} icon={<Share2 size={20} color={theme.colors.text} />} />
            <RoomControlButton label="Leave" danger onPress={leave} icon={<X size={20} color={theme.colors.danger} />} />
          </>
        )}
      </View>
      <BottomSheet visible={moderationMode && isOwner && !!moderationAction} onClose={() => { setModerationMode(false); setModerationAction(null); setSelectedUserIds([]); }}>
        <Text style={[styles.sheetTitle, { color: theme.colors.text }]}>{moderationAction === "warn" ? "Noise Control" : "Moderation"}</Text>
        <Text style={[styles.sheetLabel, { color: theme.colors.muted }]}>SELECTED: {selectedUserIds.length}</Text>
        {moderationAction === "mute" ? (
          <View style={styles.sheetActions}>
            <BantButton title={selectedUserIds.length > 1 ? "Mute Selected" : selectedUserIds.length === 1 ? "Mute Selected" : "Mute All"} onPress={() => void muteParticipants(selectedUserIds.length ? selectedUserIds : allParticipants.map((user) => user.id).filter((userId) => userId !== room.ownerId))} />
            <BantButton title="Close" variant="ghost" onPress={() => { setModerationMode(false); setModerationAction(null); setSelectedUserIds([]); }} />
          </View>
        ) : (
          <View style={styles.sheetActions}>
            <BantButton title={selectedUserIds.length > 1 ? "Warn Selected 🤫" : selectedUserIds.length === 1 ? "Warn Selected 🤫" : "Warn All 🤫"} onPress={() => {
              if (!selectedUserIds.length) {
                void sendWarning();
                return;
              }
              void warnSelected();
            }} />
            <BantButton title="Close" variant="ghost" onPress={() => { setModerationMode(false); setModerationAction(null); setSelectedUserIds([]); }} />
          </View>
        )}
      </BottomSheet>
      <BottomSheet visible={peopleOpen} onClose={() => setPeopleOpen(false)}>
        <Text style={[styles.sheetTitle, { color: theme.colors.text }]}>People in this room</Text>
        <ScrollView style={{ maxHeight: 460 }}>
          <Text style={[styles.sheetLabel, { color: theme.colors.muted }]}>SPEAKERS</Text>
          {speakers.map((user) => {
            const following = followingIds.includes(user.id);
            return <UserRow key={user.id} user={user} action={following ? "Following" : "Follow"} onPress={() => following ? unfollowUser(user.id) : followUser(user.id)} />;
          })}
          <Text style={[styles.sheetLabel, { color: theme.colors.muted, marginTop: 16 }]}>LISTENERS</Text>
          {listeners.map((user) => {
            const following = followingIds.includes(user.id);
            return <UserRow key={user.id} user={user} action={following ? "Following" : "Follow"} onPress={() => following ? unfollowUser(user.id) : followUser(user.id)} />;
          })}
        </ScrollView>
      </BottomSheet>
      <BottomSheet visible={inviteOpen} onClose={() => setInviteOpen(false)}>
        <Text style={[styles.sheetTitle, { color: theme.colors.text }]}>Invite people</Text>
        <Text style={[styles.sheetLabel, { color: theme.colors.muted }]}>ROOM LINK</Text>
        <Text style={[styles.link, { color: theme.colors.secondary, backgroundColor: theme.colors.soft }]}>{inviteLink}</Text>
        <View style={{ gap: 10, marginTop: 10 }}>
          <BantButton title="Copy link" onPress={copy} />
          <BantButton title="Share" variant="ghost" onPress={() => Sharing.shareAsync(inviteLink).catch(() => copy())} />
        </View>
      </BottomSheet>
      <BottomSheet visible={menuOpen} onClose={() => setMenuOpen(false)}>
        <Text style={[styles.sheetTitle, { color: theme.colors.text }]}>Room options</Text>
        <BantButton title="Report room" variant="danger" icon={<Flag size={18} color="#fff" />} onPress={() => { setMenuOpen(false); setReportOpen(true); }} />
        <BantButton title="Leave quietly" variant="ghost" onPress={leave} style={{ marginTop: 10 }} />
      </BottomSheet>
      <BottomSheet visible={reportOpen} onClose={() => setReportOpen(false)}>
        <Text style={[styles.sheetTitle, { color: theme.colors.text }]}>Report room</Text>
        <Text style={[styles.sheetLabel, { color: theme.colors.muted }]}>REASON</Text>
        <View style={styles.reportReasons}>
          {(["spam", "harassment", "unsafe", "impersonation", "other"] as const).map((reason) => (
            <Pressable key={reason} onPress={() => setReportReason(reason)} style={[styles.reasonChip, { backgroundColor: reportReason === reason ? theme.colors.blue : theme.colors.soft, borderColor: reportReason === reason ? theme.colors.blue : theme.colors.border }]}>
              <Text style={[styles.reasonText, { color: reportReason === reason ? "#fff" : theme.colors.secondary }]}>{reason}</Text>
            </Pressable>
          ))}
        </View>
        <TextInput
          value={reportDescription}
          onChangeText={setReportDescription}
          placeholder="What happened?"
          placeholderTextColor={theme.colors.muted}
          selectionColor={theme.colors.blue}
          multiline
          maxLength={1200}
          style={[styles.reportInput, { color: theme.colors.text, borderColor: theme.colors.border, backgroundColor: theme.colors.background }]}
        />
        <BantButton title="Submit report" variant="danger" loading={reporting} onPress={submitReport} style={{ marginTop: 12 }} />
      </BottomSheet>
    </SafeAreaView>
  ) : null;

  return (
    <>
      {redirectHref ? <Redirect href={redirectHref} /> : null}
      {redirectHref ? null : roomContent}
    </>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1 },
  header: { flexDirection: "row", alignItems: "center", padding: 12, gap: 10, maxWidth: 940, width: "100%", alignSelf: "center" },
  icon: { width: 40, height: 40, alignItems: "center", justifyContent: "center" },
  headerTitle: { flex: 1 },
  title: { fontFamily: "PlusJakartaSans_800ExtraBold", fontSize: 20 },
  privacy: { fontFamily: "PlusJakartaSans_600SemiBold", fontSize: 12, marginTop: 2 },
  hostBadge: { borderRadius: 999, paddingHorizontal: 8, paddingVertical: 4 },
  hostBadgeText: { fontFamily: "PlusJakartaSans_800ExtraBold", fontSize: 10 },
  content: { padding: 12, paddingBottom: 130, gap: 12, maxWidth: 940, width: "100%", alignSelf: "center" },
  intro: { borderWidth: 1, borderRadius: 22, padding: 14, gap: 8 },
  introTop: { flexDirection: "row", gap: 8, alignItems: "center", flexWrap: "wrap" },
  category: { fontFamily: "PlusJakartaSans_800ExtraBold", fontSize: 12 },
  description: { fontFamily: "PlusJakartaSans_500Medium", fontSize: 14, lineHeight: 20 },
  activity: { fontFamily: "PlusJakartaSans_800ExtraBold", fontSize: 13 },
  section: { fontFamily: "PlusJakartaSans_800ExtraBold", fontSize: 12, letterSpacing: 1.2, marginTop: 8 },
  moderationBar: { flexDirection: "row", alignItems: "center", gap: 8, flexWrap: "wrap", marginTop: 2 },
  moderationButton: { borderRadius: 999, paddingHorizontal: 14, paddingVertical: 10 },
  moderationButtonText: { fontFamily: "PlusJakartaSans_800ExtraBold", fontSize: 12 },
  participantsPanel: { borderWidth: 1, borderRadius: 24, padding: 14 },
  chatCard: { borderWidth: 1, borderRadius: 22, padding: 14, gap: 12 },
  messages: { gap: 8, minHeight: 96 },
  chatState: { minHeight: 96, alignItems: "center", justifyContent: "center", gap: 8 },
  chatStateText: { fontFamily: "PlusJakartaSans_600SemiBold", fontSize: 13, lineHeight: 18, textAlign: "center" },
  chatError: { fontFamily: "PlusJakartaSans_700Bold", fontSize: 12 },
  messageBubble: { maxWidth: "86%", borderRadius: 16, paddingHorizontal: 12, paddingVertical: 9, gap: 3 },
  messageMine: { alignSelf: "flex-end", borderBottomRightRadius: 5 },
  messageOther: { alignSelf: "flex-start", borderBottomLeftRadius: 5 },
  messageName: { fontFamily: "PlusJakartaSans_800ExtraBold", fontSize: 11 },
  messageBody: { fontFamily: "PlusJakartaSans_500Medium", fontSize: 14, lineHeight: 19 },
  composer: { minHeight: 54, borderWidth: 1, borderRadius: 18, flexDirection: "row", alignItems: "flex-end", gap: 10, padding: 8 },
  composerInput: { flex: 1, minHeight: 38, maxHeight: 92, paddingHorizontal: 8, paddingVertical: 9, fontFamily: "PlusJakartaSans_500Medium", fontSize: 14, outlineStyle: "none" as never },
  sendButton: { width: 42, height: 42, borderRadius: 14, alignItems: "center", justifyContent: "center" },
  controls: { position: "absolute", left: 12, right: 12, bottom: 14, borderWidth: 1, borderRadius: 24, padding: 10, flexDirection: "row", justifyContent: "space-between", maxWidth: 620, alignSelf: "center" },
  sheetTitle: { fontFamily: "PlusJakartaSans_800ExtraBold", fontSize: 22, marginBottom: 12 },
  sheetLabel: { fontFamily: "PlusJakartaSans_800ExtraBold", fontSize: 11, letterSpacing: 1.1, marginBottom: 4 },
  sheetActions: { gap: 10, marginTop: 12 },
  reportReasons: { flexDirection: "row", flexWrap: "wrap", gap: 8, marginBottom: 12 },
  reasonChip: { borderWidth: 1, borderRadius: 999, paddingHorizontal: 12, paddingVertical: 8 },
  reasonText: { fontFamily: "PlusJakartaSans_800ExtraBold", fontSize: 12, textTransform: "capitalize" },
  reportInput: { minHeight: 96, borderWidth: 1, borderRadius: 16, padding: 12, textAlignVertical: "top", fontFamily: "PlusJakartaSans_500Medium", fontSize: 14, outlineStyle: "none" as never },
  link: { overflow: "hidden", borderRadius: 14, padding: 12, marginTop: 12, fontFamily: "PlusJakartaSans_700Bold", fontSize: 13 }
});
