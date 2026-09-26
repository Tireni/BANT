import AsyncStorage from "@react-native-async-storage/async-storage";
import * as Haptics from "expo-haptics";
import { Session } from "@supabase/supabase-js";
import { create } from "zustand";
import { hasSupabaseConfig, supabase } from "@/lib/supabase";
import { Profile } from "@/types/profile";
import { Room, RoomCategory, RoomPrivacy } from "@/types/room";
import { User } from "@/types/user";
import { University } from "@/types/university";

type ThemePreference = "light" | "dark" | "system";
type FriendState = "none" | "pending_sent" | "pending_received" | "friends";
type NotificationType = "friend_request" | "friend_accepted" | "room_invite" | "room" | "system";

type Persisted = {
  authenticated: boolean;
  currentUser: User | null;
  selectedUniversity: University | null;
  friends: string[];
  friendRequests: string[];
  outgoingFriendRequests: string[];
  createdRooms: Room[];
  themePreference: ThemePreference;
  roomInvites: Record<string, string[]>;
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
  targetType?: "user" | "room" | "system";
  type: NotificationType;
  body: string;
  readAt: string | null;
  createdAt: string;
};

type BantState = Persisted & {
  hydrated: boolean;
  session: Session | null;
  profile: Profile | null;
  authLoading: boolean;
  roomsLoading: boolean;
  peopleLoading: boolean;
  rooms: Room[];
  people: User[];
  followingIds: string[];
  notifications: BantNotification[];
  toast: string | null;
  hydrate: () => Promise<void>;
  signUp: (input: { email: string; password: string; displayName: string; username: string }) => Promise<boolean>;
  signIn: (input: { email: string; password: string }) => Promise<boolean>;
  signInWithGoogle: () => Promise<void>;
  signOut: () => Promise<void>;
  completeOnboarding: (input: { university: University; interests: string[]; displayName: string; username: string; bio?: string }) => Promise<boolean>;
  saveOnboardingProfile: (input: { displayName: string; username: string; bio: string; avatarUrl?: string }) => Promise<boolean>;
  saveOnboardingInterests: (interests: string[]) => Promise<boolean>;
  finishOnboarding: () => Promise<boolean>;
  selectUniversity: (university: University) => Promise<void>;
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
  followUser: (userId: string) => Promise<void>;
  unfollowUser: (userId: string) => Promise<void>;
  updateProfile: (input: { displayName: string; username: string; bio: string }) => Promise<boolean>;
  loadNotifications: () => Promise<void>;
  markNotificationsRead: () => Promise<void>;
  loadRooms: () => Promise<void>;
  createRoom: (input: CreateRoomInput) => Promise<Room | null>;
  joinRoom: (roomId: string, role?: "speaker" | "listener") => Promise<boolean>;
  leaveRoom: (roomId: string) => Promise<boolean>;
  inviteToRoom: (roomId: string, inviteeId: string) => Promise<boolean>;
  roomAccessAllowed: (roomId: string, userId: string) => boolean;
  resetDemo: () => Promise<void>;
};

const STORAGE_KEY = "bant-demo-state-v1";

const defaultUser: User = {
  id: "u1",
  name: "Alex Johnson",
  username: "alexj",
  university: "University of Lagos",
  avatarColor: "#0E96F6",
  bio: "Computer Science. Afrobeats. Football. Always down for random gist.",
  online: true
};

const initialPersisted: Persisted = {
  authenticated: false,
  currentUser: null,
  selectedUniversity: null,
  friends: [],
  friendRequests: [],
  outgoingFriendRequests: [],
  createdRooms: [],
  themePreference: "system",
  roomInvites: {}
};

function buildLocalNotifications(): BantNotification[] {
  return [];
}

async function persist(state: Persisted) {
  await AsyncStorage.setItem(STORAGE_KEY, JSON.stringify(state));
}

