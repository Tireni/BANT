import AsyncStorage from "@react-native-async-storage/async-storage";
import * as Linking from "expo-linking";
import * as Haptics from "expo-haptics";
import { Session } from "@supabase/supabase-js";
import { Platform } from "react-native";
import { create } from "zustand";
import { googleOAuthRedirectUrl, normalizeUsername } from "@/lib/authHelpers";
import { MAX_MESH_VOICE_PARTICIPANTS, clampRoomCapacity } from "@/lib/roomLogic";
import { hasSupabaseConfig, supabase } from "@/lib/supabase";
import { Profile } from "@/types/profile";
import { Room, RoomCategory, RoomPrivacy } from "@/types/room";
import { User } from "@/types/user";

type ThemePreference = "light" | "dark" | "system";
type FriendState = "none" | "pending_sent" | "pending_received" | "friends";
type NotificationType = "friend_request" | "friend_accepted" | "room_invite" | "room" | "system";
type FriendRequestRecord = {
  id: string;
  senderId: string;
  receiverId: string;
  status: "pending" | "accepted" | "declined" | "cancelled";
};
type RoomInvite = {
  id: string;
  roomId: string;
  inviteToken: string;
  inviteeUserId: string | null;
  status: "active" | "revoked" | "used" | "expired";
  expiresAt: string | null;
};

type Persisted = {
  themePreference: ThemePreference;
};

type CreateRoomInput = {
  title: string;
  description: string;
  category: RoomCategory;
  privacy: RoomPrivacy;
  joinRule: "Everyone" | "Friends only";
  maxParticipants?: number;
  noiseControl?: boolean;
};

export type BantNotification = {
  id: string;
  actorId: string | null;
  targetId?: string | null;
  targetType?: "user" | "friend_request" | "room" | "system";
  type: NotificationType;
  body: string;
  readAt: string | null;
  createdAt: string;
};

type BantState = Persisted & {
  authenticated: boolean;
  currentUser: User | null;
  hydrated: boolean;
  session: Session | null;
  profile: Profile | null;
  authLoading: boolean;
  roomsLoading: boolean;
  peopleLoading: boolean;
  rooms: Room[];
  people: User[];
  friendIds: string[];
  incomingFriendRequests: FriendRequestRecord[];
  outgoingFriendRequests: FriendRequestRecord[];
  friendshipStates: Record<string, FriendState>;
  notifications: BantNotification[];
  toast: string | null;
  hydrate: () => Promise<void>;
  signUp: (input: { email: string; password: string; displayName: string; username: string }) => Promise<boolean>;
  signIn: (input: { email: string; password: string }) => Promise<boolean>;
  signInWithGoogle: () => Promise<void>;
  signOut: () => Promise<void>;
  saveOnboardingProfile: (input: { displayName: string; username: string; bio: string; avatarUrl?: string }) => Promise<boolean>;
  saveOnboardingInterests: (interests: string[]) => Promise<boolean>;
  finishOnboarding: () => Promise<boolean>;
  setTheme: (theme: ThemePreference) => Promise<void>;
  setToast: (message: string | null) => void;
  addFriend: (userId: string) => Promise<boolean>;
  sendFriendRequest: (userId: string) => Promise<boolean>;
  acceptFriendRequest: (userId: string) => Promise<boolean>;
  declineFriendRequest: (userId: string) => Promise<boolean>;
  cancelFriendRequest: (userId: string) => Promise<boolean>;
  friendshipState: (userId: string) => FriendState;
  friendCount: () => number;
  loadPeople: () => Promise<void>;
  updateProfile: (input: { displayName: string; username: string; bio: string }) => Promise<boolean>;
  loadNotifications: () => Promise<void>;
  markNotificationsRead: () => Promise<void>;
  loadRooms: () => Promise<void>;
  createRoom: (input: CreateRoomInput) => Promise<Room | null>;
  joinRoom: (roomId: string, role?: "speaker" | "listener") => Promise<boolean>;
  createRoomInvite: (roomId: string, inviteeId?: string | null) => Promise<RoomInvite | null>;
  revokeRoomInvite: (inviteId: string) => Promise<boolean>;
  joinRoomWithInvite: (inviteToken: string, role?: "speaker" | "listener") => Promise<string | null>;
  joinRoomWithInviteId: (inviteId: string, role?: "speaker" | "listener") => Promise<string | null>;
  leaveRoom: (roomId: string) => Promise<boolean>;
  inviteToRoom: (roomId: string, inviteeId: string) => Promise<boolean>;
  resetClientState: () => Promise<void>;
};

