import { FlatList, Pressable, StyleSheet, Text, View, useWindowDimensions } from "react-native";
import { Mic, MicOff } from "lucide-react-native";
import { BantAvatar } from "@/components/common/BantAvatar";
import { useTheme } from "@/hooks/useTheme";
import { User } from "@/types/user";

export function ParticipantGrid({
  users,
  selectedUserIds = [],
  moderationMode = false,
  onToggleUser,
  roomOwnerId,
  currentUserId,
  onWarnSelected,
  noiseControlEnabled = false,
  mutedUserIds = [],
  connectedVoiceUserIds = []
}: {
  users: User[];
  selectedUserIds?: string[];
  moderationMode?: boolean;
  onToggleUser?: (userId: string) => void;
  roomOwnerId?: string;
  currentUserId?: string;
  onWarnSelected?: () => void;
  noiseControlEnabled?: boolean;
  mutedUserIds?: string[];
  connectedVoiceUserIds?: string[];
}) {
  const theme = useTheme();
  const isOwner = Boolean(roomOwnerId && currentUserId && roomOwnerId === currentUserId);
  const { width } = useWindowDimensions();
  const columns = width >= 900 ? 5 : width >= 700 ? 4 : 3;

  return (
    <View style={styles.wrap}>
      {isOwner && moderationMode && noiseControlEnabled && selectedUserIds.length > 0 ? (
        <Pressable onPress={onWarnSelected} style={[styles.warnButton, { backgroundColor: theme.colors.warning }]}>
          <Text style={[styles.warnButtonText, { color: "#fff" }]}>Warn Selected</Text>
        </Pressable>
      ) : null}
      <FlatList
        data={users}
        key={columns}
        keyExtractor={(user) => user.id}
        numColumns={columns}
        scrollEnabled={users.length > 15}
        nestedScrollEnabled
        style={styles.list}
        initialNumToRender={24}
        maxToRenderPerBatch={24}
        windowSize={5}
        columnWrapperStyle={styles.row}
        renderItem={({ item: user }) => {
          const active = selectedUserIds.includes(user.id);
          const selectable = isOwner && moderationMode && user.id !== roomOwnerId;
          const muted = mutedUserIds.includes(user.id);
          const voiceConnected = connectedVoiceUserIds.includes(user.id);
          const isHost = roomOwnerId === user.id;
          return (
            <Pressable
              onPress={() => selectable ? onToggleUser?.(user.id) : undefined}
              style={[
                styles.item,
                { flexBasis: `${100 / columns}%` },
                selectable && active && { borderColor: theme.colors.warning, borderWidth: 2, backgroundColor: theme.colors.soft },
                selectable && { borderColor: theme.colors.border },
                !selectable && { borderColor: "transparent" }
              ]}
            >
              <View style={styles.avatarWrap}>
                <BantAvatar user={user} size={62} />
                {selectable ? (
                  <View style={[styles.check, { backgroundColor: active ? theme.colors.warning : theme.colors.soft, borderColor: active ? theme.colors.warning : theme.colors.border }]}>
                    <Text style={styles.checkText}>{active ? "OK" : ""}</Text>
                  </View>
                ) : null}
              </View>
              <View style={styles.nameRow}>
                <Text style={[styles.name, { color: theme.colors.text }]} numberOfLines={1}>{user.name.split(" ")[0]}</Text>
                {isHost ? <Text style={[styles.badge, { color: theme.colors.warning, backgroundColor: theme.colors.soft }]}>HOST</Text> : null}
              </View>
              <View style={styles.metaRow}>
                <Text style={[styles.role, { color: theme.colors.secondary }]}>
                  {muted ? "muted" : voiceConnected ? "voice connected" : "not connected"}
                </Text>
                {muted
                  ? <MicOff size={12} color={theme.colors.danger} />
                  : <Mic size={12} color={voiceConnected ? theme.colors.mint : theme.colors.muted} />}
              </View>
            </Pressable>
          );
        }}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: { width: "100%" },
  list: { maxHeight: 520 },
  row: { alignItems: "stretch" },
  item: { alignItems: "center", gap: 8, paddingVertical: 12, paddingHorizontal: 8, borderRadius: 18, borderWidth: 1, backgroundColor: "rgba(0,0,0,0.04)" },
  avatarWrap: { position: "relative" },
  check: { position: "absolute", right: -4, top: -4, width: 18, height: 18, borderRadius: 9, justifyContent: "center", alignItems: "center", borderWidth: 1 },
  checkText: { fontFamily: "PlusJakartaSans_800ExtraBold", fontSize: 10, color: "#fff" },
  nameRow: { flexDirection: "row", alignItems: "center", justifyContent: "center", gap: 6, flexWrap: "wrap" },
  name: { fontFamily: "PlusJakartaSans_700Bold", fontSize: 12 },
  badge: { overflow: "hidden", borderRadius: 999, paddingHorizontal: 6, paddingVertical: 2, fontFamily: "PlusJakartaSans_800ExtraBold", fontSize: 9 },
  metaRow: { flexDirection: "row", alignItems: "center", gap: 4 },
  role: { fontFamily: "PlusJakartaSans_700Bold", fontSize: 10, textTransform: "lowercase" },
  warnButton: { alignSelf: "flex-start", borderRadius: 999, paddingHorizontal: 14, paddingVertical: 8, marginBottom: 12 },
  warnButtonText: { fontFamily: "PlusJakartaSans_800ExtraBold", fontSize: 12 }
});
