import { Tabs } from "expo-router";
import { Redirect } from "expo-router";
import { Home, MessageCircleMore, UserRound, Users } from "lucide-react-native";
import { useTheme } from "@/hooks/useTheme";
import { onboardingRoute } from "@/lib/onboarding";
import { useBantStore } from "@/store/useBantStore";

export default function TabsLayout() {
  const theme = useTheme();
  const authenticated = useBantStore((state) => state.authenticated);
  const profile = useBantStore((state) => state.profile);
  if (!authenticated) return <Redirect href="/auth/welcome" />;
  if (!profile?.onboarding_completed) return <Redirect href={onboardingRoute(profile) as any} />;
  return (
    <Tabs
      screenOptions={{
        headerShown: false,
        tabBarActiveTintColor: theme.colors.blue,
        tabBarInactiveTintColor: theme.colors.muted,
        tabBarStyle: {
          backgroundColor: theme.colors.surface,
          borderTopColor: theme.colors.border,
          minHeight: 68,
          paddingTop: 8
        },
        tabBarLabelStyle: { fontFamily: "PlusJakartaSans_800ExtraBold", fontSize: 11 }
      }}
    >
      <Tabs.Screen name="home" options={{ title: "Home", tabBarIcon: ({ color }) => <Home color={color} size={22} /> }} />
      <Tabs.Screen name="rooms" options={{ title: "Rooms", tabBarIcon: ({ color }) => <MessageCircleMore color={color} size={25} /> }} />
      <Tabs.Screen name="friends" options={{ title: "People", tabBarIcon: ({ color }) => <Users color={color} size={22} /> }} />
      <Tabs.Screen name="profile" options={{ title: "Profile", tabBarIcon: ({ color }) => <UserRound color={color} size={22} /> }} />
    </Tabs>
  );
}
