// Supabase Edge Function to get PaymentIntent details (including charge_id)
// This function retrieves the PaymentIntent and its latest charge

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import Stripe from "https://esm.sh/stripe@14.21.0?target=deno"
import { corsHeaders, jsonResponse, requireAuthUser } from "../_shared/auth.ts"
import { paymentIntentBelongsToUser } from "../_shared/stripeOwnership.ts"

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

    const { payment_intent_id } = await req.json()

    if (!payment_intent_id) {
      return jsonResponse({ error: "Missing payment_intent_id" }, 400)
    }

    // Retrieve PaymentIntent
    const paymentIntent = await stripe.paymentIntents.retrieve(payment_intent_id)
    const isAuthorized = await paymentIntentBelongsToUser(stripe, paymentIntent, auth.user.id)
    if (!isAuthorized) {
      return jsonResponse({ error: "Unauthorized: payment intent does not belong to authenticated user" }, 403)
    }

    // Get charge ID from latest_charge
    const chargeId = typeof paymentIntent.latest_charge === "string" 
      ? paymentIntent.latest_charge 
      : paymentIntent.latest_charge?.id

    return jsonResponse({
        payment_intent_id: paymentIntent.id,
        charge_id: chargeId,
        status: paymentIntent.status,
        amount: paymentIntent.amount,
        currency: paymentIntent.currency,
      })
  } catch (error: any) {
    console.error("Error retrieving payment intent:", error)
    return jsonResponse({ error: error.message }, 500)
  }
})
