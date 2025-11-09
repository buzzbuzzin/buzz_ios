// Supabase Edge Function to check Stripe connected account status
// This function checks the status of a Stripe Express connected account
//
// Setup instructions:
// 1. Deploy: supabase functions deploy check-account-status
// 2. Set Stripe secret key: supabase secrets set STRIPE_SECRET_KEY=sk_test_...
//
// Request body:
// {
//   "account_id": "acct_xxx"
// }

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const stripeSecretKey = Deno.env.get("STRIPE_SECRET_KEY")
if (!stripeSecretKey) {
  throw new Error("STRIPE_SECRET_KEY environment variable is not set")
}

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
    const { account_id } = await req.json()

    if (!account_id) {
      return new Response(
        JSON.stringify({ error: "account_id is required" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

    // Retrieve account details from Stripe using direct HTTP call
    const stripeResponse = await fetch(`https://api.stripe.com/v1/accounts/${account_id}`, {
      method: "GET",
      headers: {
        "Authorization": `Bearer ${stripeSecretKey}`,
      },
    })

    if (!stripeResponse.ok) {
      const errorData = await stripeResponse.json()
      throw new Error(errorData.error?.message || "Failed to retrieve account")
    }

    const account = await stripeResponse.json()

    // Determine status based on account details
    let status = "onboarding"
    if (account.details_submitted && account.charges_enabled && account.payouts_enabled) {
      status = "active"
    } else if (account.details_submitted && !account.charges_enabled) {
      status = "pending"
    } else if (account.requirements?.currently_due?.length > 0) {
      status = "onboarding"
    }

    // Check if account is restricted
    if (account.requirements?.disabled_reason) {
      status = "restricted"
    }

    return new Response(
      JSON.stringify({
        account_id: account.id,
        status: status,
        details_submitted: account.details_submitted,
        charges_enabled: account.charges_enabled,
        payouts_enabled: account.payouts_enabled,
        requirements: account.requirements ? {
          currently_due: account.requirements.currently_due,
          disabled_reason: account.requirements.disabled_reason,
        } : null,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    )
  } catch (error: any) {
    console.error("Error checking account status:", error)
    return new Response(
      JSON.stringify({ error: error.message || "Failed to check account status" }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    )
  }
})