function persisted(state: BantState): Persisted {
  return {
    authenticated: state.authenticated,
    currentUser: state.currentUser,
    selectedUniversity: state.selectedUniversity,
    friends: state.friends,
    friendRequests: state.friendRequests,
    outgoingFriendRequests: state.outgoingFriendRequests,
    createdRooms: state.createdRooms,
    themePreference: state.themePreference,
    roomInvites: state.roomInvites
  };
}

export const useBantStore = create<BantState>((set, get) => ({
  ...initialPersisted,
  hydrated: false,
  session: null,
  profile: null,
  authLoading: false,
  roomsLoading: false,
  peopleLoading: false,
  rooms: [],
  people: [],
  followingIds: initialPersisted.friends,
  notifications: buildLocalNotifications(),
  toast: null,
  outgoingFriendRequests: initialPersisted.outgoingFriendRequests,
  roomInvites: initialPersisted.roomInvites,
  hydrate: async () => {
    const raw = await AsyncStorage.getItem(STORAGE_KEY);
    const parsed = raw ? JSON.parse(raw) as Persisted : initialPersisted;
    const safeCreatedRooms: Room[] = []; 
    set({
      ...parsed,
      createdRooms: safeCreatedRooms,
      rooms: [],
      notifications: buildLocalNotifications()
    });

    if (!hasSupabaseConfig) {
      set({ authenticated: false, currentUser: null, selectedUniversity: null, session: null, profile: null, hydrated: true, notifications: [], rooms: [] });
      return;
    }

    const { data } = await supabase.auth.getSession();
    if (!data.session) {
      set({ authenticated: false, currentUser: null, selectedUniversity: null, session: null, profile: null, hydrated: true });
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
    const redirectTo = "bant://auth/callback";
    const { error } = await supabase.auth.signInWithOAuth({
      provider: "google",
      options: { redirectTo }
    });
    if (error) {
      set({ authLoading: false, toast: error.message });
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
      set({ authLoading: false, toast: error.message });
      return false;
    }
    if (!data.session) {
      set({ authLoading: false, toast: "Check your email to confirm your account" });
      return false;
    }
    const profileResult = await ensureProfile(data.session, displayName, username);
    if (!profileResult.ok) {
      set({ authLoading: false, toast: `Account confirmed, but profile setup failed: ${profileResult.error}` });
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
    const { data, error } = await supabase.auth.signInWithPassword({ email, password });
    if (error || !data.session) {
      set({ authLoading: false, toast: error?.message ?? "Unable to sign in" });
      return false;
    }
    const displayName = data.user.user_metadata?.display_name ?? email.split("@")[0];
    const username = data.user.user_metadata?.username ?? email.split("@")[0];
    const profileResult = await ensureProfile(data.session, displayName, username);
    if (!profileResult.ok) {
      set({ authLoading: false, toast: `Signed in, but profile setup failed: ${profileResult.error}` });
      return false;
    }
    await loadProfileIntoState(data.session, set);
    set({ authLoading: false });
    return true;
  },
  signOut: async () => {
    if (hasSupabaseConfig) await supabase.auth.signOut();
    set({ authenticated: false, currentUser: null, selectedUniversity: null, session: null, profile: null });
    await persist(persisted(get()));
  },
  completeOnboarding: async ({ university, interests, displayName, username, bio }) => {
    const session = get().session;
    if (!hasSupabaseConfig || !session) {
      set({ toast: "Sign in first" });
      return false;
    }
    set({ authLoading: true, toast: null });
    const universityRow = await ensureUniversity(university);
    if (!universityRow) {
      set({ authLoading: false, toast: "Unable to save university" });
      return false;
    }
    const { error: profileError } = await supabase
      .from("profiles")
      .update({
        display_name: displayName.trim(),
        username: normalizeUsername(username),
        bio: bio?.trim() || null,
        university_id: universityRow.id,
        onboarding_completed: true
      })
      .eq("id", session.user.id);
    if (profileError) {
      set({ authLoading: false, toast: profileError.message });
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
    await loadProfileIntoState(session, set);
    set({ authLoading: false, toast: "Onboarding complete" });
    await persist(persisted(get()));
    return true;
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
  selectUniversity: async (university) => {
    const user = get().currentUser ?? defaultUser;
    const currentUser = { ...user, university: university.name };
    set({ selectedUniversity: university, currentUser });
    await persist(persisted(get()));
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
    const state = get();
    if (!userId || userId === state.profile?.id) return false;
    if (state.friends.includes(userId)) {
      set({ toast: "You are already friends" });
      return false;
    }
    if (state.outgoingFriendRequests.includes(userId)) {
      set({ toast: "Friend request already sent" });
      return false;
    }
    set({
      outgoingFriendRequests: Array.from(new Set([...state.outgoingFriendRequests, userId])),
      toast: "Friend request sent"
    });
    void Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light).catch(() => {});
    await persist(persisted(get()));
    return true;
  },
  acceptFriendRequest: async (userId) => {
    const state = get();
    if (!userId) return false;
    const nextFriends = Array.from(new Set([...state.friends, userId]));
    const nextIncoming = state.friendRequests.filter((id) => id !== userId);
    const nextOutgoing = state.outgoingFriendRequests.filter((id) => id !== userId);
    set({
      friends: nextFriends,
      friendRequests: nextIncoming,
      outgoingFriendRequests: nextOutgoing,
      notifications: state.notifications.map((item) => item.actorId === userId && item.type === "friend_request" ? { ...item, readAt: item.readAt ?? new Date().toISOString() } : item),
      toast: "Friend request accepted"
    });
    void Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium).catch(() => {});
    await persist(persisted(get()));
    return true;
  },
  declineFriendRequest: async (userId) => {
    const state = get();
    if (!userId) return false;
    set({
      friendRequests: state.friendRequests.filter((id) => id !== userId),
      notifications: state.notifications.filter((item) => !(item.actorId === userId && item.type === "friend_request")),
      toast: "Friend request declined"
    });
    await persist(persisted(get()));
    return true;
  },
  cancelFriendRequest: async (userId) => {
    const state = get();
    if (!userId) return false;
    set({
      outgoingFriendRequests: state.outgoingFriendRequests.filter((id) => id !== userId),
      toast: "Friend request cancelled"
    });
    await persist(persisted(get()));
    return true;
  },
  friendshipState: (userId) => {
    const state = get();
    if (state.friends.includes(userId)) return "friends";
    if (state.outgoingFriendRequests.includes(userId)) return "pending_sent";
    if (state.friendRequests.includes(userId)) return "pending_received";
    return "none";
  },
  friendCount: () => get().friends.length,
  loadPeople: async () => {
    if (!hasSupabaseConfig) {
      set({ people: [], followingIds: [], peopleLoading: false, toast: "Supabase config is required to load people" });
      return;
    }
    const session = get().session;
    if (!session) return;
    set({ peopleLoading: true });
    const [{ data: profiles, error: profilesError }, { data: follows, error: followsError }] = await Promise.all([
      supabase
        .from("profiles")
        .select("id, display_name, username, bio, avatar_url, university_id, universities(name)")
        .eq("onboarding_completed", true)
        .neq("id", session.user.id)
        .order("created_at", { ascending: false }),
      supabase.from("follows").select("following_id").eq("follower_id", session.user.id)
    ]);
    if (profilesError || followsError) {
      set({ peopleLoading: false, toast: profilesError?.message ?? followsError?.message ?? "Unable to load people" });
      return;
    }
    set({
      people: (profiles ?? []).map((row) => profileRowToUser(row)),
      followingIds: (follows ?? []).map((follow) => follow.following_id),
      peopleLoading: false
    });
  },
  followUser: async (userId) => {
    if (!hasSupabaseConfig) {
      void get().addFriend(userId);
      return;
    }
    const session = get().session;
    if (!session || userId === session.user.id) return;
    const { error } = await supabase.from("follows").insert({ follower_id: session.user.id, following_id: userId });
    if (error && !error.message.toLowerCase().includes("duplicate")) {
      set({ toast: error.message });
      return;
    }
    set({ followingIds: Array.from(new Set([...get().followingIds, userId])), toast: "Followed" });
  },
  unfollowUser: async (userId) => {
    if (!hasSupabaseConfig) {
      set({ friends: get().friends.filter((id) => id !== userId), followingIds: get().followingIds.filter((id) => id !== userId), toast: "Removed" });
      await persist(persisted(get()));
      return;
    }
    const session = get().session;
    if (!session) return;
    const { error } = await supabase.from("follows").delete().eq("follower_id", session.user.id).eq("following_id", userId);
    if (error) {
      set({ toast: error.message });
      return;
    }
    set({ followingIds: get().followingIds.filter((id) => id !== userId), toast: "Unfollowed" });
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
      .select("id, actor_id, type, body, read_at, created_at")
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
    const baseSelect = "id, title, slug, description, category, privacy, status, host_id, university_id, created_at, universities(name), room_members(user_id, role, left_at, profiles(id, display_name, username, bio, avatar_url, universities(name)))";
    const fullSelect = `${baseSelect.replace("created_at", "max_participants, noise_control_enabled, created_at")}`;
    const { data, error } = await supabase
      .from("rooms")
      .select(fullSelect)
      .eq("status", "live")
      .order("created_at", { ascending: false });
    if (error && isMissingRoomColumnsError(error)) {
      const fallback = await supabase
        .from("rooms")
        .select(baseSelect)
        .eq("status", "live")
        .order("created_at", { ascending: false });
      if (fallback.error) {
        set({ rooms: [], roomsLoading: false, toast: fallback.error.message });
        return;
      }
      const liveFallback = (fallback.data ?? []).filter((row: any) => (row.status ?? "live") !== "ended");
      set({ rooms: liveFallback.map((row) => shapeRoom(row, session.user.id)), roomsLoading: false });
      return;
    }
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
      const university = state.selectedUniversity ? await ensureUniversity(state.selectedUniversity) : null;
      const baseSlug = slugify(input.title);
      const maxParticipants = Math.min(Math.max(Number(input.maxParticipants ?? 20), 5), 100);
      const noiseControlEnabled = Boolean(input.noiseControl);
      const basePayload = {
        title: input.title.trim(),
        slug: `${baseSlug}-${Date.now().toString(36)}`,
        description: input.description.trim() || "A fresh BANT room.",
        category: input.category,
        privacy: input.privacy,
        university_id: university?.id ?? null,
        host_id: state.session.user.id,
        status: "live"
      };
      const fullPayload = {
        ...basePayload,
        max_participants: maxParticipants,
        noise_control_enabled: noiseControlEnabled
      };
      const baseSelect = "id, title, slug, description, category, privacy, status, host_id, university_id, created_at, universities(name), room_members(user_id, role, left_at, profiles(id, display_name, username, bio, avatar_url, universities(name)))";
      const fullSelect = `${baseSelect.replace("created_at", "max_participants, noise_control_enabled, created_at")}`;
      const { data, error } = await supabase
        .from("rooms")
        .insert(fullPayload)
        .select(fullSelect)
        .single();
      if (error && isMissingRoomColumnsError(error)) {
        const fallback = await supabase
          .from("rooms")
          .insert(basePayload)
          .select(baseSelect)
          .single();
        if (fallback.error || !fallback.data) {
          set({ toast: fallback.error?.message ?? "Unable to create room" });
          return null;
        }
        const room = shapeRoom(fallback.data, state.session.user.id);
        set({ rooms: [room, ...state.rooms.filter((item) => item.id !== room.id)], toast: "Room created with the current schema" });
        return room;
      }
      if (error || !data) {
        set({ toast: error?.message ?? "Unable to create room" });
        return null;
      }
      const room = shapeRoom(data, state.session.user.id);
      set({ rooms: [room, ...state.rooms.filter((item) => item.id !== room.id)], toast: "Room created" });
      void Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success).catch(() => {});
      return room;
    }

    set({ toast: "Supabase config is required to create rooms" });
    return null;
  },
  joinRoom: async (roomId, role = "listener") => {
    if (!hasSupabaseConfig) return true;
    const session = get().session;
    if (!session) {
      set({ toast: "Sign in first" });
      return false;
    }
    const room = get().rooms.find((item) => item.id === roomId);
    if (room && room.privacy === "private" && !get().roomAccessAllowed(roomId, session.user.id)) {
      set({ toast: "This room is private or invite-only." });
      return false;
    }
    if (room && room.maxParticipants && room.participantCount >= room.maxParticipants) {
      set({ toast: "Room is full" });
      return false;
    }
    const { error } = await supabase
      .from("room_members")
      .upsert({ room_id: roomId, user_id: session.user.id, role, left_at: null, joined_at: new Date().toISOString() }, { onConflict: "room_id,user_id" });
    if (error) {
      set({ toast: error.message });
      return false;
    }
    await get().loadRooms();
    return true;
  },
  leaveRoom: async (roomId) => {
    if (!hasSupabaseConfig) return true;
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
      const { error: deleteError } = await supabase.from("rooms").delete().eq("id", roomId);
      if (deleteError) {
        set({ toast: deleteError.message });
        return false;
      }
      set({ rooms: get().rooms.filter((item) => item.id !== roomId) });
      set({ toast: "Room closed because it was empty" });
      await get().loadRooms();
      return true;
    }

    if (room?.ownerId === session.user.id) {
      const { error: endError } = await supabase
        .from("rooms")
        .update({ status: "ended" })
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
    const state = get();
    if (!roomId || !inviteeId) return false;
    if (!state.roomInvites[roomId]) state.roomInvites[roomId] = [];
    state.roomInvites[roomId] = Array.from(new Set([...state.roomInvites[roomId], inviteeId]));
    set({ roomInvites: { ...state.roomInvites }, toast: "Invite sent" });
    await persist(persisted(get()));
    return true;
  },
  roomAccessAllowed: (roomId, userId) => {
    const room = get().rooms.find((item) => item.id === roomId);
    if (!room) return false;
    if (room.privacy !== "private") return true;
    const invitees = get().roomInvites[roomId] ?? [];
    return invitees.includes(userId) || room.ownerId === userId || get().friends.includes(userId);
  },
  resetDemo: async () => {
    await AsyncStorage.removeItem(STORAGE_KEY);
    if (hasSupabaseConfig) await supabase.auth.signOut();
    set({ ...initialPersisted, hydrated: true, session: null, profile: null, authLoading: false, roomsLoading: false, peopleLoading: false, rooms: [], people: [], followingIds: [], notifications: [], toast: "State reset" });
  }
}));

