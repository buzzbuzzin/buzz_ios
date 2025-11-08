// Supabase Edge Function to create Stripe Transfer to pilot's connected account
// This function transfers funds from the platform account to a pilot's connected account
// when a booking is completed

// Usage:
// 1. Deploy this function: supabase functions deploy create-transfer
// 2. Set Stripe secret key as environment variable (same as create-payment-intent):
//    supabase secrets set STRIPE_SECRET_KEY=sk_test_...

// Requirements:
// - Stripe secret key set as environment variable
// - Stripe Connect enabled on your Stripe account
// - Pilots must have stripe_account_id set in their profile

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import Stripe from "https://esm.sh/stripe@14.21.0?target=deno"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

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
    const { booking_id, amount, currency = "usd", charge_id } = await req.json()

    // Validate required fields
    if (!booking_id || !amount || !charge_id) {
      return new Response(
        JSON.stringify({ error: "Missing required fields: booking_id, amount, charge_id" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

    // Get booking details from database
    const { data: booking, error: bookingError } = await supabase
      .from("bookings")
      .select("pilot_id, payment_amount, tip_amount")
      .eq("id", booking_id)
      .single()

    if (bookingError || !booking) {
      return new Response(
        JSON.stringify({ error: "Booking not found" }),
        {
          status: 404,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

    if (!booking.pilot_id) {
      return new Response(
        JSON.stringify({ error: "Booking has no assigned pilot" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

    // Get pilot's Stripe account ID
    const { data: pilot, error: pilotError } = await supabase
      .from("profiles")
      .select("stripe_account_id")
      .eq("id", booking.pilot_id)
      .single()

    if (pilotError || !pilot) {
      return new Response(
        JSON.stringify({ error: "Pilot not found" }),
        {
          status: 404,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

    if (!pilot.stripe_account_id) {
      return new Response(
        JSON.stringify({ error: "Pilot does not have a Stripe connected account" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

    // Calculate transfer amount (payment_amount + tip_amount)
    const paymentAmount = parseFloat(booking.payment_amount) || 0
    const tipAmount = parseFloat(booking.tip_amount) || 0
    const totalAmount = Math.round((paymentAmount + tipAmount) * 100) // Convert to cents

    // Use the provided amount if it matches, otherwise use calculated amount
    const transferAmount = amount === totalAmount ? amount : totalAmount

    // Create transfer to pilot's connected account
    // Using source_transaction links the transfer to the charge
    const transfer = await stripe.transfers.create({
      amount: transferAmount,
      currency: currency,
      destination: pilot.stripe_account_id,
      source_transaction: charge_id, // Links transfer to the charge
    })

    // Update booking with transfer ID
    const { error: updateError } = await supabase
      .from("bookings")
      .update({ transfer_id: transfer.id })
      .eq("id", booking_id)

    if (updateError) {
      console.error("Error updating booking with transfer_id:", updateError)
      // Don't fail the request, transfer was successful
    }

    return new Response(
      JSON.stringify({
        transfer_id: transfer.id,
        amount: transfer.amount,
        currency: transfer.currency,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    )
  } catch (error: any) {
    console.error("Error creating transfer:", error)
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    )
  }
})

