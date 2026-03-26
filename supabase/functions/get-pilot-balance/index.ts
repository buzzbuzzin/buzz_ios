import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import Stripe from "https://esm.sh/stripe@14.21.0?target=deno"
import { corsHeaders, jsonResponse, requireAuthUser, requireMatchingUserId, serviceSupabase } from "../_shared/auth.ts"

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

    const { pilot_id } = await req.json()
    const pilotCheck = requireMatchingUserId(auth.user.id, pilot_id)
    if (pilotCheck.response) {
      return pilotCheck.response
    }

    const pilotId = pilotCheck.userId

    // Get pilot's Stripe account ID
    const { data: profile, error: profileError } = await serviceSupabase
      .from("profiles")
      .select("stripe_account_id")
      .eq("id", pilotId)
      .single()

    if (profileError || !profile) {
      return jsonResponse({ error: "Pilot profile not found" }, 404)
    }

    if (!profile.stripe_account_id) {
      return jsonResponse({
          balance: 0,
          available: 0,
          pending: 0,
          currency: "usd"
        })
    }

    // Get balance from Stripe account
    // For Express accounts, we need to use the Balance API
    const balance = await stripe.balance.retrieve({
      stripeAccount: profile.stripe_account_id,
    })

    // Calculate available balance (available[0] is usually USD)
    const availableBalance = balance.available.find(b => b.currency === "usd") || { amount: 0, currency: "usd" }
    const pendingBalance = balance.pending.find(b => b.currency === "usd") || { amount: 0, currency: "usd" }

    return jsonResponse({
        balance: availableBalance.amount + pendingBalance.amount, // Total balance
        available: availableBalance.amount, // Available for payout
        pending: pendingBalance.amount, // Pending transfers
        currency: availableBalance.currency,
      })
  } catch (error: any) {
    console.error("Error fetching balance:", error)
    return jsonResponse({
        error: error.message,
        balance: 0,
        available: 0,
        pending: 0,
        currency: "usd"
      }, 500)
  }
})
