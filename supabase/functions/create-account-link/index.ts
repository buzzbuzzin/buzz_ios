// Supabase Edge Function to create Stripe Account Link for onboarding
// This function creates an account link to redirect pilots to Stripe onboarding
//
// Setup instructions:
// 1. Deploy: supabase functions deploy create-account-link
// 2. Set Stripe secret key: supabase secrets set STRIPE_SECRET_KEY=sk_test_...
//
// Request body:
// {
//   "account_id": "acct_xxx",
//   "refresh_url": "https://yourapp.com/reauth",
//   "return_url": "https://yourapp.com/return"
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
    const { account_id, refresh_url, return_url } = await req.json()

    if (!account_id) {
      return new Response(
        JSON.stringify({ error: "account_id is required" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

    // Create account link for onboarding
    const accountLink = await stripe.accountLinks.create({
      account: account_id,
      refresh_url: refresh_url || "https://yourapp.com/reauth",
      return_url: return_url || "https://yourapp.com/return",
      type: "account_onboarding",
    })

    return new Response(
      JSON.stringify({
        url: accountLink.url,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    )
  } catch (error: any) {
    console.error("Error creating account link:", error)
    return new Response(
      JSON.stringify({ error: error.message || "Failed to create account link" }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    )
  }
})

