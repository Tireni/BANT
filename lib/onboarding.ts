import { Profile } from '@/types/profile';

export function onboardingRoute(profile: Profile | null | undefined) {
  if (!profile) return '/onboarding/profile';
  if (profile.onboarding_completed) return '/(tabs)/home';
  if ((profile.onboarding_step ?? 1) <= 1) return '/onboarding/profile';
  if (profile.onboarding_step === 2) return '/onboarding/interests';
  if (profile.onboarding_step >= 3) return '/onboarding/complete';
  return '/onboarding/profile';
}
