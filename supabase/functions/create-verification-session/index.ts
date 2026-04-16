// Supabase Edge Function: creates a Stripe Identity VerificationSession and
// persists a 'pending' government_ids row for the user using the service-role
// key. After migration 20260416_lock_verification_status_to_service_role.sql,
// this function (and the stripe-webhook companion) are the ONLY writers of
// verification_status — the iOS client never writes status directly anymore.
//
// Deploy: supabase functions deploy create-verification-session
// Required secrets:
// - STRIPE_SECRET_KEY
// - SUPABASE_URL
// - SUPABASE_SERVICE_ROLE_KEY
//
// Request body: { user_id: string, email?: string }
// Response:     { client_secret: string, id: string }

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4"
import Stripe from "https://esm.sh/stripe@14.21.0?target=deno"

const stripeSecretKey = Deno.env.get("STRIPE_SECRET_KEY")
const supabaseUrl = Deno.env.get("SUPABASE_URL")
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")

if (!stripeSecretKey) {
  throw new Error("STRIPE_SECRET_KEY environment variable is not set")
}
if (!supabaseUrl || !supabaseServiceRoleKey) {
  throw new Error("Supabase environment variables are not set")
}

const stripe = new Stripe(stripeSecretKey, {
  apiVersion: "2023-10-16",
  httpClient: Stripe.createFetchHttpClient(),
})

const supabaseAdmin = createClient(supabaseUrl, supabaseServiceRoleKey, {
  auth: { autoRefreshToken: false, persistSession: false },
})

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    const { user_id, email } = await req.json()

    if (!user_id) {
      return new Response(
        JSON.stringify({ error: "user_id is required" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

    // 1. Create the Stripe Identity VerificationSession. We attach both
    //    metadata keys so the webhook can look up the user regardless of which
    //    convention it prefers (subscription code uses `supabase_user_id`).
    const verificationSession = await stripe.identity.verificationSessions.create({
      type: "document",
      provided_details: {
        email: email || undefined,
      },
      options: {
        document: {
          require_matching_selfie: true,
        },
      },
      metadata: {
        user_id,
        supabase_user_id: user_id,
      },
    })

    // 2. Persist a pending row (service role bypasses the status-lock trigger).
    //    - If no row exists: INSERT with status='pending'.
    //    - If row exists and status is 'verified': record the new session_id
    //      but do NOT reset status (defensive for re-verification attempts).
    //    - Otherwise: reset status to 'pending' and attach the new session_id.
    const { data: existing, error: lookupErr } = await supabaseAdmin
      .from("government_ids")
      .select("verification_status")
      .eq("user_id", user_id)
      .maybeSingle()

    if (lookupErr) {
      console.error("[create-verification-session] Lookup error:", lookupErr)
      // Non-fatal: proceed with the insert path and let ON CONFLICT handle it.
    }

    if (!existing) {
      const { error: insertErr } = await supabaseAdmin
        .from("government_ids")
        .insert({
          user_id,
          stripe_session_id: verificationSession.id,
          verification_status: "pending",
        })
      if (insertErr) {
        console.error("[create-verification-session] Insert error:", insertErr)
      }
    } else if (existing.verification_status === "verified") {
      const { error: updateErr } = await supabaseAdmin
        .from("government_ids")
        .update({ stripe_session_id: verificationSession.id })
        .eq("user_id", user_id)
      if (updateErr) {
        console.error("[create-verification-session] Update (keep verified) error:", updateErr)
      }
    } else {
      const { error: updateErr } = await supabaseAdmin
        .from("government_ids")
        .update({
          stripe_session_id: verificationSession.id,
          verification_status: "pending",
        })
        .eq("user_id", user_id)
      if (updateErr) {
        console.error("[create-verification-session] Update (reset pending) error:", updateErr)
      }
    }

    return new Response(
      JSON.stringify({
        client_secret: verificationSession.client_secret,
        id: verificationSession.id,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    )
  } catch (error) {
    console.error("[create-verification-session] Error:", error)
    return new Response(
      JSON.stringify({
        error: error instanceof Error ? error.message : "Failed to create verification session",
      }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    )
  }
})