const STORAGE_KEY = "bant-client-preferences-v1";

const initialPersisted: Persisted = {
  themePreference: "system"
};

function buildLocalNotifications(): BantNotification[] {
  return [];
}

async function persist(state: Persisted) {
  await AsyncStorage.setItem(STORAGE_KEY, JSON.stringify(state));
}

function persisted(state: BantState): Persisted {
  return {
    themePreference: state.themePreference
  };
}

export const useBantStore = create<BantState>((set, get) => ({
  authenticated: false,
  currentUser: null,
  themePreference: initialPersisted.themePreference,
  hydrated: false,
  session: null,
  profile: null,
  authLoading: false,
  roomsLoading: false,
  peopleLoading: false,
  rooms: [],
  people: [],
  friendIds: [],
  incomingFriendRequests: [],
  outgoingFriendRequests: [],
  friendshipStates: {},
  notifications: buildLocalNotifications(),
  toast: null,
  hydrate: async () => {
    const raw = await AsyncStorage.getItem(STORAGE_KEY);
    const parsed = raw ? JSON.parse(raw) as Persisted : initialPersisted;
    set({
      themePreference: parsed.themePreference ?? "system",
      rooms: [],
      notifications: buildLocalNotifications()
    });

    if (!hasSupabaseConfig) {
      set({ authenticated: false, currentUser: null, session: null, profile: null, hydrated: true, notifications: [], rooms: [], people: [], friendIds: [], incomingFriendRequests: [], outgoingFriendRequests: [], friendshipStates: {} });
      return;
    }

    const { data } = await supabase.auth.getSession();
    if (!data.session) {
      set({ authenticated: false, currentUser: null, session: null, profile: null, hydrated: true, people: [], friendIds: [], incomingFriendRequests: [], outgoingFriendRequests: [], friendshipStates: {} });
      return;
    }

    await loadProfileIntoState(data.session, set);
    await get().loadRooms();
    await get().loadPeople();
    await get().loadNotifications();
    set({ hydrated: true });
  },
  signInWithGoogle: async () => {
    if (!hasSupabaseConfig) {
      set({ toast: "Google login requires Supabase env vars" });
      return;
    }
    set({ authLoading: true, toast: null });
    const redirectTo = googleOAuthRedirectUrl({
      platform: Platform.OS,
      origin: typeof window !== "undefined" ? window.location?.origin : undefined,
      nativeUrl: Linking.createURL("/auth/callback")
    });
    const { error } = await supabase.auth.signInWithOAuth({
      provider: "google",
      options: { redirectTo }
    });
    if (error) {
      set({ authLoading: false, toast: "Google sign-in could not be completed." });
      return;
    }
    set({ authLoading: false });
  },
  signUp: async ({ email, password, displayName, username }) => {
    if (!hasSupabaseConfig) {
      set({ toast: "Supabase env vars are missing" });
      return false;
    }
    set({ authLoading: true, toast: null });
    const { data, error } = await supabase.auth.signUp({
      email,
      password,
      options: { data: { display_name: displayName, username: normalizeUsername(username) } }
    });
    if (error) {
      set({ authLoading: false, toast: "Could not create account." });
      return false;
    }
    if (!data.session) {
      set({ authLoading: false, toast: "Check your email to confirm your account" });
      return false;
    }
    const profileResult = await ensureProfile(data.session, displayName, username);
    if (!profileResult.ok) {
      set({ authLoading: false, toast: "Account confirmed, but profile setup failed. Contact support." });
      return false;
    }
    await loadProfileIntoState(data.session, set);
    set({ authLoading: false });
    return true;
  },
  signIn: async ({ email, password }) => {
    if (!hasSupabaseConfig) {
      set({ toast: "Supabase env vars are missing" });
      return false;
    }
    set({ authLoading: true, toast: null });
    const loginEmail = email.trim().toLowerCase();
    const { data, error } = await supabase.auth.signInWithPassword({ email: loginEmail, password });
    if (error || !data.session) {
      set({ authLoading: false, toast: "Email or password is incorrect." });
      return false;
    }
    const displayName = data.user.user_metadata?.display_name ?? loginEmail.split("@")[0];
    const username = data.user.user_metadata?.username ?? loginEmail.split("@")[0];
    const profileResult = await ensureProfile(data.session, displayName, username);
    if (!profileResult.ok) {
      set({ authLoading: false, toast: "Signed in, but profile setup failed. Contact support." });
      return false;
    }
    await loadProfileIntoState(data.session, set);
    set({ authLoading: false });
    return true;
  },
  signOut: async () => {
    if (hasSupabaseConfig) await supabase.auth.signOut();
    set({ authenticated: false, currentUser: null, session: null, profile: null, rooms: [], people: [], friendIds: [], incomingFriendRequests: [], outgoingFriendRequests: [], friendshipStates: {}, notifications: [] });
    await persist(persisted(get()));
  },
  saveOnboardingProfile: async ({ displayName, username, bio, avatarUrl }: { displayName: string; username: string; bio: string; avatarUrl?: string }) => {
    const session = get().session;
    if (!hasSupabaseConfig || !session) {
      set({ toast: "Sign in first" });
      return false;
    }
    const normalized = normalizeUsername(username);
    if (!displayName.trim() || normalized.length < 3) {
      set({ toast: "Enter your name and a valid username" });
      return false;
    }
    set({ authLoading: true, toast: null });

    const profileResult = await ensureProfile(session, displayName, username);
    if (!profileResult.ok) {
      set({ authLoading: false, toast: `Profile setup failed: ${profileResult.error}` });
      return false;
    }

    const { error } = await supabase
      .from("profiles")
      .update({
        display_name: displayName.trim(),
        username: normalized,
        bio: bio.trim() || null,
        avatar_url: avatarUrl || null,
        onboarding_step: 2
      })
      .eq("id", session.user.id);
    if (error) {
      set({ authLoading: false, toast: error.message });
      return false;
    }
    await loadProfileIntoState(session, set);
    set({ authLoading: false });
    return true;
  },
  saveOnboardingInterests: async (interests) => {
    const session = get().session;
    if (!hasSupabaseConfig || !session) {
      set({ toast: "Sign in first" });
      return false;
    }
    if (interests.length < 3) {
      set({ toast: "Choose at least 3 interests" });
      return false;
    }
    set({ authLoading: true, toast: null });

    const profileResult = await ensureProfile(session, get().profile?.display_name ?? session.user.email?.split("@")[0] ?? "BANT User", get().profile?.username ?? session.user.email?.split("@")[0] ?? "bant_user");
    if (!profileResult.ok) {
      set({ authLoading: false, toast: `Profile setup failed: ${profileResult.error}` });
      return false;
    }

    const { data: interestRows, error: interestError } = await supabase
      .from("interests")
      .select("id, slug")
      .in("slug", interests);
    if (interestError) {
      set({ authLoading: false, toast: interestError.message });
      return false;
    }
    await supabase.from("user_interests").delete().eq("user_id", session.user.id);
    if (interestRows?.length) {
      const { error: linkError } = await supabase.from("user_interests").insert(interestRows.map((interest) => ({
        user_id: session.user.id,
        interest_id: interest.id
      })));
      if (linkError) {
        set({ authLoading: false, toast: linkError.message });
        return false;
      }
    }
    const { error: stepError } = await supabase.from("profiles").update({ onboarding_step: 4 }).eq("id", session.user.id);
    if (stepError) {
      set({ authLoading: false, toast: stepError.message });
      return false;
    }
    await loadProfileIntoState(session, set);
    set({ authLoading: false });
    return true;
  },
  finishOnboarding: async () => {
    const session = get().session;
    if (!hasSupabaseConfig || !session) {
      set({ toast: "Sign in first" });
      return false;
    }
    set({ authLoading: true, toast: null });
    const { error } = await supabase
      .from("profiles")
      .update({ onboarding_completed: true, onboarding_step: 4 })
      .eq("id", session.user.id);
    if (error) {
      set({ authLoading: false, toast: error.message });
      return false;
    }
    await loadProfileIntoState(session, set);
    set({ authLoading: false, toast: "Profile complete" });
    return true;
  },
  setTheme: async (themePreference) => {
    set({ themePreference, toast: "Theme changed" });
    await persist(persisted(get()));
  },
  setToast: (toast) => set({ toast }),
  addFriend: async (userId) => {
    return await get().sendFriendRequest(userId);
  },
  sendFriendRequest: async (userId) => {
    if (!hasSupabaseConfig) {
      set({ toast: "Supabase config is required to send friend requests" });
      return false;
    }
    const session = get().session;
    if (!session || !userId || userId === session.user.id) return false;
    const { error } = await supabase.rpc("send_friend_request", { p_receiver_id: userId });
    if (error) {
      set({ toast: error.message });
      return false;
    }
    await get().loadPeople();
    await get().loadNotifications();
    set({ toast: "Friend request sent" });
    void Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light).catch(() => {});
    return true;
  },
  acceptFriendRequest: async (userId) => {
    const request = get().incomingFriendRequests.find((item) => item.senderId === userId || item.id === userId);
    if (!request) {
      set({ toast: "Friend request not found" });
      return false;
    }
    const { error } = await supabase.rpc("accept_friend_request", { p_request_id: request.id });
    if (error) {
      set({ toast: error.message });
      return false;
    }
    await get().loadPeople();
    await get().loadNotifications();
    set({ toast: "Friend request accepted" });
    void Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium).catch(() => {});
    return true;
  },
  declineFriendRequest: async (userId) => {
    const request = get().incomingFriendRequests.find((item) => item.senderId === userId || item.id === userId);
    if (!request) {
      set({ toast: "Friend request not found" });
      return false;
    }
    const { error } = await supabase.rpc("decline_friend_request", { p_request_id: request.id });
    if (error) {
      set({ toast: error.message });
      return false;
    }
    await get().loadPeople();
    await get().loadNotifications();
    set({ toast: "Friend request declined" });
    return true;
  },
  cancelFriendRequest: async (userId) => {
    const request = get().outgoingFriendRequests.find((item) => item.receiverId === userId || item.id === userId);
    if (!request) {
      set({ toast: "Friend request not found" });
      return false;
    }
    const { error } = await supabase.rpc("cancel_friend_request", { p_request_id: request.id });
    if (error) {
      set({ toast: error.message });
      return false;
    }
    await get().loadPeople();
    await get().loadNotifications();
    set({ toast: "Friend request cancelled" });
    return true;
  },
  friendshipState: (userId) => {
    return get().friendshipStates[userId] ?? "none";
  },
  friendCount: () => get().friendIds.length,
  loadPeople: async () => {
    if (!hasSupabaseConfig) {
      set({ people: [], friendIds: [], incomingFriendRequests: [], outgoingFriendRequests: [], friendshipStates: {}, peopleLoading: false, toast: "Supabase config is required to load people" });
      return;
    }
    const session = get().session;
    if (!session) return;
    set({ peopleLoading: true });
    const [{ data: profiles, error: profilesError }, { data: friendships, error: friendshipsError }, { data: requests, error: requestsError }] = await Promise.all([
      supabase
        .from("profiles")
        .select("id, display_name, username, bio, avatar_url")
        .eq("onboarding_completed", true)
        .neq("id", session.user.id)
        .order("created_at", { ascending: false }),
      supabase.from("friendships").select("id, user_a, user_b").or(`user_a.eq.${session.user.id},user_b.eq.${session.user.id}`),
      supabase.from("friend_requests").select("id, sender_id, receiver_id, status").eq("status", "pending").or(`sender_id.eq.${session.user.id},receiver_id.eq.${session.user.id}`)
    ]);
    if (profilesError || friendshipsError || requestsError) {
      set({ peopleLoading: false, toast: profilesError?.message ?? friendshipsError?.message ?? requestsError?.message ?? "Unable to load people" });
      return;
    }
    const friendIds = (friendships ?? []).map((item: any) => item.user_a === session.user.id ? item.user_b : item.user_a);
    const incoming = (requests ?? []).filter((item: any) => item.receiver_id === session.user.id).map(friendRequestRow);
    const outgoing = (requests ?? []).filter((item: any) => item.sender_id === session.user.id).map(friendRequestRow);
    const friendshipStates: Record<string, FriendState> = {};
    friendIds.forEach((id) => { friendshipStates[id] = "friends"; });
    incoming.forEach((request) => { friendshipStates[request.senderId] = "pending_received"; });
    outgoing.forEach((request) => { friendshipStates[request.receiverId] = "pending_sent"; });
    set({
      people: (profiles ?? []).map((row) => profileRowToUser(row)),
      friendIds,
      incomingFriendRequests: incoming,
      outgoingFriendRequests: outgoing,
      friendshipStates,
      peopleLoading: false
    });
  },
  updateProfile: async ({ displayName, username, bio }) => {
    const session = get().session;
    if (!hasSupabaseConfig || !session) {
      set({ toast: "Sign in first" });
      return false;
    }
    const normalized = normalizeUsername(username);
    if (normalized.length < 3) {
      set({ toast: "Username must be at least 3 characters" });
      return false;
    }
    const { error } = await supabase
      .from("profiles")
      .update({
        display_name: displayName.trim(),
        username: normalized,
        bio: bio.trim() || null
      })
      .eq("id", session.user.id);
    if (error) {
      set({ toast: error.message });
      return false;
    }
    await loadProfileIntoState(session, set);
    set({ toast: "Profile updated" });
    return true;
  },
  loadNotifications: async () => {
    if (!hasSupabaseConfig) {
      set({ notifications: [], toast: "Supabase config is required to load notifications" });
      return;
    }
    const session = get().session;
    if (!session) return;
    const { data, error } = await supabase
      .from("notifications")
      .select("id, actor_id, type, body, read_at, created_at, target_id, target_type")
      .eq("user_id", session.user.id)
      .order("created_at", { ascending: false })
      .limit(30);
    if (error) {
      set({ toast: error.message });
      return;
    }
    set({ notifications: (data ?? []).map((item) => ({
      id: item.id,
        actorId: item.actor_id,
        targetId: item.target_id,
        targetType: item.target_type,
      type: item.type,
      body: item.body,
      readAt: item.read_at,
      createdAt: item.created_at
    })) });
  },
  markNotificationsRead: async () => {
    if (!hasSupabaseConfig) return;
    const session = get().session;
    if (!session) return;
    const now = new Date().toISOString();
    const { error } = await supabase.from("notifications").update({ read_at: now }).eq("user_id", session.user.id).is("read_at", null);
    if (error) {
      set({ toast: error.message });
      return;
    }
    set({ notifications: get().notifications.map((item) => ({ ...item, readAt: item.readAt ?? now })) });
  },
  loadRooms: async () => {
    if (!hasSupabaseConfig) {
      set({ rooms: [], roomsLoading: false, toast: "Supabase config is required to load rooms" });
      return;
    }
    const session = get().session;
    if (!session) {
      set({ rooms: [], roomsLoading: false });
      return;
    }
    set({ rooms: [], roomsLoading: true });
    const fullSelect = "id, title, slug, description, category, privacy, status, owner_id, host_id, max_participants, noise_control_enabled, created_at, room_members(user_id, role, left_at, is_muted, muted_by_owner, muted_at, profiles(id, display_name, username, bio, avatar_url))";
    const { data, error } = await supabase
      .from("rooms")
      .select(fullSelect)
      .eq("status", "live")
      .order("created_at", { ascending: false });
    if (error) {
      set({ rooms: [], roomsLoading: false, toast: error.message });
      return;
    }
    const liveRooms = (data ?? []).filter((row: any) => (row.status ?? "live") !== "ended");
    set({ rooms: liveRooms.map((row) => shapeRoom(row, session.user.id)), roomsLoading: false });
  },
  createRoom: async (input) => {
    const state = get();
    if (hasSupabaseConfig && state.session) {
      const baseSlug = slugify(input.title);
      const maxParticipants = clampRoomCapacity(Number(input.maxParticipants ?? 8));
      const noiseControlEnabled = Boolean(input.noiseControl);
      const basePayload = {
        title: input.title.trim(),
        slug: `${baseSlug}-${Date.now().toString(36)}`,
        description: input.description.trim() || "A fresh BANT room.",
        category: input.category,
        privacy: input.privacy,
        host_id: state.session.user.id,
        owner_id: state.session.user.id,
        status: "live"
      };
      const fullPayload = {
        ...basePayload,
        max_participants: maxParticipants,
        noise_control_enabled: noiseControlEnabled
      };
      const fullSelect = "id, title, slug, description, category, privacy, status, owner_id, host_id, max_participants, noise_control_enabled, created_at, room_members(user_id, role, left_at, is_muted, muted_by_owner, muted_at, profiles(id, display_name, username, bio, avatar_url))";
      const { data, error } = await supabase
        .from("rooms")
        .insert(fullPayload)
        .select(fullSelect)
        .single();
      if (error || !data) {
        set({ toast: error?.message ?? "Unable to create room" });
        return null;
      }
      await get().loadRooms();
      const room = get().rooms.find((item) => item.id === data.id) ?? shapeRoom(data, state.session.user.id);
      set({ toast: "Room created" });
      void Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success).catch(() => {});
      return room;
    }

    set({ toast: "Supabase config is required to create rooms" });
    return null;
  },
  joinRoom: async (roomId, role = "listener") => {
    if (!hasSupabaseConfig) {
      set({ toast: "Supabase config is required to join rooms" });
      return false;
    }
    const session = get().session;
    if (!session) {
      set({ toast: "Sign in first" });
      return false;
    }
    const { error } = await supabase.rpc("join_room", {
      p_room_id: roomId,
      p_role: role
    });
    if (error) {
      set({ toast: error.message });
      return false;
    }
    await get().loadRooms();
    return true;
  },
  createRoomInvite: async (roomId, inviteeId = null) => {
    if (!hasSupabaseConfig) {
      set({ toast: "Supabase config is required to create invites" });
      return null;
    }
    if (!get().session) {
      set({ toast: "Sign in first" });
      return null;
    }
    const { data, error } = await supabase.rpc("create_room_invite", {
      p_room_id: roomId,
      p_invitee_user_id: inviteeId,
      p_expires_at: null
    });
    if (error || !data) {
      set({ toast: roomInviteMessage(error?.message) });
      return null;
    }
    const invite = roomInviteRow(data);
    set({ toast: inviteeId ? "Invite sent" : "Invite ready" });
    return invite;
  },
  revokeRoomInvite: async (inviteId) => {
    if (!hasSupabaseConfig) {
      set({ toast: "Supabase config is required to revoke invites" });
      return false;
    }
    const { error } = await supabase.rpc("revoke_room_invite", { p_invite_id: inviteId });
    if (error) {
      set({ toast: roomInviteMessage(error.message) });
      return false;
    }
    set({ toast: "Invite revoked" });
    return true;
  },
  joinRoomWithInvite: async (inviteToken, role = "listener") => {
    if (!hasSupabaseConfig) {
      set({ toast: "Supabase config is required to join rooms" });
      return null;
    }
    const session = get().session;
    if (!session) {
      set({ toast: "Sign in first" });
      return null;
    }
    const { data, error } = await supabase.rpc("join_private_room_with_invite", {
      p_invite_token: inviteToken,
      p_role: role
    });
    if (error || !data) {
      set({ toast: roomInviteMessage(error?.message) });
      return null;
    }
    await get().loadRooms();
    const member = Array.isArray(data) ? data[0] : data;
    set({ toast: "Joined room" });
    return member?.room_id ?? null;
  },
  joinRoomWithInviteId: async (inviteId, role = "listener") => {
    if (!hasSupabaseConfig) {
      set({ toast: "Supabase config is required to join rooms" });
      return null;
    }
    if (!get().session) {
      set({ toast: "Sign in first" });
      return null;
    }
    const { data, error } = await supabase.rpc("join_private_room_with_invite_id", {
      p_invite_id: inviteId,
      p_role: role
    });
    if (error || !data) {
      set({ toast: roomInviteMessage(error?.message) });
      return null;
    }
    await get().loadRooms();
    const member = Array.isArray(data) ? data[0] : data;
    set({ toast: "Joined room" });
    return member?.room_id ?? null;
  },
  leaveRoom: async (roomId) => {
    if (!hasSupabaseConfig) {
      set({ toast: "Supabase config is required to leave rooms" });
      return false;
    }
    const session = get().session;
    if (!session) return false;
    const room = get().rooms.find((item) => item.id === roomId);

    const { error: leaveError } = await supabase
      .from("room_members")
      .update({ left_at: new Date().toISOString() })
      .eq("room_id", roomId)
      .eq("user_id", session.user.id);
    if (leaveError) {
      set({ toast: leaveError.message });
      return false;
    }

    const { data: remainingMembers } = await supabase
      .from("room_members")
      .select("user_id")
      .eq("room_id", roomId)
      .is("left_at", null);

    if ((remainingMembers ?? []).length === 0) {
      set({ rooms: get().rooms.filter((item) => item.id !== roomId) });
      set({ toast: "Room closed because it was empty" });
      await get().loadRooms();
      return true;
    }

    if (room?.ownerId === session.user.id) {
      const { error: endError } = await supabase
        .from("rooms")
        .update({ status: "ended", ended_at: new Date().toISOString() })
        .eq("id", roomId);
      if (endError) {
        set({ toast: endError.message });
        return false;
      }
    }

    await get().loadRooms();
    set({ toast: room?.ownerId === session.user.id ? "Room ended" : "Left room" });
    return true;
  },
  inviteToRoom: async (roomId, inviteeId) => {
    if (!roomId || !inviteeId) return false;
    const invite = await get().createRoomInvite(roomId, inviteeId);
    return Boolean(invite);
  },
  resetClientState: async () => {
    await AsyncStorage.removeItem(STORAGE_KEY);
    if (hasSupabaseConfig) await supabase.auth.signOut();
    set({ authenticated: false, currentUser: null, themePreference: "system", hydrated: true, session: null, profile: null, authLoading: false, roomsLoading: false, peopleLoading: false, rooms: [], people: [], friendIds: [], incomingFriendRequests: [], outgoingFriendRequests: [], friendshipStates: {}, notifications: [], toast: "Client state reset" });
  }
}));

