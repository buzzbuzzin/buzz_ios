// Supabase Edge Function to create Stripe Identity VerificationSession
// This function must be deployed to Supabase Edge Functions
// 
// Setup instructions:
// 1. Install Supabase CLI: https://supabase.com/docs/guides/cli
// 2. Run: supabase functions deploy create-verification-session
// 3. Set Stripe secret key as environment variable:
//    supabase secrets set STRIPE_SECRET_KEY=sk_test_...
//
// The function requires:
// - Stripe secret key set as environment variable
// - Request body with: { user_id: string, email: string }

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

    // Create Stripe Identity VerificationSession with selfie check enabled
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
        user_id: user_id,
      },
    })

    // Return only the client secret to the frontend
    // Never expose the full session object or secret key
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
    console.error("Error creating verification session:", error)
    return new Response(
      JSON.stringify({
        error: error.message || "Failed to create verification session",
      }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    )
  }
})

