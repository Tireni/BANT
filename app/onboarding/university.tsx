import { Redirect } from "expo-router";
import { onboardingRoute } from "@/lib/onboarding";
import { useBantStore } from "@/store/useBantStore";

export default function LegacyOnboardingRedirect() {
  const profile = useBantStore((state) => state.profile);
  return <Redirect href={onboardingRoute(profile) as any} />;
}
