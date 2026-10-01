import { createClient } from "@supabase/supabase-js";

const url = process.env.TEST_SUPABASE_URL;
const anonKey = process.env.TEST_SUPABASE_ANON_KEY;
const serviceRoleKey = process.env.TEST_SUPABASE_SERVICE_ROLE_KEY;

if (!url || !anonKey || !serviceRoleKey) {
  console.error("Set TEST_SUPABASE_URL, TEST_SUPABASE_ANON_KEY, and TEST_SUPABASE_SERVICE_ROLE_KEY.");
  process.exit(1);
}

if (process.env.ALLOW_BANT_LOAD_TEST !== "yes") {
  console.error("Refusing to create test users. Set ALLOW_BANT_LOAD_TEST=yes for a dedicated staging project.");
  process.exit(1);
}

const admin = createClient(url, serviceRoleKey, {
  auth: { persistSession: false, autoRefreshToken: false }
});

const runId = Date.now().toString(36);
const password = `BantLoad!${runId}Aa1`;
const createdUserIds = [];
let ownerClient = null;
let roomId = null;

async function createTestUser(index) {
  const email = `bant-load-${runId}-${index}@example.com`;
  const { data, error } = await admin.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: { display_name: `Load User ${index}`, username: `load_${runId.slice(-5)}_${index}` }
  });
  if (error || !data.user) throw error ?? new Error("Unable to create test user");
  createdUserIds.push(data.user.id);

  const { error: profileError } = await admin.from("profiles").upsert({
    id: data.user.id,
    display_name: `Load User ${index}`,
    username: `load_${runId.slice(-5)}_${index}`,
    onboarding_completed: true,
    onboarding_step: 4
  });
  if (profileError) throw profileError;

  const client = createClient(url, anonKey, { auth: { persistSession: false, autoRefreshToken: false } });
  const login = await client.auth.signInWithPassword({ email, password });
  if (login.error) throw login.error;
  return client;
}

try {
  console.log("Creating owner...");
  ownerClient = await createTestUser(0);

  const ownerSession = await ownerClient.auth.getUser();
  const ownerId = ownerSession.data.user?.id;
  if (!ownerId) throw new Error("Owner session missing");

  const created = await ownerClient.from("rooms").insert({
    title: `100 Person Load Test ${runId}`,
    slug: `load-${runId}`,
    description: "Staging-only 100-person backend capacity test",
    category: "General",
    privacy: "public",
    host_id: ownerId,
    owner_id: ownerId,
    status: "live",
    max_participants: 100,
    noise_control_enabled: true
  }).select("id").single();

  if (created.error || !created.data) throw created.error ?? new Error("Room creation failed");
  roomId = created.data.id;

  console.log("Joining 99 additional users...");
  for (let i = 1; i <= 99; i += 1) {
    const client = await createTestUser(i);
    const joined = await client.rpc("join_room", { p_room_id: roomId, p_role: "speaker" });
    if (joined.error) throw new Error(`User ${i} failed to join: ${joined.error.message}`);
    if (i % 10 === 0 || i === 99) console.log(`Active target reached: ${i + 1}/100`);
  }

  const countResult = await admin
    .from("room_members")
    .select("user_id", { count: "exact", head: true })
    .eq("room_id", roomId)
    .is("left_at", null);

  if (countResult.error) throw countResult.error;
  if (countResult.count !== 100) throw new Error(`Expected 100 active members, got ${countResult.count}`);

  console.log("Testing 101st user rejection...");
  const overflowClient = await createTestUser(100);
  const overflow = await overflowClient.rpc("join_room", { p_room_id: roomId, p_role: "speaker" });
  if (!overflow.error) throw new Error("101st participant was incorrectly allowed to join");

  console.log("PASS: 100 active members accepted and the 101st was rejected.");
} finally {
  if (roomId && ownerClient) {
    await ownerClient.rpc("end_room", { p_room_id: roomId }).catch(() => {});
  }
  console.log(`Cleaning up ${createdUserIds.length} staging users...`);
  for (const userId of createdUserIds.reverse()) {
    await admin.auth.admin.deleteUser(userId).catch(() => {});
  }
}