function slugify(value: string) {
  return value.toLowerCase().trim().replace(/[^a-z0-9]+/g, "-").replace(/(^-|-$)/g, "") || "room";
}

function avatarColorFor(username: string) {
  const colors = ["#0E96F6", "#43D88B", "#8B5CF6", "#F79009", "#F04438"];
  return colors[username.length % colors.length];
}

async function ensureProfile(session: Session, displayName: string, username: string): Promise<{ ok: boolean; error?: string }> {
  const normalized = normalizeUsername(username || session.user.email?.split("@")[0] || "bant_user");
  const { data: existing, error: lookupError } = await supabase
    .from("profiles")
    .select("id")
    .eq("id", session.user.id)
    .maybeSingle();
  if (!lookupError && existing) return { ok: true };

  const { error: rpcError } = await supabase.rpc("ensure_profile", {
    p_display_name: displayName.trim() || session.user.email?.split("@")[0] || "BANT User",
    p_username: normalized
  });
  if (!rpcError) return { ok: true };
  if (!rpcError.message.toLowerCase().includes("function") && !rpcError.message.toLowerCase().includes("schema cache")) {
    return { ok: false, error: rpcError.message };
  }

  const baseUsername = (normalized.length >= 3 ? normalized : `user_${session.user.id.slice(0, 6)}`).slice(0, 19);
  const safeUsername = `${baseUsername}_${session.user.id.slice(0, 4)}`;
  const { error } = await supabase.from("profiles").insert({
    id: session.user.id,
    display_name: displayName.trim() || "BANT User",
    username: safeUsername,
    onboarding_completed: false,
    onboarding_step: 1
  });
  if (error) {
    return { ok: false, error: error.message || lookupError?.message || "Unknown database error" };
  }
  return { ok: true };
}

