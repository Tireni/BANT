import { Redirect, router } from "expo-router";

export default function EducationStep() {
  if (typeof window !== "undefined") {
    router.replace("/onboarding/profile");
  }

  return <Redirect href="/onboarding/profile" />;
}
