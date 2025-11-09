import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import Stripe from "https://esm.sh/stripe@14.21.0?target=deno"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
}

const stripeSecretKey = Deno.env.get("STRIPE_SECRET_KEY")
if (!stripeSecretKey) {
  throw new Error("STRIPE_SECRET_KEY environment variable is not set")
}

const supabaseUrl = Deno.env.get("SUPABASE_URL") || ""
const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || ""

const stripe = new Stripe(stripeSecretKey, {
  httpClient: Stripe.createFetchHttpClient(),
})

const supabase = createClient(supabaseUrl, supabaseServiceKey)

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    const { pilot_id, amount, currency = "usd" } = await req.json()

    // Validate required fields
    if (!pilot_id || !amount || amount <= 0) {
      return new Response(
        JSON.stringify({ error: "Invalid request. pilot_id and amount are required." }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

    // Get pilot profile with Stripe account ID
    const { data: profile, error: profileError } = await supabase
      .from("profiles")
      .select("stripe_account_id")
      .eq("id", pilot_id)
      .single()

    if (profileError || !profile) {
      return new Response(
        JSON.stringify({ error: "Pilot profile not found" }),
        {
          status: 404,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

    if (!profile.stripe_account_id) {
      return new Response(
        JSON.stringify({ error: "Pilot does not have a Stripe connected account" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

    // Get current balance from Stripe account
    const balance = await stripe.balance.retrieve({
      stripeAccount: profile.stripe_account_id,
    })

    // Get available balance
    const availableBalance = balance.available.find(b => b.currency === currency) || { amount: 0, currency }
    
    // Check if balance is sufficient
    if (availableBalance.amount < amount) {
      return new Response(
        JSON.stringify({ 
          success: false,
          error: "Insufficient balance",
          message: `Available balance: $${(availableBalance.amount / 100).toFixed(2)}, requested: $${(amount / 100).toFixed(2)}`
        }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

    // Create payout from Stripe account balance
    const payout = await stripe.payouts.create({
      amount: amount,
      currency: currency,
    }, {
      stripeAccount: profile.stripe_account_id, // Create payout from connected account
    })

    return new Response(
      JSON.stringify({
        success: true,
        payout_id: payout.id,
        amount: payout.amount,
        currency: payout.currency,
        arrival_date: payout.arrival_date,
        message: "Withdrawal successful",
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    )
  } catch (error: any) {
    console.error("Error processing withdrawal:", error)
    return new Response(
      JSON.stringify({ 
        success: false,
        error: error.message,
        message: error.message
      }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    )
  }
})

