// Supabase Edge Function to create Stripe SetupIntent for saving payment methods
// This function creates a SetupIntent to collect payment method details without charging
// Based on Stripe docs: https://docs.stripe.com/payments/mobile/set-up-future-payments

// Usage:
// 1. Deploy this function: supabase functions deploy create-setup-intent
// 2. Set Stripe secret key as environment variable:
//    supabase secrets set STRIPE_SECRET_KEY=sk_test_...

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
    const { customer_id } = await req.json()

    // Validate required fields
    if (!customer_id) {
      return new Response(
        JSON.stringify({ error: "Missing required field: customer_id" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

    // Get or create Stripe customer
    // Note: customer_id is our app's UUID, not a Stripe customer ID
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

    // Create ephemeral key for customer (required for PaymentSheet)
    let ephemeralKeySecret: string | undefined
    try {
      const ephemeralKey = await stripe.ephemeralKeys.create(
        { customer: stripeCustomerId },
        { apiVersion: "2024-11-20.acacia" }
      )
      ephemeralKeySecret = ephemeralKey.secret
    } catch (error) {
      console.log("Could not create ephemeral key:", error)
      return new Response(
        JSON.stringify({ error: "Failed to create ephemeral key" }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

    // Create SetupIntent
    // The mobile Payment Element supports cards, Bancontact, iDEAL, Link, SEPA Direct Debit, Sofort, and US bank accounts
    const setupIntent = await stripe.setupIntents.create({
      customer: stripeCustomerId,
      automatic_payment_methods: {
        enabled: true,
      },
    })

    return new Response(
      JSON.stringify({
        client_secret: setupIntent.client_secret,
        setup_intent_id: setupIntent.id,
        customer_id: stripeCustomerId,
        ephemeral_key_secret: ephemeralKeySecret,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    )
  } catch (error: any) {
    console.error("Error creating setup intent:", error)
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    )
  }
})

