// Supabase Edge Function to create Stripe Subscription
// This function creates a subscription with payment_behavior: default_incomplete
// which creates a PaymentIntent for the first invoice

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import Stripe from "https://esm.sh/stripe@14.21.0?target=deno"
import { corsHeaders, jsonResponse, requireAuthUser, requireMatchingUserId } from "../_shared/auth.ts"
import { findOrCreateCustomerForUser } from "../_shared/stripeOwnership.ts"

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

    const { customer_id, price_id } = await req.json()
    const userCheck = requireMatchingUserId(auth.user.id, customer_id)
    if (userCheck.response) {
      return userCheck.response
    }

    // Validate required fields
    if (!price_id) {
      return jsonResponse({ error: "Missing required field: price_id" }, 400)
    }

    const userId = userCheck.userId
    const stripeCustomerId = await findOrCreateCustomerForUser(stripe, userId)

    // Create ephemeral key for customer (required for PaymentSheet to show "Save payment details" checkbox)
    let ephemeralKeySecret: string | undefined
    try {
      const ephemeralKey = await stripe.ephemeralKeys.create(
        { customer: stripeCustomerId },
        { apiVersion: "2024-11-20.acacia" }
      )
      ephemeralKeySecret = ephemeralKey.secret
    } catch (error) {
      console.error("Could not create ephemeral key:", error)
      // Return error instead of continuing silently
      // Ephemeral key is required for PaymentSheet to show "Save payment details" checkbox
      return jsonResponse({ error: "Failed to create ephemeral key for customer" }, 500)
    }
    
    if (!ephemeralKeySecret) {
      return jsonResponse({ error: "Ephemeral key secret is missing" }, 500)
    }

    // Create subscription with default_incomplete payment behavior
    // This creates a subscription with status 'incomplete' and a PaymentIntent for the first invoice
    // Note: save_default_payment_method is set to "on_subscription" to ensure payment method is saved
    // for recurring charges. The PaymentSheet will still show "Save payment details" checkbox
    // when customer + ephemeral key are provided (which we ensure above).
    const subscription = await stripe.subscriptions.create({
      customer: stripeCustomerId,
      items: [{ price: price_id }],
      metadata: { user_id: userId },
      payment_behavior: "default_incomplete",
      payment_settings: { save_default_payment_method: "on_subscription" },
      expand: ["latest_invoice.payment_intent"],
    })

    // Get the PaymentIntent client secret from the latest invoice
    const invoice = subscription.latest_invoice as Stripe.Invoice
    const paymentIntent = invoice.payment_intent as Stripe.PaymentIntent
    const clientSecret = paymentIntent.client_secret

    if (!clientSecret) {
      throw new Error("Failed to get PaymentIntent client secret")
    }

    // Store subscription in database (you'll need to create a subscriptions table)
    // For now, we'll return the subscription info

    return jsonResponse({
        subscription_id: subscription.id,
        client_secret: clientSecret,
        customer_id: stripeCustomerId,
        ephemeral_key_secret: ephemeralKeySecret,
        status: subscription.status,
      })
  } catch (error) {
    console.error("Error creating subscription:", error)
    return jsonResponse({ error: error.message }, 500)
  }
})
