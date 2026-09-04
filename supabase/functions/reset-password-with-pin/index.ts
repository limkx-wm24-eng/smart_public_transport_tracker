













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
