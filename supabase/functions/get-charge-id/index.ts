// Supabase Edge Function to get the charge ID from a payment intent
// This is used for Search & Rescue bookings where payment happens after completion

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
  // Handle CORS preflight requests
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
      return jsonResponse({ error: "Missing required field: payment_intent_id" }, 400)
    }

    // Retrieve the payment intent to get the charge ID
    const paymentIntent = await stripe.paymentIntents.retrieve(payment_intent_id)
    const isAuthorized = await paymentIntentBelongsToUser(stripe, paymentIntent, auth.user.id)
    if (!isAuthorized) {
      return jsonResponse({ error: "Unauthorized: payment intent does not belong to authenticated user" }, 403)
    }

    // The latest charge is stored in the payment intent
    const chargeId = paymentIntent.latest_charge as string | null

    if (!chargeId) {
      return jsonResponse({
          error: "Payment intent has no associated charge",
          status: paymentIntent.status
        }, 400)
    }

    return jsonResponse({
        charge_id: chargeId,
        payment_intent_id: paymentIntent.id,
        status: paymentIntent.status,
      })
  } catch (error: any) {
    console.error("Error getting charge ID:", error)
    return jsonResponse({ error: error.message }, 500)
  }
})
