import { createClient } from "npm:@supabase/supabase-js@2";

Deno.serve(async (req) => {
  try {
    const url = new URL(req.url);
    const token = url.searchParams.get("token") ?? "";
    const next = safeNext(url.searchParams.get("next"));

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !serviceRoleKey) return htmlPage("BANT", "Join the conversation on BANT.", next, 503);

    if (!token) return htmlPage("BANT", "This room invite is invalid.", next, 400);

    const admin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false }
    });

    const { data: invite } = await admin
      .from("room_invites")
      .select("status, expires_at, rooms!room_invites_room_id_fkey(title, description, status)")
      .eq("invite_token", token)
      .maybeSingle();

    const room = Array.isArray((invite as any)?.rooms) ? (invite as any).rooms[0] : (invite as any)?.rooms;
    const active = Boolean(
      invite &&
      room &&
      invite.status === "active" &&
      room.status === "live" &&
      (!invite.expires_at || new Date(invite.expires_at).getTime() > Date.now())
    );

    const title = room?.title?.trim() || "BANT";
    const description = active
      ? (room?.description?.trim() || "Join this live conversation on BANT.")
      : "This BANT room invite is no longer available.";

    return htmlPage(title, description, next, 200);
  } catch (error) {
    console.error("room-invite-preview failed", error instanceof Error ? error.message : error);
    return htmlPage("BANT", "Join the conversation on BANT.", null, 500);
  }
});

function safeNext(value: string | null) {
  if (!value) return null;
  try {
    const parsed = new URL(value);
    if (parsed.protocol !== "https:" && parsed.protocol !== "http:") return null;
    return parsed.toString();
  } catch {
    return null;
  }
}

function htmlPage(title: string, description: string, next: string | null, status: number) {
  const safeTitle = escapeHtml(title);
  const safeDescription = escapeHtml(description);
  const safeNext = next ? escapeHtml(next) : "";

  const redirectHead = next
    ? `<meta http-equiv="refresh" content="0;url=${safeNext}">`
    : "";
  const redirectScript = next
    ? `<script>window.location.replace(${JSON.stringify(next)});</script>`
    : "";

  const html = `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>${safeTitle} | BANT</title>
  <meta name="description" content="${safeDescription}">
  <meta property="og:type" content="website">
  <meta property="og:site_name" content="BANT">
  <meta property="og:title" content="${safeTitle}">
  <meta property="og:description" content="${safeDescription}">
  <meta name="twitter:card" content="summary">
  <meta name="twitter:title" content="${safeTitle}">
  <meta name="twitter:description" content="${safeDescription}">
  ${redirectHead}
</head>
<body>
  <main style="font-family:system-ui,-apple-system,sans-serif;padding:24px">
    <h1>${safeTitle}</h1>
    <p>${safeDescription}</p>
    ${next ? `<p><a href="${safeNext}">Open room</a></p>` : ""}
  </main>
  ${redirectScript}
</body>
</html>`;

  const headers = new Headers();
  headers.set("Content-Type", "text/html; charset=utf-8");
  headers.set("Content-Disposition", "inline");
  headers.set("Cache-Control", "public, max-age=60");
  headers.set("X-Content-Type-Options", "nosniff");

  return new Response(html, {
    status,
    headers
  });
}

function escapeHtml(value: string) {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}
