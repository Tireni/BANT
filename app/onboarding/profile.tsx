import { Redirect, router } from "expo-router";
import { Camera } from "lucide-react-native";
import { useEffect, useState } from "react";
import { Image, KeyboardAvoidingView, Platform, ScrollView, StyleSheet, Text, View, Pressable } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { BantAvatar } from "@/components/common/BantAvatar";
import { BantButton } from "@/components/common/BantButton";
import { BantInput } from "@/components/common/BantInput";
import { OnboardingStep } from "@/components/onboarding/OnboardingStep";
import { useTheme } from "@/hooks/useTheme";
import { hasSupabaseConfig, supabase } from "@/lib/supabase";
import { useBantStore } from "@/store/useBantStore";

const AVATAR_PRESETS = [
  "https://images.unsplash.com/photo-1534528741775-53994a69daeb",
  "https://images.unsplash.com/photo-1539571696357-5a69c17a67c6",
  "https://images.unsplash.com/photo-1517841905240-472988babdf9",
  "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d",
  "https://images.unsplash.com/photo-1494790108377-be9c29b29330",
  "https://images.unsplash.com/photo-1500648767791-00dcc994a43e"
];

export default function ProfileStep() {
  const theme = useTheme();
  const authenticated = useBantStore((state) => state.authenticated);
  const profile = useBantStore((state) => state.profile);
  const currentUser = useBantStore((state) => state.currentUser);
  const authLoading = useBantStore((state) => state.authLoading);
  const saveOnboardingProfile = useBantStore((state) => state.saveOnboardingProfile);
  const setToast = useBantStore((state) => state.setToast);
  const [displayName, setDisplayName] = useState("");
  const [username, setUsername] = useState("");
  const [bio, setBio] = useState("");
  const [avatarUrl, setAvatarUrl] = useState<string | null>(null);
  const [uploading, setUploading] = useState(false);

  useEffect(() => {
    setDisplayName(profile?.display_name ?? currentUser?.name ?? "");
    setUsername(profile?.username ?? currentUser?.username ?? "");
    setBio(profile?.bio ?? currentUser?.bio ?? "");
    setAvatarUrl(profile?.avatar_url ?? null);
  }, [currentUser, profile]);

  if (!authenticated) return <Redirect href="/auth/welcome" />;

  const pickAvatar = async () => {
    if (!hasSupabaseConfig) {
      setToast("Upload a profile photo after Supabase setup");
      return;
    }

    if (Platform.OS === "web") {
      const input = document.createElement("input");
      input.type = "file";
      input.accept = "image/*";
      input.style.display = "none";
      input.onchange = async () => {
        const file = input.files?.[0];
        if (!file) return;
        await uploadAvatar(file);
      };
      input.click();
      return;
    }

    let ImagePicker: any = null;
    try {
      ImagePicker = require("expo-image-picker");
    } catch (error) {
      setToast("Image picking is not available in this environment");
      return;
    }

    try {
      const permission = await ImagePicker.requestMediaLibraryPermissionsAsync();
      if (!permission.granted) {
        setToast("Please allow access to your photos");
        return;
      }

      const result = await ImagePicker.launchImageLibraryAsync({
        mediaTypes: ImagePicker.MediaTypeOptions.Images,
        allowsEditing: true,
        aspect: [1, 1],
        quality: 0.8
      });

      if (result.canceled || !result.assets[0]?.uri) return;
      const response = await fetch(result.assets[0].uri);
      const blob = await response.blob();
      await uploadAvatar(blob as Blob, result.assets[0].fileName ?? `avatar-${Date.now()}.jpg`);
    } catch (error: any) {
      setToast(error?.message ?? "Unable to pick a profile photo");
    }
  };

  const uploadAvatar = async (file: Blob | File, fileNameOverride?: string) => {
    if (!hasSupabaseConfig) {
      setToast("Photo upload needs Supabase storage setup");
      return;
    }

    const fileName = fileNameOverride ?? `avatars/${Date.now()}.jpg`;
    setUploading(true);
    const { data, error } = await supabase.storage.from("avatars").upload(fileName, file, {
      contentType: file.type || "image/jpeg",
      upsert: true
    });
    setUploading(false);

    if (error) {
      setToast(error.message || "Could not upload your photo");
      return;
    }

    const { data: publicUrlData } = supabase.storage.from("avatars").getPublicUrl(data.path);
    setAvatarUrl(publicUrlData.publicUrl);
    setToast("Profile photo ready");
  };

  const save = async () => {
    const ok = await saveOnboardingProfile({ displayName, username, bio, avatarUrl: avatarUrl ?? undefined });
    if (ok) router.push("/onboarding/interests");
  };

  return (
    <SafeAreaView style={[styles.screen, { backgroundColor: theme.colors.background }]}>
      <KeyboardAvoidingView behavior={Platform.OS === "ios" ? "padding" : undefined} style={styles.keyboard}>
        <ScrollView contentContainerStyle={styles.content} keyboardShouldPersistTaps="handled">
          <OnboardingStep step={1} total={2} title="SET UP YOUR PROFILE" subtitle="Tell people a little about who you are.">
            <View style={[styles.photoCard, { backgroundColor: theme.colors.surface, borderColor: theme.colors.border }]}>
              <Pressable onPress={pickAvatar} style={styles.avatarPreview}>
                {avatarUrl ? (
                  <Image source={{ uri: avatarUrl }} style={styles.avatarImg} />
                ) : currentUser ? (
                  <BantAvatar user={user_fallback(displayName, avatarUrl) as any} size={84} />
                ) : (
                  <View style={[styles.emptyAvatar, { backgroundColor: theme.colors.soft }]}><Camera color={theme.colors.blue} size={28} /></View>
                )}
              </Pressable>
              <Text style={[styles.photoText, { color: theme.colors.secondary }]}>Add a profile photo from your device or browser.</Text>
              <BantButton title={uploading ? "Uploading..." : "Choose photo"} variant="ghost" onPress={pickAvatar} loading={uploading} style={styles.uploadButton} />
            </View>
            <View style={styles.form}>
              <BantInput placeholder="Full name" value={displayName} onChangeText={setDisplayName} />
              <BantInput placeholder="Username" value={username} onChangeText={setUsername} autoCapitalize="none" />
              <BantInput placeholder="Short bio" value={bio} onChangeText={setBio} multiline maxLength={160} />
            </View>
          </OnboardingStep>
        </ScrollView>
        <View style={styles.footer}><BantButton title="Continue" onPress={save} loading={authLoading || uploading} style={styles.button} /></View>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

function user_fallback(name: string, avatar_url: string | null) {
  return {
    id: "temp",
    name: name || "BANT",
    avatarColor: "#0E96F6",
  };
}

const styles = StyleSheet.create({
  screen: { flex: 1 },
  keyboard: { flex: 1, width: "100%" },
  content: { padding: 20, paddingBottom: 24, width: "100%", maxWidth: 560, alignSelf: "center" },
  photoCard: { borderWidth: 1, borderRadius: 24, padding: 18, alignItems: "center", gap: 12 },
  avatarPreview: { width: 84, height: 84, borderRadius: 42, overflow: "hidden", alignItems: "center", justifyContent: "center" },
  avatarImg: { width: 84, height: 84, borderRadius: 42 },
  emptyAvatar: { width: 84, height: 84, borderRadius: 42, alignItems: "center", justifyContent: "center" },
  photoText: { fontFamily: "PlusJakartaSans_500Medium", fontSize: 13, lineHeight: 19, textAlign: "center" },
  uploadButton: { width: "100%" },
  form: { gap: 12 },
  footer: { width: "100%", maxWidth: 560, alignSelf: "center", paddingHorizontal: 20, paddingBottom: 24, paddingTop: 12 },
  button: { width: "100%" }
});