function isMissingRoomColumnsError(error: { message?: string } | null | undefined) {
  const message = (error?.message ?? "").toLowerCase();
  return message.includes("max_participants") || message.includes("noise_control_enabled") || message.includes("column rooms.");
}

function slugify(value: string) {
  return value.toLowerCase().trim().replace(/[^a-z0-9]+/g, "-").replace(/(^-|-$)/g, "") || "room";
}

function normalizeUsername(value: string) {
  return value.toLowerCase().trim().replace(/[^a-z0-9_]/g, "_").replace(/_+/g, "_").slice(0, 24);
}

function fallbackAvatar(username: string) {
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

async function ensureUniversity(university: University): Promise<{ id: string; name: string; short_name: string; location: string } | null> {
  const { data: existing } = await supabase
    .from("universities")
    .select("id, name, short_name, location")
    .eq("name", university.name)
    .maybeSingle();
  if (existing) return existing;
  const { data, error } = await supabase
    .from("universities")
    .insert({ name: university.name, short_name: university.shortName, location: university.location })
    .select("id, name, short_name, location")
    .single();
  return error ? null : data;
}

async function loadProfileIntoState(session: Session, set: (partial: Partial<BantState>) => void) {
  const { data: profile } = await supabase
    .from("profiles")
    .select("id, display_name, username, university_id, bio, avatar_url, onboarding_completed, onboarding_step, user_status, occupation_category, occupation_custom, institution_source, created_at, updated_at, universities(name, short_name, location)")
    .eq("id", session.user.id)
    .maybeSingle();

  const university = Array.isArray(profile?.universities) ? profile?.universities[0] : profile?.universities;
  const currentUser: User | null = profile ? {
    id: profile.id,
    name: profile.display_name,
    username: profile.username,
    university: university?.name ?? "BANT",
    avatarColor: fallbackAvatar(profile.username),
    avatar_url: profile.avatar_url,
    bio: profile.bio ?? "",
    online: true
  } : null;
  const selectedUniversity: University | null = university ? {
    id: profile?.university_id ?? university.name,
    name: university.name,
    shortName: university.short_name,
    location: university.location
  } : null;
  const shapedProfile: Profile | null = profile ? {
    id: profile.id,
    display_name: profile.display_name,
    username: profile.username,
    university_id: profile.university_id,
    university_name: university?.name ?? null,
    university_short_name: university?.short_name ?? null,
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
  set({ authenticated: Boolean(session), session, profile: shapedProfile, currentUser, selectedUniversity });
}

function shapeRoom(row: any, currentUserId: string): Room {
  const university = Array.isArray(row.universities) ? row.universities[0] : row.universities;
  const activeMembers = ((row.room_members ?? []) as any[]).filter((member) => !member.left_at);
  const users: { role: "host" | "speaker" | "listener"; user: User }[] = [];
  activeMembers.forEach((member) => {
    const profile = Array.isArray(member.profiles) ? member.profiles[0] : member.profiles;
    const profileUniversity = Array.isArray(profile?.universities) ? profile?.universities[0] : profile?.universities;
    const user = profileToUser(profile, profileUniversity?.name ?? university?.name ?? "BANT");
    if (!user) return;
    users.push({
      role: member.role as "host" | "speaker" | "listener",
      user
    });
  });
  const speakers = users.filter((member) => member.role === "host" || member.role === "speaker").map((member) => member.user);
  const listeners = users.filter((member) => member.role === "listener").map((member) => member.user);
  const currentMember = activeMembers.find((member) => member.user_id === currentUserId);
  return {
    id: row.id,
    title: row.title,
    slug: row.slug,
    description: row.description || "A fresh BANT room.",
    category: row.category as RoomCategory,
    university: university?.name ?? "BANT",
    privacy: row.privacy as RoomPrivacy,
    speakerIds: speakers.map((user) => user.id),
    listenerIds: listeners.map((user) => user.id),
    participantCount: activeMembers.length,
    maxParticipants: Number(row.max_participants ?? Math.max(activeMembers.length, 20)),
    noiseControlEnabled: Boolean(row.noise_control_enabled),
    isLive: row.status === "live",
    ownerId: row.host_id,
    speakers,
    listeners,
    currentUserRole: currentMember?.role
  };
}

function profileToUser(profile: any, university: string): User | null {
  if (!profile) return null;
  return {
    id: profile.id,
    name: profile.display_name,
    username: profile.username,
    university,
    avatarColor: fallbackAvatar(profile.username ?? profile.id),
    avatar_url: profile.avatar_url ?? null,
    bio: profile.bio ?? "",
    online: true
  };
}

function profileRowToUser(row: any): User {
  const university = Array.isArray(row.universities) ? row.universities[0] : row.universities;
  return {
    id: row.id,
    name: row.display_name,
    username: row.username,
    university: university?.name ?? "BANT",
    avatarColor: fallbackAvatar(row.username ?? row.id),
    avatar_url: row.avatar_url ?? null,
    bio: row.bio ?? "",
    online: true
  };
}
