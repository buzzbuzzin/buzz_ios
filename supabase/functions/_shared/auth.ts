import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

export const supabaseUrl = Deno.env.get("SUPABASE_URL") || ""
export const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") || ""
export const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || ""

if (!supabaseUrl || !supabaseAnonKey || !supabaseServiceKey) {
  throw new Error("SUPABASE_URL, SUPABASE_ANON_KEY, and SUPABASE_SERVICE_ROLE_KEY must be set")
}

export const serviceSupabase = createClient(supabaseUrl, supabaseServiceKey)

export function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  })
}

export async function requireAuthUser(req: Request) {
  const authHeader = req.headers.get("Authorization")
  if (!authHeader) {
    return { response: jsonResponse({ error: "Missing Authorization header" }, 401) }
  }

  const userClient = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { autoRefreshToken: false, persistSession: false },
  })

  const {
    data: { user },
    error,
  } = await userClient.auth.getUser()

  if (error || !user) {
    return { response: jsonResponse({ error: "Invalid or expired token" }, 401) }
  }

  return { user }
}

export function requireMatchingUserId(authUserId: string, requestedUserId?: string | null) {
  if (requestedUserId && requestedUserId !== authUserId) {
    return { response: jsonResponse({ error: "Unauthorized: user does not match authenticated user" }, 403) }
  }

  return { userId: authUserId }
}

export async function requireOwnedStripeAccount(userId: string, requestedAccountId?: string | null) {
  const { data: profile, error } = await serviceSupabase
    .from("profiles")
    .select("stripe_account_id")
    .eq("id", userId)
    .maybeSingle()

  if (error || !profile) {
    return { response: jsonResponse({ error: "User profile not found" }, 404) }
  }

  const accountId = profile.stripe_account_id as string | null
  if (!accountId) {
    return { response: jsonResponse({ error: "No Stripe connected account found for this user" }, 400) }
  }

  if (requestedAccountId && requestedAccountId !== accountId) {
    return { response: jsonResponse({ error: "Unauthorized: account does not belong to authenticated user" }, 403) }
  }

  return { accountId }
}
