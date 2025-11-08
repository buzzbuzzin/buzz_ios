// Supabase Edge Function to get PaymentIntent details (including charge_id)
// This function retrieves the PaymentIntent and its latest charge

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
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    const { payment_intent_id } = await req.json()

    if (!payment_intent_id) {
      return new Response(
        JSON.stringify({ error: "Missing payment_intent_id" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

    // Retrieve PaymentIntent
    const paymentIntent = await stripe.paymentIntents.retrieve(payment_intent_id)

    // Get charge ID from latest_charge
    const chargeId = typeof paymentIntent.latest_charge === "string" 
      ? paymentIntent.latest_charge 
      : paymentIntent.latest_charge?.id

    return new Response(
      JSON.stringify({
        payment_intent_id: paymentIntent.id,
        charge_id: chargeId,
        status: paymentIntent.status,
        amount: paymentIntent.amount,
        currency: paymentIntent.currency,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    )
  } catch (error: any) {
    console.error("Error retrieving payment intent:", error)
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    )
  }
})

