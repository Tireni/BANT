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
import { NoiseWarningOverlay } from "@/components/room/NoiseWarningOverlay";
import { UserRow } from "@/components/friends/UserRow";
import { useRoomChat } from "@/hooks/useRoomChat";
import { useRoomSimulation } from "@/hooks/useRoomSimulation";
import { useLiveRoomAudio } from "@/hooks/useLiveRoomAudio";
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
  const friendshipState = useBantStore((state) => state.friendshipState);
  const sendFriendRequest = useBantStore((state) => state.sendFriendRequest);
  const acceptFriendRequest = useBantStore((state) => state.acceptFriendRequest);
  const cancelFriendRequest = useBantStore((state) => state.cancelFriendRequest);
  const createRoomInvite = useBantStore((state) => state.createRoomInvite);
  const setToast = useBantStore((state) => state.setToast);
  const joinRoom = useBantStore((state) => state.joinRoom);
  const leaveRoom = useBantStore((state) => state.leaveRoom);
  const loadRoom = useBantStore((state) => state.loadRoom);
  const room = rooms.find((item) => item.id === id);
  const { activeSpeakerId, participantCount, activity } = useRoomSimulation(room);
  const [handRaised, setHandRaised] = useState(false);
  const [peopleOpen, setPeopleOpen] = useState(false);
  const [inviteOpen, setInviteOpen] = useState(false);
  const [inviteLink, setInviteLink] = useState("");
  const [creatingInvite, setCreatingInvite] = useState(false);
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
  const voice = useLiveRoomAudio({ roomId: room?.id, adminMuted: Boolean(room?.currentUserAdminMuted) });
  const chat = useRoomChat(room?.id, profile?.id);
  useEffect(() => {
    if (!room || !profile?.id) return;
    if (room.currentUserRole) {
      if (voice.status === "idle" && voice.supported) {
        void voice.start();
      }
      return;
    }
    void joinRoom(room.id, "speaker").then((joined) => {
      if (joined && voice.supported) {
        void loadRoom(room.id);
        void voice.start();
      }
    });
  }, [joinRoom, loadRoom, profile?.id, room, voice.start, voice.status, voice.supported]);
  useEffect(() => {
    if (!hasSupabaseConfig || !room?.id) return;
    const channel = supabase
      .channel(`room-members:${room.id}`)
      .on("postgres_changes", { event: "*", schema: "public", table: "room_members", filter: `room_id=eq.${room.id}` }, () => {
        void loadRoom(room.id);
      })
      .subscribe();
    return () => {
      void supabase.removeChannel(channel);
    };
  }, [loadRoom, room?.id]);
  useEffect(() => {
    if (!hasSupabaseConfig || !room?.id) return;
    const channel = supabase
      .channel(`room:${room.id}`)
      .on("postgres_changes", { event: "UPDATE", schema: "public", table: "rooms", filter: `id=eq.${room.id}` }, (payload) => {
        const next = payload.new as { status?: string };
        if (next.status === "ended") {
          voice.stop();
          setToast("Room ended");
          router.replace("/(tabs)/rooms");
          return;
        }
        void loadRoom(room.id);
      })
      .subscribe();
    return () => {
      void supabase.removeChannel(channel);
    };
  }, [loadRoom, room?.id, setToast, voice.stop]);
  const redirectHref = !authenticated ? "/auth/welcome" : !profile?.onboarding_completed ? (onboardingRoute(profile) as any) : null;
  const generateInvite = async () => {
    if (!room) return;
    setCreatingInvite(true);
    const invite = await createRoomInvite(room.id);
    setCreatingInvite(false);
    if (invite) setInviteLink(inviteUrlForToken(invite.inviteToken));
  };
  const copy = async () => {
    if (!inviteLink) {
      await generateInvite();
      return;
    }
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
  const isOwner = Boolean(profile && room && (room.ownerId === profile.id || room.currentUserRole === "owner" || room.currentUserRole === "host"));

  const friendActionFor = (userId: string) => {
    const state = friendshipState(userId);
    return {
      label: state === "friends" ? "Friends" : state === "pending_received" ? "Accept" : state === "pending_sent" ? "Request sent" : "Add friend",
      press: () => {
        if (state === "friends") return;
        if (state === "pending_received") void acceptFriendRequest(userId);
        else if (state === "pending_sent") void cancelFriendRequest(userId);
        else void sendFriendRequest(userId);
      }
    };
  };

  const sendWarning = async (targetUserIds?: string[]) => {
    if (!hasSupabaseConfig || !profile?.id || !room?.id) return;
    const { error } = await supabase.rpc("send_room_warning", {
      p_room_id: room.id,
      p_target_user_ids: targetUserIds && targetUserIds.length ? targetUserIds : null
    });
    if (error) {
      setToast(moderationMessage(error.message));
      return;
    }
    setSelectedUserIds([]);
    setModerationMode(false);
    setModerationAction(null);
  };

  const warnSelected = async () => {
    if (!selectedUserIds.length) return;
    await sendWarning(selectedUserIds);
  };

  const moderateParticipants = async (action: "mute" | "unmute", targetUserIds?: string[]) => {
    if (!room || !profile?.id || !hasSupabaseConfig) return;
    const isOwner = room.ownerId === profile.id;
    if (!isOwner) return;
    const ids = (targetUserIds && targetUserIds.length ? targetUserIds : allParticipants.map((user) => user.id).filter((userId) => userId !== room.ownerId)).filter(Boolean);
    if (!ids.length) return;
    const { error } = await supabase.rpc("moderate_room_members", {
      p_room_id: room.id,
      p_target_user_ids: ids,
      p_action: action
    });
    if (error) {
      setToast(moderationMessage(error.message));
      return;
    }
    await loadRoom(room.id);
    setSelectedUserIds([]);
    setModerationMode(false);
    setModerationAction(null);
    setToast(action === "mute" ? "Participants muted" : "Participants released");
  };

  const moderateAllParticipants = async (action: "mute" | "unmute") => {
    if (!room || !profile?.id || !hasSupabaseConfig) return;
    const { error } = await supabase.rpc("moderate_room_all_members", {
      p_room_id: room.id,
      p_action: action
    });
    if (error) {
      setToast(moderationMessage(error.message));
      return;
    }
    await loadRoom(room.id);
    setSelectedUserIds([]);
    setModerationMode(false);
    setModerationAction(null);
    setToast(action === "mute" ? "Participants muted" : "Participants released");
  };

  const endRoom = async () => {
    if (!hasSupabaseConfig || !profile?.id || !room?.id) return;
    const { error } = await supabase.rpc("end_room", { p_room_id: room.id });
    if (error) {
      setToast(moderationMessage(error.message));
      return;
    }
    voice.stop();
    router.replace("/(tabs)/rooms");
  };

  const roomContent = room ? (
    <SafeAreaView style={[styles.screen, { backgroundColor: theme.colors.background }]} edges={["top"]}>
      <NoiseWarningOverlay roomId={room?.id} currentUserId={profile?.id} />
      <View style={styles.header}>
        <Pressable onPress={() => isOwner ? setMenuOpen(true) : void leave()} style={styles.icon}><ArrowLeft color={theme.colors.text} size={24} /></Pressable>
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
            {voice.status === "connected" ? `LiveKit audio live${voice.remoteCount ? ` · ${voice.remoteCount} media connected` : ""}` : voice.error ?? "LiveKit audio is ready after room access is confirmed."}
          </Text>
        </View>

        {isOwner ? (
          <View style={styles.moderationBar}>
            <Pressable onPress={() => setModerationMode((value) => !value)} style={[styles.moderationButton, { backgroundColor: moderationMode ? theme.colors.warning : theme.colors.soft }]}>
              <Text style={[styles.moderationButtonText, { color: moderationMode ? "#fff" : theme.colors.text }]}>Moderate</Text>
            </Pressable>
            {room.noiseControlEnabled ? <Pressable onPress={() => sendWarning()} style={[styles.moderationButton, { backgroundColor: theme.colors.warning }]}>
              <Text style={[styles.moderationButtonText, { color: "#fff" }]}>Warn Everyone 🤫</Text>
            </Pressable> : null}
          </View>
        ) : null}

        <View style={[styles.participantsPanel, { backgroundColor: theme.colors.surface, borderColor: theme.colors.border }]}>
          <Text style={[styles.section, { color: theme.colors.muted }]}>ROOM</Text>
          <ParticipantGrid
            users={allParticipants}
            selectedUserIds={selectedUserIds}
            onToggleUser={(userId) => {
              if (!moderationMode) return;
              if (userId === room.ownerId) return;
              setSelectedUserIds((current) => current.includes(userId) ? current.filter((id) => id !== userId) : [...current, userId]);
            }}
            moderationMode={moderationMode}
            roomOwnerId={room.ownerId}
            currentUserId={profile?.id}
            onWarnSelected={warnSelected}
            noiseControlEnabled={Boolean(room.noiseControlEnabled)}
            mutedUserIds={room.mutedUserIds ?? []}
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
            <RoomControlButton label={voice.adminMuted ? "Host Muted" : voiceLabel} active={voice.status === "connected"} onPress={toggleVoice} icon={voice.muted ? <MicOff size={20} color={voice.adminMuted ? theme.colors.danger : theme.colors.blue} /> : <Mic size={20} color={voice.status === "connected" ? theme.colors.blue : theme.colors.text} />} />
            <RoomControlButton label="Mute" active={false} onPress={() => { setModerationAction("mute"); setModerationMode(true); setSelectedUserIds([]); }} icon={<MicOff size={20} color={theme.colors.text} />} />
            <RoomControlButton label="Moderate" active={moderationMode} onPress={() => { setModerationAction("mute"); setModerationMode(true); setSelectedUserIds([]); }} icon={<Users size={20} color={theme.colors.text} />} />
            {room.noiseControlEnabled ? <RoomControlButton label="Noise 🤫" active={moderationAction === "warn"} onPress={() => { setModerationAction("warn"); setModerationMode(true); setSelectedUserIds([]); }} icon={<Volume2 size={20} color={theme.colors.warning} />} /> : null}
            <RoomControlButton label="End Room" danger onPress={endRoom} icon={<X size={20} color={theme.colors.danger} />} />
          </>
        ) : (
          <>
            <RoomControlButton label={voice.adminMuted ? "Host Muted" : voiceLabel} active={voice.status === "connected"} onPress={toggleVoice} icon={voice.muted ? <MicOff size={20} color={voice.adminMuted ? theme.colors.danger : theme.colors.blue} /> : <Mic size={20} color={voice.status === "connected" ? theme.colors.blue : theme.colors.text} />} />
            <RoomControlButton label="Leave" danger onPress={leave} icon={<X size={20} color={theme.colors.danger} />} />
          </>
        )}
      </View>
      <BottomSheet visible={moderationMode && isOwner && !!moderationAction} onClose={() => { setModerationMode(false); setModerationAction(null); setSelectedUserIds([]); }}>
        <Text style={[styles.sheetTitle, { color: theme.colors.text }]}>{moderationAction === "warn" ? "Noise Control" : "Moderation"}</Text>
        <Text style={[styles.sheetLabel, { color: theme.colors.muted }]}>SELECTED: {selectedUserIds.length}</Text>
        {moderationAction === "mute" ? (
          <View style={styles.sheetActions}>
            <BantButton title={selectedUserIds.length ? "Mute Selected" : "Mute All"} onPress={() => selectedUserIds.length ? void moderateParticipants("mute", selectedUserIds) : void moderateAllParticipants("mute")} />
            <BantButton title={selectedUserIds.length ? "Release Selected" : "Release All"} variant="ghost" onPress={() => selectedUserIds.length ? void moderateParticipants("unmute", selectedUserIds) : void moderateAllParticipants("unmute")} />
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
            const action = friendActionFor(user.id);
            return <UserRow key={user.id} user={user} action={action.label} onPress={action.press} />;
          })}
          <Text style={[styles.sheetLabel, { color: theme.colors.muted, marginTop: 16 }]}>LISTENERS</Text>
          {listeners.map((user) => {
            const action = friendActionFor(user.id);
            return <UserRow key={user.id} user={user} action={action.label} onPress={action.press} />;
          })}
        </ScrollView>
      </BottomSheet>
      <BottomSheet visible={inviteOpen} onClose={() => setInviteOpen(false)}>
        <Text style={[styles.sheetTitle, { color: theme.colors.text }]}>Invite people</Text>
        <Text style={[styles.sheetLabel, { color: theme.colors.muted }]}>ROOM LINK</Text>
        <Text style={[styles.link, { color: theme.colors.secondary, backgroundColor: theme.colors.soft }]}>{inviteLink || "Generate a secure invite link for this room."}</Text>
        <View style={{ gap: 10, marginTop: 10 }}>
          <BantButton title={inviteLink ? "Copy link" : "Generate invite link"} onPress={copy} loading={creatingInvite} />
          <BantButton title="Share" variant="ghost" disabled={!inviteLink} onPress={() => Sharing.shareAsync(inviteLink).catch(() => copy())} />
        </View>
      </BottomSheet>
      <BottomSheet visible={menuOpen} onClose={() => setMenuOpen(false)}>
        <Text style={[styles.sheetTitle, { color: theme.colors.text }]}>Room options</Text>
        <BantButton title="Report room" variant="danger" icon={<Flag size={18} color="#fff" />} onPress={() => { setMenuOpen(false); setReportOpen(true); }} />
        {isOwner ? <BantButton title="End room" variant="danger" onPress={endRoom} style={{ marginTop: 10 }} /> : <BantButton title="Leave quietly" variant="ghost" onPress={leave} style={{ marginTop: 10 }} />}
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

function inviteUrlForToken(token: string) {
  if (typeof window !== "undefined" && window.location?.origin) return `${window.location.origin}/invite/${token}`;
  return `https://bant.app/invite/${token}`;
}

function moderationMessage(message?: string) {
  const value = (message ?? "").toLowerCase();
  if (value.includes("owner")) return "Only the room owner can do that.";
  if (value.includes("noise")) return "Noise Control is not enabled.";
  if (value.includes("full")) return "Room is full.";
  if (value.includes("ended") || value.includes("live")) return "This room has ended.";
  if (value.includes("auth")) return "Sign in first.";
  return "Unable to complete moderation action.";
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
