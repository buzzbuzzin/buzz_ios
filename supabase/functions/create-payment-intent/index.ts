// Supabase Edge Function to create Stripe PaymentIntent with transfer_group
// This function creates a PaymentIntent on the platform account with a transfer_group
// that will be used later to transfer funds to connected accounts (pilots)

// Usage:
// 1. Deploy this function: supabase functions deploy create-payment-intent
// 2. Set Stripe secret key as environment variable:
//    supabase secrets set STRIPE_SECRET_KEY=sk_test_...

// Requirements:
// - Stripe secret key set as environment variable
// - Stripe Connect enabled on your Stripe account

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
    const { amount, currency = "usd", customer_id, transfer_group } = await req.json()

    // Validate required fields
    if (!amount || !transfer_group) {
      return new Response(
        JSON.stringify({ error: "Missing required fields: amount, transfer_group" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

    // Create or retrieve customer
    // Note: customer_id is our app's UUID, not a Stripe customer ID
    // We'll create a Stripe customer and store the mapping in metadata
    let customerId: string | undefined
    if (customer_id) {
      // Search for existing customer by metadata
      const existingCustomers = await stripe.customers.search({
        query: `metadata['user_id']:'${customer_id}'`,
      })
      
      if (existingCustomers.data.length > 0) {
        customerId = existingCustomers.data[0].id
      } else {
        // Create new Stripe customer with our UUID in metadata
        const newCustomer = await stripe.customers.create({
          metadata: { user_id: customer_id },
        })
        customerId = newCustomer.id
      }
    } else {
      // Create anonymous customer
      const customer = await stripe.customers.create()
      customerId = customer.id
    }

    // Create ephemeral key for customer (optional, for saving payment methods)
    let ephemeralKeySecret: string | undefined
    try {
      const ephemeralKey = await stripe.ephemeralKeys.create(
        { customer: customerId },
        { apiVersion: "2024-11-20.acacia" }
      )
      ephemeralKeySecret = ephemeralKey.secret
    } catch (error) {
      console.log("Could not create ephemeral key:", error)
      // Continue without ephemeral key (guest checkout)
    }

    // Create PaymentIntent with transfer_group
    const paymentIntent = await stripe.paymentIntents.create({
      amount: amount,
      currency: currency,
      customer: customerId,
      transfer_group: transfer_group,
      automatic_payment_methods: {
        enabled: true,
      },
    })

    return new Response(
      JSON.stringify({
        client_secret: paymentIntent.client_secret,
        payment_intent_id: paymentIntent.id,
        customer_id: customerId,
        ephemeral_key_secret: ephemeralKeySecret,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    )
  } catch (error: any) {
    console.error("Error creating payment intent:", error)
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    )
  }
})

