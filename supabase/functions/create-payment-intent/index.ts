// Supabase Edge Function to create Stripe PaymentIntent with transfer_group
// This function creates a PaymentIntent on the platform account with a transfer_group
// that will be used later to transfer funds to connected accounts (pilots)
// Supports applying referral credits to reduce the payment amount

// Usage:
// 1. Deploy this function: supabase functions deploy create-payment-intent
// 2. Set Stripe secret key as environment variable:
//    supabase secrets set STRIPE_SECRET_KEY=sk_test_...

// Requirements:
// - Stripe secret key set as environment variable
// - Stripe Connect enabled on your Stripe account

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import Stripe from "https://esm.sh/stripe@14.21.0?target=deno"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const stripeSecretKey = Deno.env.get("STRIPE_SECRET_KEY")
if (!stripeSecretKey) {
  throw new Error("STRIPE_SECRET_KEY environment variable is not set")
}

const supabaseUrl = Deno.env.get("SUPABASE_URL")!
const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!

const stripe = new Stripe(stripeSecretKey, {
  httpClient: Stripe.createFetchHttpClient(),
})

const supabase = createClient(supabaseUrl, supabaseServiceKey)

const ALLOWED_ORIGIN = Deno.env.get("ALLOWED_ORIGIN") || "*"

const corsHeaders = {
  "Access-Control-Allow-Origin": ALLOWED_ORIGIN,
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    // Verify the caller's identity via JWT
    const authHeader = req.headers.get("Authorization")
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "Missing Authorization header" }),
        {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

    const userClient = createClient(supabaseUrl, Deno.env.get("SUPABASE_ANON_KEY") || "", {
      global: { headers: { Authorization: authHeader } },
      auth: { autoRefreshToken: false, persistSession: false },
    })
    const { data: { user }, error: authError } = await userClient.auth.getUser()
    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: "Invalid or expired token" }),
        {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

    const {
      amount,
      currency = "usd",
      customer_id,
      transfer_group,
      credits_to_use = 0  // Amount of referral credits to apply (in dollars)
    } = await req.json()

    // Verify the authenticated user matches the customer_id
    if (customer_id && user.id !== customer_id) {
      return new Response(
        JSON.stringify({ error: "Unauthorized: user does not match customer_id" }),
        {
          status: 403,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

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

    // Original amount in cents
    const originalAmountCents = amount

    // Calculate credits to apply
    let creditsAppliedCents = 0
    let finalAmountCents = originalAmountCents

    if (credits_to_use > 0 && customer_id) {
      // Validate user has sufficient credits
      const { data: profile, error: profileError } = await supabase
        .from("profiles")
        .select("referral_credits")
        .eq("id", customer_id)
        .single()

      if (profileError || !profile) {
        return new Response(
          JSON.stringify({ error: "User profile not found" }),
          {
            status: 404,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          }
        )
      }

      const availableCredits = profile.referral_credits || 0
      const creditsToUseDollars = Math.min(credits_to_use, availableCredits)
      creditsAppliedCents = Math.floor(creditsToUseDollars * 100)

      // Validate sufficient credits
      if (credits_to_use > availableCredits) {
        return new Response(
          JSON.stringify({ 
            error: "Insufficient credits",
            available_credits: availableCredits,
            requested_credits: credits_to_use
          }),
          {
            status: 400,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          }
        )
      }

      // Calculate final amount (minimum $0.50 for Stripe)
      finalAmountCents = Math.max(originalAmountCents - creditsAppliedCents, 50)
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

    // Create PaymentIntent with the final amount (after credits)
    // Store original amount and credits in metadata for record keeping
    const paymentIntent = await stripe.paymentIntents.create({
      amount: finalAmountCents,
      currency: currency,
      customer: customerId,
      transfer_group: transfer_group,
      metadata: {
        original_amount_cents: originalAmountCents.toString(),
        credits_applied_cents: creditsAppliedCents.toString(),
        user_id: customer_id || "",
      },
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
        // Include credit information in response
        original_amount: originalAmountCents,
        credits_applied: creditsAppliedCents,
        final_amount: finalAmountCents,
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
