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
import { corsHeaders, jsonResponse, requireAuthUser, requireOwnedStripeAccount } from "../_shared/auth.ts"

const stripeSecretKey = Deno.env.get("STRIPE_SECRET_KEY")
if (!stripeSecretKey) {
  throw new Error("STRIPE_SECRET_KEY environment variable is not set")
}

const stripe = new Stripe(stripeSecretKey, {
  httpClient: Stripe.createFetchHttpClient(),
})

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    const auth = await requireAuthUser(req)
    if (auth.response) {
      return auth.response
    }

    const { account_id, refresh_url, return_url } = await req.json()
    const accountCheck = await requireOwnedStripeAccount(auth.user.id, account_id)
    if (accountCheck.response) {
      return accountCheck.response
    }

    // Create account link for onboarding
    const accountLink = await stripe.accountLinks.create({
      account: accountCheck.accountId,
      refresh_url: refresh_url || "https://yourapp.com/reauth",
      return_url: return_url || "https://yourapp.com/return",
      type: "account_onboarding",
    })

    return jsonResponse({
      url: accountLink.url,
    })
  } catch (error: any) {
    console.error("Error creating account link:", error)
    return jsonResponse({ error: error.message || "Failed to create account link" }, 500)
  }
})
