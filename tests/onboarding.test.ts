import { describe, expect, it } from "vitest";
import { onboardingRoute } from "../lib/onboarding";

describe("onboardingRoute", () => {
  it("routes missing profiles to profile setup", () => {
    expect(onboardingRoute(null)).toBe("/onboarding/profile");
  });

  it("routes incomplete profiles by step", () => {
    expect(onboardingRoute({ onboarding_completed: false, onboarding_step: 1 } as any)).toBe("/onboarding/profile");
    expect(onboardingRoute({ onboarding_completed: false, onboarding_step: 2 } as any)).toBe("/onboarding/interests");
    expect(onboardingRoute({ onboarding_completed: false, onboarding_step: 3 } as any)).toBe("/onboarding/complete");
  });

  it("routes complete profiles to home", () => {
    expect(onboardingRoute({ onboarding_completed: true, onboarding_step: 4 } as any)).toBe("/(tabs)/home");
  });
});
