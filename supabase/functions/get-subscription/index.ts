// Supabase Edge Function to get customer's current subscription

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import Stripe from "https://esm.sh/stripe@14.21.0?target=deno"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

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
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    const { customer_id } = await req.json()

    if (!customer_id) {
      return new Response(
        JSON.stringify({ error: "Missing required field: customer_id" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

    // Find Stripe customer
    const existingCustomers = await stripe.customers.search({
      query: `metadata['user_id']:'${customer_id}'`,
    })
    
    if (existingCustomers.data.length === 0) {
      return new Response(
        JSON.stringify({ subscription: null }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

    const stripeCustomerId = existingCustomers.data[0].id

    // Get active subscriptions for this customer
    const subscriptions = await stripe.subscriptions.list({
      customer: stripeCustomerId,
      status: "all",
      limit: 1,
    })

    if (subscriptions.data.length === 0) {
      return new Response(
        JSON.stringify({ subscription: null }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
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

    return new Response(
      JSON.stringify({
        subscription: {
          id: subscription.id,
          customer_id: customer_id,
          status: subscription.status,
          current_period_start: subscription.current_period_start,
          current_period_end: subscription.current_period_end,
          cancel_at_period_end: subscription.cancel_at_period_end,
          plan: plan,
          stripe_subscription_id: subscription.id,
        },
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    )
  } catch (error) {
    console.error("Error fetching subscription:", error)
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    )
  }
})

