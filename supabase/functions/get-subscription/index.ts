// Supabase Edge Function to get customer's current subscription

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import Stripe from "https://esm.sh/stripe@14.21.0?target=deno"
import { corsHeaders, jsonResponse, requireAuthUser, requireMatchingUserId } from "../_shared/auth.ts"
import { findCustomerForUser } from "../_shared/stripeOwnership.ts"

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

    const { customer_id } = await req.json()
    const userCheck = requireMatchingUserId(auth.user.id, customer_id)
    if (userCheck.response) {
      return userCheck.response
    }

    const stripeCustomerId = await findCustomerForUser(stripe, userCheck.userId)
    if (!stripeCustomerId) {
      return jsonResponse({ subscription: null })
    }

    // Get active subscriptions for this customer
    const subscriptions = await stripe.subscriptions.list({
      customer: stripeCustomerId,
      status: "all",
      limit: 1,
    })

    if (subscriptions.data.length === 0) {
      return jsonResponse({ subscription: null })
    }

    const subscription = subscriptions.data[0]
    
    // Get the price/plan details
    const priceId = subscription.items.data[0]?.price.id
    let plan: any = null
    
    if (priceId) {
      const price = await stripe.prices.retrieve(priceId)
      plan = {
        id: price.id,
        name: price.nickname || price.id,
        price_id: price.id,
        amount: price.unit_amount || 0,
        currency: price.currency,
        interval: price.recurring?.interval || "month",
      }
    }

    return jsonResponse({
        subscription: {
          id: subscription.id,
          customer_id: userCheck.userId,
          status: subscription.status,
          current_period_start: subscription.current_period_start,
          current_period_end: subscription.current_period_end,
          cancel_at_period_end: subscription.cancel_at_period_end,
          plan: plan,
          stripe_subscription_id: subscription.id,
        },
      })
  } catch (error) {
    console.error("Error fetching subscription:", error)
    return jsonResponse({ error: error.message }, 500)
  }
})
