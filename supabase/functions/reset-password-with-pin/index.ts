// Supabase Edge Function: reset-password-with-pin
//
// Lets a logged-out user reset their password using the security PIN they
// set at sign-up, instead of an emailed link. This function is the ONLY
// place that holds the service-role key needed to change another user's
// password — that key must never be embedded in the Flutter app, since
// anyone could extract it from the app binary and reset any account.
//
// Deploy with:
//   supabase functions deploy reset-password-with-pin
//
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are injected automatically by
// Supabase into every deployed Edge Function — no manual secret needed.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

// Same SHA-256 hex digest algorithm used client-side in
// lib/providers/auth_provider.dart's hashPin() — must stay identical on
// both sides for the comparison below to ever match.
async function sha256Hex(input: string): Promise<string> {
  const data = new TextEncoder().encode(input);
  const hashBuffer = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(hashBuffer))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  let email: unknown, pin: unknown, newPassword: unknown;
  try {
    const body = await req.json();
    email = body.email;
    pin = body.pin;
    newPassword = body.newPassword;
  } catch {
    return jsonResponse({ error: "Invalid request body" }, 400);
  }

  if (
    typeof email !== "string" || !email.trim() ||
    typeof pin !== "string" || !pin.trim() ||
    typeof newPassword !== "string" || newPassword.length < 6
  ) {
    return jsonResponse(
      { error: "Email, PIN, and a password of at least 6 characters are required." },
      400,
    );
  }

  // Same generic error for "no such account" and "wrong PIN" — this
  // endpoint must never let someone probe which emails have accounts.
  const genericError = () => jsonResponse({ error: "Incorrect email or PIN." }, 401);

  const supabaseAdmin = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  );

  const { data: profile, error: profileError } = await supabaseAdmin
    .from("profiles")
    .select("id, pin_hash")
    .eq("email", (email as string).trim().toLowerCase())
    .maybeSingle();

  if (profileError || !profile || !profile.pin_hash) {
    return genericError();
  }

  const suppliedHash = await sha256Hex((pin as string).trim());
  if (suppliedHash !== profile.pin_hash) {
    return genericError();
  }

  const { error: updateError } = await supabaseAdmin.auth.admin.updateUserById(
    profile.id,
    { password: newPassword as string },
  );

  if (updateError) {
    return jsonResponse({ error: updateError.message }, 500);
  }

  return jsonResponse({ success: true }, 200);
});
