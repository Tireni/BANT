import { describe, expect, it } from "vitest";

const hasIntegrationEnv = Boolean(process.env.TEST_SUPABASE_URL && process.env.TEST_SUPABASE_ANON_KEY);

describe.skipIf(!hasIntegrationEnv)("Supabase integration smoke", () => {
  it("has staging Supabase test credentials configured", () => {
    expect(process.env.TEST_SUPABASE_URL).toMatch(/^https:\/\//);
    expect(process.env.TEST_SUPABASE_ANON_KEY).toBeTruthy();
  });
});

