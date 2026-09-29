export function normalizeUsername(value: string) {
  return value.toLowerCase().trim().replace(/[^a-z0-9_]/g, "_").replace(/_+/g, "_").slice(0, 24);
}

export function isEmailIdentifier(value: string) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value.trim());
}

export function googleOAuthRedirectUrl(input: { platform: string; origin?: string; nativeUrl: string }) {
  if (input.platform === "web" && input.origin) {
    return `${input.origin}/auth/callback`;
  }
  return input.nativeUrl;
}
