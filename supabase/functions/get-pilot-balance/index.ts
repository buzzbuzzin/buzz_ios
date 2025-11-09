import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import Stripe from "https://esm.sh/stripe@14.21.0?target=deno"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
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
    const { pilot_id } = await req.json()

    if (!pilot_id) {
      return new Response(
        JSON.stringify({ error: "pilot_id is required" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

    // Get pilot's Stripe account ID
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
        JSON.stringify({ 
          balance: 0,
          available: 0,
          pending: 0,
          currency: "usd"
        }),
        {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

    // Get balance from Stripe account
    // For Express accounts, we need to use the Balance API
    const balance = await stripe.balance.retrieve({
      stripeAccount: profile.stripe_account_id,
    })

    // Calculate available balance (available[0] is usually USD)
    const availableBalance = balance.available.find(b => b.currency === "usd") || { amount: 0, currency: "usd" }
    const pendingBalance = balance.pending.find(b => b.currency === "usd") || { amount: 0, currency: "usd" }

    return new Response(
      JSON.stringify({
        balance: availableBalance.amount + pendingBalance.amount, // Total balance
        available: availableBalance.amount, // Available for payout
        pending: pendingBalance.amount, // Pending transfers
        currency: availableBalance.currency,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    )
  } catch (error: any) {
    console.error("Error fetching balance:", error)
    return new Response(
      JSON.stringify({ 
        error: error.message,
        balance: 0,
        available: 0,
        pending: 0,
        currency: "usd"
      }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    )
  }
})