async function loadProfileIntoState(session: Session, set: (partial: Partial<BantState>) => void) {
  const { data: profile } = await supabase
    .from("profiles")
    .select("id, display_name, username, university_id, bio, avatar_url, onboarding_completed, onboarding_step, user_status, occupation_category, occupation_custom, institution_source, created_at, updated_at")
    .eq("id", session.user.id)
    .maybeSingle();

  const currentUser: User | null = profile ? {
    id: profile.id,
    name: profile.display_name,
    username: profile.username,
    avatarColor: avatarColorFor(profile.username),
    avatar_url: profile.avatar_url,
    bio: profile.bio ?? "",
    online: true
  } : null;
  const shapedProfile: Profile | null = profile ? {
    id: profile.id,
    display_name: profile.display_name,
    username: profile.username,
    university_id: profile.university_id,
    university_name: null,
    university_short_name: null,
    bio: profile.bio,
    avatar_url: profile.avatar_url,
    onboarding_completed: profile.onboarding_completed,
    onboarding_step: profile.onboarding_step ?? 1,
    user_status: profile.user_status,
    occupation_category: profile.occupation_category,
    occupation_custom: profile.occupation_custom,
    institution_source: profile.institution_source,
    created_at: profile.created_at,
    updated_at: profile.updated_at
  } : null;
  set({ authenticated: Boolean(session), session, profile: shapedProfile, currentUser });
}

