import AsyncStorage from "@react-native-async-storage/async-storage";
import { Redirect } from "expo-router";
import { useEffect, useState } from "react";
import { onboardingRoute } from "@/lib/onboarding";
import { PENDING_INVITE_TOKEN_KEY } from "@/lib/roomInvites";
import { useBantStore } from "@/store/useBantStore";

export default function AuthCallback() {
  const [href, setHref] = useState<string | null>(null);
  const hydrate = useBantStore((state) => state.hydrate);

  useEffect(() => {
    void hydrate().then(async () => {
      const token = await AsyncStorage.getItem(PENDING_INVITE_TOKEN_KEY);
      const profile = useBantStore.getState().profile;
      if (token && profile?.onboarding_completed) {
        setHref(`/invite/${token}`);
        return;
      }
      setHref(onboardingRoute(profile));
    });
  }, [hydrate]);

  if (!href) return null;
  return <Redirect href={href as any} />;
}
