// Supabase Edge Function to create Stripe Financial Connections session
// This function creates a Financial Connections session to link bank accounts
//
// Setup instructions:
// 1. Deploy: supabase functions deploy create-financial-connections-session
// 2. Set Stripe secret key: supabase secrets set STRIPE_SECRET_KEY=sk_test_...
//
// Request body:
// {
//   "account_id": "acct_xxx",
//   "features": ["balances", "ownership", "transactions"] (optional)
// }

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import Stripe from "https://esm.sh/stripe@14.21.0?target=deno"

const stripeSecretKey = Deno.env.get("STRIPE_SECRET_KEY")
if (!stripeSecretKey) {
  throw new Error("STRIPE_SECRET_KEY environment variable is not set")
}

const stripe = new Stripe(stripeSecretKey, {
  httpClient: Stripe.createFetchHttpClient(),
})

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    const { account_id, features = ["balances", "ownership"] } = await req.json()

    if (!account_id) {
      return new Response(
        JSON.stringify({ error: "account_id is required" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

    // Create Financial Connections session
    const session = await stripe.financialConnections.sessions.create({
      account_holder: {
        type: "account",
        account: account_id,
      },
      permissions: features,
    })

    return new Response(
      JSON.stringify({
        client_secret: session.client_secret,
        id: session.id,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    )
  } catch (error: any) {
    console.error("Error creating financial connections session:", error)
    return new Response(
      JSON.stringify({ error: error.message || "Failed to create financial connections session" }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    )
  }
})