function shapeRoom(row: any, currentUserId: string): Room {
  const activeMembers = ((row.room_members ?? []) as any[]).filter((member) => !member.left_at);
  const users: { role: "owner" | "host" | "speaker" | "listener"; user: User }[] = [];
  activeMembers.forEach((member) => {
    const profile = Array.isArray(member.profiles) ? member.profiles[0] : member.profiles;
    const user = profileToUser(profile);
    if (!user) return;
    users.push({
      role: member.role as "owner" | "host" | "speaker" | "listener",
      user
    });
  });
  const speakers = users.filter((member) => member.role === "owner" || member.role === "host" || member.role === "speaker").map((member) => member.user);
  const listeners = users.filter((member) => member.role === "listener").map((member) => member.user);
  const currentMember = activeMembers.find((member) => member.user_id === currentUserId);
  const mutedUserIds = activeMembers.filter((member) => Boolean(member.is_muted)).map((member) => member.user_id);
  return {
    id: row.id,
    title: row.title,
    slug: row.slug,
    description: row.description || "A fresh BANT room.",
    category: row.category as RoomCategory,
    privacy: row.privacy as RoomPrivacy,
    speakerIds: speakers.map((user) => user.id),
    listenerIds: listeners.map((user) => user.id),
    participantCount: activeMembers.length,
    maxParticipants: Number(row.max_participants ?? Math.max(activeMembers.length, MAX_MESH_VOICE_PARTICIPANTS)),
    noiseControlEnabled: Boolean(row.noise_control_enabled),
    isLive: row.status === "live",
    ownerId: row.owner_id ?? row.host_id,
    speakers,
    listeners,
    currentUserRole: currentMember?.role,
    mutedUserIds,
    currentUserAdminMuted: Boolean(currentMember?.is_muted)
  };
}

