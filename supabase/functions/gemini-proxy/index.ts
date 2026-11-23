// Supabase Edge Function: gemini-proxy
//
// Keeps the Gemini API key on the server. The app sends the same JSON body it
// would send to Gemini's `generateContent` endpoint, plus the logged-in user's
// Supabase access token; this function checks the token, adds the secret key
// and forwards the request. The key never ships inside the app.
//
// Deploy:
//   supabase secrets set GEMINI_API_KEY=your-new-key
//   supabase functions deploy gemini-proxy
//
// SUPABASE_URL and SUPABASE_ANON_KEY are injected by Supabase automatically.

import { createClient } from "jsr:@supabase/supabase-js@2";

const GEMINI_BASE = "https://generativelanguage.googleapis.com/v1beta/models";
const DEFAULT_MODEL = "gemini-3.5-flash-lite";
const ALLOWED_MODELS = new Set([DEFAULT_MODEL]);

const MAX_BODY_BYTES = 256 * 1024; // prompts are text; reject anything huge
const RATE_LIMIT = 40; // requests per user per minute (best effort, see below)
const WINDOW_MS = 60_000;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

// Per-isolate sliding window. Edge isolates are short-lived and may be
// replicated, so this is a safety net against runaway loops, not a hard quota.
// Set a spending cap on the Gemini key in Google Cloud for a real limit.
const hits = new Map<string, number[]>();
function isRateLimited(userId: string): boolean {
  const now = Date.now();
  const recent = (hits.get(userId) ?? []).filter((t) => now - t < WINDOW_MS);
  recent.push(now);
  hits.set(userId, recent);
  return recent.length > RATE_LIMIT;
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  const geminiKey = Deno.env.get("GEMINI_API_KEY");
  if (!geminiKey) {
    console.error("GEMINI_API_KEY secret is not set");
    return json({ error: "Server is not configured" }, 500);
  }

  // 1. Only signed-in app users may call Gemini. The public anon key alone
  //    carries no user, so it is rejected here.
  const token = (req.headers.get("Authorization") ?? "").replace(
    /^Bearer\s+/i,
    "",
  );
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { auth: { persistSession: false, autoRefreshToken: false } },
  );
  const { data, error } = await supabase.auth.getUser(token);
  if (error || !data?.user) {
    return json({ error: "Unauthorized" }, 401);
  }
  if (isRateLimited(data.user.id)) {
    return json({ error: "Too many requests" }, 429);
  }

  // 2. Validate what we are about to forward.
  const model = new URL(req.url).searchParams.get("model") ?? DEFAULT_MODEL;
  if (!ALLOWED_MODELS.has(model)) {
    return json({ error: "Model not allowed" }, 400);
  }

  const raw = await req.text();
  if (raw.length > MAX_BODY_BYTES) {
    return json({ error: "Request too large" }, 413);
  }
  try {
    const parsed = JSON.parse(raw);
    if (!parsed || !Array.isArray(parsed.contents)) {
      return json({ error: "Body must contain 'contents'" }, 400);
    }
  } catch {
    return json({ error: "Invalid JSON" }, 400);
  }

  // 3. Forward to Gemini with the server-side key (header, not query string,
  //    so it does not end up in URL logs).
  try {
    const upstream = await fetch(`${GEMINI_BASE}/${model}:generateContent`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-goog-api-key": geminiKey,
      },
      body: raw,
    });
    // Pass Gemini's status and body straight through so the app's existing
    // error handling (e.g. 429 rate-limit messages) keeps working.
    return new Response(await upstream.text(), {
      status: upstream.status,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (e) {
    console.error("Gemini request failed", e);
    return json({ error: "Upstream request failed" }, 502);
  }
});
