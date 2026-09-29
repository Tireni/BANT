import { describe, expect, it } from "vitest";
import { authIdentifier, googleOAuthRedirectUrl, isEmailIdentifier, normalizeUsername } from "../lib/authHelpers";

describe("auth helpers", () => {
  it("normalizes usernames consistently", () => {
    expect(normalizeUsername("  Big Bant.User!! ")).toBe("big_bant_user_");
    expect(normalizeUsername("A__B")).toBe("a_b");
  });

  it("detects email identifiers", () => {
    expect(isEmailIdentifier("user@example.com")).toBe(true);
    expect(isEmailIdentifier("bant_user")).toBe(false);
  });

  it("classifies username or email login identifiers", () => {
    expect(authIdentifier("USER@Example.COM")).toEqual({ kind: "email", value: "user@example.com" });
    expect(authIdentifier("Bant User")).toEqual({ kind: "username", value: "bant_user" });
  });

  it("uses native deep link redirects outside web", () => {
    expect(googleOAuthRedirectUrl({ platform: "ios", nativeUrl: "bant://auth/callback" })).toBe("bant://auth/callback");
  });

  it("uses the web origin on web", () => {
    expect(googleOAuthRedirectUrl({ platform: "web", origin: "https://bant.app", nativeUrl: "bant://auth/callback" })).toBe("https://bant.app/auth/callback");
  });
});