function profileToUser(profile: any): User | null {
  if (!profile) return null;
  return {
    id: profile.id,
    name: profile.display_name,
    username: profile.username,
    avatarColor: avatarColorFor(profile.username ?? profile.id),
    avatar_url: profile.avatar_url ?? null,
    bio: profile.bio ?? "",
    online: true
  };
}

function profileRowToUser(row: any): User {
  return {
    id: row.id,
    name: row.display_name,
    username: row.username,
    avatarColor: avatarColorFor(row.username ?? row.id),
    avatar_url: row.avatar_url ?? null,
    bio: row.bio ?? "",
    online: true
  };
}

function friendRequestRow(row: any): FriendRequestRecord {
  return {
    id: row.id,
    senderId: row.sender_id,
    receiverId: row.receiver_id,
    status: row.status
  };
}

function roomInviteRow(row: any): RoomInvite {
  return {
    id: row.id,
    roomId: row.room_id,
    inviteToken: row.invite_token,
    inviteeUserId: row.invitee_user_id ?? null,
    status: row.status,
    expiresAt: row.expires_at ?? null
  };
}

function roomInviteMessage(message?: string) {
  const value = (message ?? "").toLowerCase();
  if (value.includes("full")) return "Room is full.";
  if (value.includes("ended") || value.includes("not live")) return "This room has ended.";
  if (value.includes("expired")) return "Invite has expired.";
  if (value.includes("access") || value.includes("private")) return "You don't have access to this room.";
  if (value.includes("owner")) return "Only the room owner can manage invites.";
  if (value.includes("auth")) return "Sign in first.";
  return "Invite is invalid.";
}
