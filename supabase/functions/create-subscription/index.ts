// Supabase Edge Function to create Stripe Subscription
// This function creates a subscription with payment_behavior: default_incomplete
// which creates a PaymentIntent for the first invoice

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
    const { customer_id, price_id } = await req.json()

    // Validate required fields
    if (!customer_id || !price_id) {
      return new Response(
        JSON.stringify({ error: "Missing required fields: customer_id, price_id" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

    // Get or create Stripe customer
    let stripeCustomerId: string
    const existingCustomers = await stripe.customers.search({
      query: `metadata['user_id']:'${customer_id}'`,
    })
    
    if (existingCustomers.data.length > 0) {
      stripeCustomerId = existingCustomers.data[0].id
    } else {
      // Create new Stripe customer with our UUID in metadata
      const newCustomer = await stripe.customers.create({
        metadata: { user_id: customer_id },
      })
      stripeCustomerId = newCustomer.id
    }

    // Create ephemeral key for customer
    let ephemeralKeySecret: string | undefined
    try {
      const ephemeralKey = await stripe.ephemeralKeys.create(
        { customer: stripeCustomerId },
        { apiVersion: "2024-11-20.acacia" }
      )
      ephemeralKeySecret = ephemeralKey.secret
    } catch (error) {
      console.log("Could not create ephemeral key:", error)
    }

    // Create subscription with default_incomplete payment behavior
    // This creates a subscription with status 'incomplete' and a PaymentIntent for the first invoice
    const subscription = await stripe.subscriptions.create({
      customer: stripeCustomerId,
      items: [{ price: price_id }],
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

    return new Response(
      JSON.stringify({
        subscription_id: subscription.id,
        client_secret: clientSecret,
        customer_id: stripeCustomerId,
        ephemeral_key_secret: ephemeralKeySecret,
        status: subscription.status,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    )
  } catch (error) {
    console.error("Error creating subscription:", error)
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    )
  }
})

