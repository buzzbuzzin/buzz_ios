// Supabase Edge Function to check Stripe Identity VerificationSession status
// This function retrieves the verification status from Stripe API

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import Stripe from "https://esm.sh/stripe@14.21.0?target=deno"

const stripeSecretKey = Deno.env.get("STRIPE_SECRET_KEY")
if (!stripeSecretKey) {
  throw new Error("STRIPE_SECRET_KEY environment variable is not set")
}

const stripe = new Stripe(stripeSecretKey, {
  apiVersion: "2023-10-16",
  httpClient: Stripe.createFetchHttpClient(),
})

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    // Parse request body
    const { session_id } = await req.json()

    if (!session_id) {
      return new Response(
        JSON.stringify({ error: "session_id is required" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

    // Retrieve the verification session from Stripe with expanded verification report
    // This includes selfie check details if selfie verification is enabled
    const verificationSession = await stripe.identity.verificationSessions.retrieve(
      session_id,
      {
        expand: ["last_verification_report"],
      }
    )

    // Map Stripe status to our app status
    // Stripe statuses: unverified, verified, requires_input
    let verificationStatus = "pending"
    if (verificationSession.status === "verified") {
      verificationStatus = "verified"
    } else if (verificationSession.status === "requires_input") {
      verificationStatus = "rejected"
    } else {
      verificationStatus = "pending"
    }

    // Return the verification status
    return new Response(
      JSON.stringify({
        status: verificationStatus,
        stripe_status: verificationSession.status,
        verified_at: verificationSession.verified_at,
        last_error: verificationSession.last_error,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    )
  } catch (error) {
    console.error("Error checking verification status:", error)
    return new Response(
      JSON.stringify({
        error: error.message || "Failed to check verification status",
      }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    )
  }
})

