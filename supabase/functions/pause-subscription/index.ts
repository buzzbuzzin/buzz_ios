// Supabase Edge Function to pause a subscription

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import Stripe from "https://esm.sh/stripe@14.21.0?target=deno"
import { corsHeaders, jsonResponse, requireAuthUser } from "../_shared/auth.ts"
import { subscriptionBelongsToUser } from "../_shared/stripeOwnership.ts"

const stripeSecretKey = Deno.env.get("STRIPE_SECRET_KEY")
if (!stripeSecretKey) {
  throw new Error("STRIPE_SECRET_KEY environment variable is not set")
}

const stripe = new Stripe(stripeSecretKey, {
  httpClient: Stripe.createFetchHttpClient(),
})

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    const auth = await requireAuthUser(req)
    if (auth.response) {
      return auth.response
    }

    const { subscription_id } = await req.json()

    if (!subscription_id) {
      return jsonResponse({ error: "Missing required field: subscription_id" }, 400)
    }

    const existingSubscription = await stripe.subscriptions.retrieve(subscription_id)
    const isAuthorized = await subscriptionBelongsToUser(stripe, existingSubscription, auth.user.id)
    if (!isAuthorized) {
      return jsonResponse({ error: "Unauthorized: subscription does not belong to authenticated user" }, 403)
    }

    // Pause the subscription by canceling it at period end
    // Stripe doesn't have a direct "pause" API, so we cancel at period end
    // which effectively pauses future billing
    const subscription = await stripe.subscriptions.update(subscription_id, {
      cancel_at_period_end: true,
    })

    return jsonResponse({ success: true, subscription_id: subscription.id })
  } catch (error) {
    console.error("Error pausing subscription:", error)
    return jsonResponse({ error: error.message }, 500)
  }
})
