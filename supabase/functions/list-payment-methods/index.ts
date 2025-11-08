// Supabase Edge Function to list customer's saved payment methods from Stripe
// This function retrieves all payment methods attached to a Stripe customer

// Usage:
// 1. Deploy this function: supabase functions deploy list-payment-methods
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
      // Return empty list instead of error to maintain consistent response structure
      return new Response(
        JSON.stringify({
          payment_methods: [],
        }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 200,
        }
      )
    }

    // Note: customer_id is our app's UUID, not a Stripe customer ID
    // We need to find the Stripe customer by metadata
    const existingCustomers = await stripe.customers.search({
      query: `metadata['user_id']:'${customer_id}'`,
    })

    if (existingCustomers.data.length === 0) {
      // No Stripe customer found, return empty list
      return new Response(
        JSON.stringify({
          payment_methods: [],
        }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 200,
        }
      )
    }

    const stripeCustomerId = existingCustomers.data[0].id

    // List payment methods for the customer
    // According to Stripe docs: https://docs.stripe.com/payments/save-customer-payment-methods
    // Only payment methods with allow_redisplay="always" or "limited" should be displayed
    const paymentMethods = await stripe.paymentMethods.list({
      customer: stripeCustomerId,
      type: "card",
    })

    // Format payment methods for response
    // Filter to only include payment methods that can be redisplayed
    // Payment methods with allow_redisplay="unspecified" won't be shown
    const formattedPaymentMethods = paymentMethods.data
      .filter((pm) => {
        // Only include payment methods that can be redisplayed
        // allow_redisplay can be "always", "limited", or "unspecified"
        const allowRedisplay = pm.allow_redisplay || "unspecified"
        return allowRedisplay === "always" || allowRedisplay === "limited"
      })
      .map((pm) => ({
        id: pm.id,
        type: pm.type,
        card: pm.card
          ? {
              brand: pm.card.brand,
              last4: pm.card.last4,
              expMonth: pm.card.exp_month,
              expYear: pm.card.exp_year,
            }
          : null,
        created: pm.created,
        allow_redisplay: pm.allow_redisplay || "unspecified",
      }))

    return new Response(
      JSON.stringify({
        payment_methods: formattedPaymentMethods,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    )
  } catch (error: any) {
    console.error("Error listing payment methods:", error)
    // Return empty list instead of error to maintain consistent response structure
    return new Response(
      JSON.stringify({
        payment_methods: [],
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    )
  }
})

