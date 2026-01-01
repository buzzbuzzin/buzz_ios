// Supabase Edge Function to create Stripe Transfer to pilot's connected account
// This function transfers funds from the platform account to a pilot's connected account
// when a booking is completed
//
// For automotive bookings: Creates separate transfers for each crew member based on their rank
// For other bookings: Single transfer to the assigned pilot

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

interface TransferResult {
  pilot_id: string
  transfer_id: string
  amount: number
  currency: string
  success: boolean
  error?: string
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    const { booking_id, amount, currency = "usd", charge_id } = await req.json()

    // Validate required fields
    if (!booking_id) {
      return new Response(
        JSON.stringify({ error: "Missing required field: booking_id" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

    // Get booking details from database including specialization
    const { data: booking, error: bookingError } = await supabase
      .from("bookings")
      .select("pilot_id, payment_amount, tip_amount, charge_id, specialization, transfer_id")
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

    // Use provided charge_id or booking's charge_id
    const sourceChargeId = charge_id || booking.charge_id

    // Check if this is an automotive booking with crew
    if (booking.specialization === "automotive") {
      // Handle automotive booking - transfer to all crew members
      return await handleAutomotiveTransfer(booking_id, sourceChargeId, currency, booking.transfer_id)
    }

    // Check if this is a Search & Rescue booking with crew
    if (booking.specialization === "search_rescue") {
      // Handle S&R booking - transfer equal amounts to all crew members
      return await handleSearchRescueTransfer(booking_id, sourceChargeId, currency, booking.transfer_id, amount)
    }

    // Non-automotive booking - original single pilot transfer logic
    if (!amount) {
      return new Response(
        JSON.stringify({ error: "Missing required field: amount (required for non-automotive bookings)" }),
        {
          status: 400,
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

    // Create transfer to pilot's connected account
    const transferParams: any = {
      amount: amount,
      currency: currency,
      destination: pilot.stripe_account_id,
    }

    if (sourceChargeId) {
      transferParams.source_transaction = sourceChargeId
    }

    const transfer = await stripe.transfers.create(transferParams)

    // Update booking with transfer ID (only if this is the first transfer)
    if (!booking.transfer_id) {
      const { error: updateError } = await supabase
        .from("bookings")
        .update({ transfer_id: transfer.id })
        .eq("id", booking_id)

      if (updateError) {
        console.error("Error updating booking with transfer_id:", updateError)
      }
    }

    return new Response(
      JSON.stringify({
        transfer_id: transfer.id,
        amount: transfer.amount,
        currency: transfer.currency,
        is_automotive: false,
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

/**
 * Handle transfers for automotive bookings with multiple crew members
 * Creates a separate transfer for each crew member based on their payout_amount
 */
async function handleAutomotiveTransfer(
  bookingId: string,
  chargeId: string | null,
  currency: string,
  existingTransferId: string | null
): Promise<Response> {
  // Get all crew members for this booking
  const { data: crewMembers, error: crewError } = await supabase
    .from("booking_crew")
    .select("id, pilot_id, payout_amount, transfer_id, role")
    .eq("booking_id", bookingId)

  if (crewError) {
    return new Response(
      JSON.stringify({ error: `Error fetching crew: ${crewError.message}` }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    )
  }

  if (!crewMembers || crewMembers.length === 0) {
    return new Response(
      JSON.stringify({ error: "No crew members found for this automotive booking" }),
      {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    )
  }

  // Get Stripe account IDs for all crew members
  const pilotIds = crewMembers.map(m => m.pilot_id)
  const { data: pilots, error: pilotsError } = await supabase
    .from("profiles")
    .select("id, stripe_account_id")
    .in("id", pilotIds)

  if (pilotsError || !pilots) {
    return new Response(
      JSON.stringify({ error: "Error fetching pilot profiles" }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    )
  }

  // Create a map of pilot_id to stripe_account_id
  const pilotStripeAccounts: Record<string, string> = {}
  pilots.forEach(p => {
    if (p.stripe_account_id) {
      pilotStripeAccounts[p.id] = p.stripe_account_id
    }
  })

  // Process transfers for each crew member
  const transferResults: TransferResult[] = []
  let firstTransferId: string | null = null

  for (const member of crewMembers) {
    // Skip if already paid
    if (member.transfer_id) {
      transferResults.push({
        pilot_id: member.pilot_id,
        transfer_id: member.transfer_id,
        amount: Number(member.payout_amount) * 100,
        currency,
        success: true,
      })
      continue
    }

    const stripeAccountId = pilotStripeAccounts[member.pilot_id]
    if (!stripeAccountId) {
      transferResults.push({
        pilot_id: member.pilot_id,
        transfer_id: "",
        amount: Number(member.payout_amount) * 100,
        currency,
        success: false,
        error: "Pilot does not have a Stripe connected account",
      })
      continue
    }

    try {
      // Convert payout_amount from dollars to cents for Stripe
      const amountInCents = Math.round(Number(member.payout_amount) * 100)

      const transferParams: any = {
        amount: amountInCents,
        currency,
        destination: stripeAccountId,
        metadata: {
          booking_id: bookingId,
          crew_member_id: member.id,
          role: member.role,
        },
      }

      // Link to source charge if available
      if (chargeId) {
        transferParams.source_transaction = chargeId
      }

      const transfer = await stripe.transfers.create(transferParams)

      // Update booking_crew with transfer_id
      await supabase
        .from("booking_crew")
        .update({ transfer_id: transfer.id })
        .eq("id", member.id)

      // Track first transfer for booking record
      if (!firstTransferId) {
        firstTransferId = transfer.id
      }

      transferResults.push({
        pilot_id: member.pilot_id,
        transfer_id: transfer.id,
        amount: transfer.amount,
        currency: transfer.currency,
        success: true,
      })
    } catch (error: any) {
      console.error(`Error creating transfer for pilot ${member.pilot_id}:`, error)
      transferResults.push({
        pilot_id: member.pilot_id,
        transfer_id: "",
        amount: Number(member.payout_amount) * 100,
        currency,
        success: false,
        error: error.message,
      })
    }
  }

  // Update booking with first transfer ID if not already set
  if (!existingTransferId && firstTransferId) {
    await supabase
      .from("bookings")
      .update({ transfer_id: firstTransferId })
      .eq("id", bookingId)
  }

  // Calculate summary
  const successfulTransfers = transferResults.filter(t => t.success)
  const failedTransfers = transferResults.filter(t => !t.success)
  const totalTransferred = successfulTransfers.reduce((sum, t) => sum + t.amount, 0)

  return new Response(
    JSON.stringify({
      is_automotive: true,
      crew_count: crewMembers.length,
      transfers: transferResults,
      summary: {
        successful: successfulTransfers.length,
        failed: failedTransfers.length,
        total_transferred: totalTransferred,
        currency,
      },
    }),
    {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: failedTransfers.length === crewMembers.length ? 500 : 200,
    }
  )
}

/**
 * Handle transfers for Search & Rescue bookings with multiple crew members
 * All pilots receive equal pay: hours × hourly_rate (typically $25/hour)
 */
async function handleSearchRescueTransfer(
  bookingId: string,
  chargeId: string | null,
  currency: string,
  existingTransferId: string | null,
  totalAmountInCents: number
): Promise<Response> {
  // Get booking details to get hourly rate and hours worked
  const { data: booking, error: bookingError } = await supabase
    .from("bookings")
    .select("hourly_rate, final_hours_worked, estimated_flight_hours, is_voluntary")
    .eq("id", bookingId)
    .single()

  if (bookingError || !booking) {
    return new Response(
      JSON.stringify({ error: `Error fetching booking: ${bookingError?.message}` }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    )
  }

  // For voluntary missions, no payment needed
  if (booking.is_voluntary) {
    return new Response(
      JSON.stringify({
        is_search_rescue: true,
        is_voluntary: true,
        message: "No payment needed for voluntary mission",
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    )
  }

  // Get all crew members for this booking
  const { data: crewMembers, error: crewError } = await supabase
    .from("booking_crew")
    .select("id, pilot_id, transfer_id")
    .eq("booking_id", bookingId)

  if (crewError) {
    return new Response(
      JSON.stringify({ error: `Error fetching crew: ${crewError.message}` }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    )
  }

  if (!crewMembers || crewMembers.length === 0) {
    return new Response(
      JSON.stringify({ error: "No crew members found for this Search & Rescue booking" }),
      {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    )
  }

  // Calculate equal payout per pilot
  const hoursWorked = booking.final_hours_worked || booking.estimated_flight_hours || 0
  const hourlyRate = booking.hourly_rate || 25
  const payoutPerPilotDollars = hoursWorked * hourlyRate
  const payoutPerPilotCents = Math.round(payoutPerPilotDollars * 100)

  // Get Stripe account IDs for all crew members
  const pilotIds = crewMembers.map(m => m.pilot_id)
  const { data: pilots, error: pilotsError } = await supabase
    .from("profiles")
    .select("id, stripe_account_id")
    .in("id", pilotIds)

  if (pilotsError || !pilots) {
    return new Response(
      JSON.stringify({ error: "Error fetching pilot profiles" }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    )
  }

  // Create a map of pilot_id to stripe_account_id
  const pilotStripeAccounts: Record<string, string> = {}
  pilots.forEach(p => {
    if (p.stripe_account_id) {
      pilotStripeAccounts[p.id] = p.stripe_account_id
    }
  })

  // Process transfers for each crew member
  const transferResults: TransferResult[] = []
  let firstTransferId: string | null = null

  for (const member of crewMembers) {
    // Skip if already paid
    if (member.transfer_id) {
      transferResults.push({
        pilot_id: member.pilot_id,
        transfer_id: member.transfer_id,
        amount: payoutPerPilotCents,
        currency,
        success: true,
      })
      continue
    }

    const stripeAccountId = pilotStripeAccounts[member.pilot_id]
    if (!stripeAccountId) {
      transferResults.push({
        pilot_id: member.pilot_id,
        transfer_id: "",
        amount: payoutPerPilotCents,
        currency,
        success: false,
        error: "Pilot does not have a Stripe connected account",
      })
      continue
    }

    try {
      const transferParams: any = {
        amount: payoutPerPilotCents,
        currency,
        destination: stripeAccountId,
        metadata: {
          booking_id: bookingId,
          crew_member_id: member.id,
          booking_type: "search_rescue",
          hours_worked: hoursWorked,
          hourly_rate: hourlyRate,
        },
      }

      // Link to source charge if available
      if (chargeId) {
        transferParams.source_transaction = chargeId
      }

      const transfer = await stripe.transfers.create(transferParams)

      // Update booking_crew with transfer_id and payout_amount
      await supabase
        .from("booking_crew")
        .update({ 
          transfer_id: transfer.id,
          payout_amount: payoutPerPilotDollars
        })
        .eq("id", member.id)

      // Track first transfer for booking record
      if (!firstTransferId) {
        firstTransferId = transfer.id
      }

      transferResults.push({
        pilot_id: member.pilot_id,
        transfer_id: transfer.id,
        amount: transfer.amount,
        currency: transfer.currency,
        success: true,
      })
    } catch (error: any) {
      console.error(`Error creating transfer for S&R pilot ${member.pilot_id}:`, error)
      transferResults.push({
        pilot_id: member.pilot_id,
        transfer_id: "",
        amount: payoutPerPilotCents,
        currency,
        success: false,
        error: error.message,
      })
    }
  }

  // Update booking with first transfer ID if not already set
  if (!existingTransferId && firstTransferId) {
    await supabase
      .from("bookings")
      .update({ transfer_id: firstTransferId })
      .eq("id", bookingId)
  }

  // Calculate summary
  const successfulTransfers = transferResults.filter(t => t.success)
  const failedTransfers = transferResults.filter(t => !t.success)
  const totalTransferred = successfulTransfers.reduce((sum, t) => sum + t.amount, 0)

  return new Response(
    JSON.stringify({
      is_search_rescue: true,
      crew_count: crewMembers.length,
      hours_worked: hoursWorked,
      hourly_rate: hourlyRate,
      payout_per_pilot: payoutPerPilotDollars,
      transfers: transferResults,
      summary: {
        successful: successfulTransfers.length,
        failed: failedTransfers.length,
        total_transferred: totalTransferred,
        currency,
      },
    }),
    {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: failedTransfers.length === crewMembers.length ? 500 : 200,
    }
  )
}
