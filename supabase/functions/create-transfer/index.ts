// Supabase Edge Function to create Stripe transfers for completed bookings and paid tips.
// The caller must be authenticated and authorized for the target booking.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import Stripe from "https://esm.sh/stripe@14.21.0?target=deno"
import { corsHeaders, jsonResponse, requireAuthUser, serviceSupabase as supabase } from "../_shared/auth.ts"

const stripeSecretKey = Deno.env.get("STRIPE_SECRET_KEY")
if (!stripeSecretKey) {
  throw new Error("STRIPE_SECRET_KEY environment variable is not set")
}

const stripe = new Stripe(stripeSecretKey, {
  httpClient: Stripe.createFetchHttpClient(),
})

type TransferType = "booking" | "tip"

interface TransferResult {
  pilot_id: string
  transfer_id: string
  amount: number
  currency: string
  success: boolean
  error?: string
  requires_reconciliation?: boolean
}

interface BookingRecord {
  id: string
  customer_id: string
  pilot_id: string | null
  payment_amount: number | string | null
  tip_amount: number | string | null
  charge_id: string | null
  tip_charge_id: string | null
  specialization: string | null
  status: string
  transfer_id: string | null
  tip_transfer_id: string | null
}

interface CrewMember {
  id: string
  pilot_id: string
  payout_amount: number | string | null
  transfer_id: string | null
  role: string
}

function toCents(value: number | string | null | undefined): number {
  return Math.max(0, Math.round(Number(value ?? 0) * 100))
}

function updatePayload(column: string, value: string | null) {
  return { [column]: value, updated_at: new Date().toISOString() }
}

async function fetchBooking(bookingId: string): Promise<BookingRecord | null> {
  const { data, error } = await supabase
    .from("bookings")
    .select("id, customer_id, pilot_id, payment_amount, tip_amount, charge_id, tip_charge_id, specialization, status, transfer_id, tip_transfer_id")
    .eq("id", bookingId)
    .maybeSingle()

  if (error) {
    console.error("Error fetching booking:", error)
    return null
  }

  return data as BookingRecord | null
}

async function isAuthorizedForBooking(userId: string, booking: BookingRecord, transferType: TransferType): Promise<boolean> {
  if (transferType === "tip") {
    return booking.customer_id === userId
  }

  if (booking.customer_id === userId || booking.pilot_id === userId) {
    return true
  }

  if (booking.specialization !== "automotive" && booking.specialization !== "search_rescue") {
    return false
  }

  const { data, error } = await supabase
    .from("booking_crew")
    .select("id")
    .eq("booking_id", booking.id)
    .eq("pilot_id", userId)
    .maybeSingle()

  if (error) {
    console.error("Error checking crew authorization:", error)
    return false
  }

  return !!data
}

async function claimBookingTransfer(bookingId: string, column: "transfer_id" | "tip_transfer_id") {
  const { data, error } = await supabase
    .from("bookings")
    .update(updatePayload(column, "pending"))
    .eq("id", bookingId)
    .is(column, null)
    .select("id")
    .maybeSingle()

  return { data, error }
}

async function resetBookingClaim(bookingId: string, column: "transfer_id" | "tip_transfer_id") {
  await supabase
    .from("bookings")
    .update(updatePayload(column, null))
    .eq("id", bookingId)
    .eq(column, "pending")
}

async function finalizeBookingClaim(bookingId: string, column: "transfer_id" | "tip_transfer_id", transferId: string) {
  const { data, error } = await supabase
    .from("bookings")
    .update(updatePayload(column, transferId))
    .eq("id", bookingId)
    .eq(column, "pending")
    .select("id")
    .maybeSingle()

  return { data, error }
}

async function claimCrewTransfer(crewId: string) {
  const { data, error } = await supabase
    .from("booking_crew")
    .update(updatePayload("transfer_id", "pending"))
    .eq("id", crewId)
    .is("transfer_id", null)
    .select("id")
    .maybeSingle()

  return { data, error }
}

async function resetCrewClaim(crewId: string) {
  await supabase
    .from("booking_crew")
    .update(updatePayload("transfer_id", null))
    .eq("id", crewId)
    .eq("transfer_id", "pending")
}

async function finalizeCrewClaim(crewId: string, transferId: string) {
  const { data, error } = await supabase
    .from("booking_crew")
    .update(updatePayload("transfer_id", transferId))
    .eq("id", crewId)
    .eq("transfer_id", "pending")
    .select("id")
    .maybeSingle()

  return { data, error }
}

async function getPilotStripeAccount(pilotId: string) {
  const { data, error } = await supabase
    .from("profiles")
    .select("stripe_account_id")
    .eq("id", pilotId)
    .maybeSingle()

  if (error || !data) {
    return { error: jsonResponse({ error: "Pilot not found" }, 404) }
  }

  if (!data.stripe_account_id) {
    return { error: jsonResponse({ error: "Pilot does not have a Stripe connected account" }, 400) }
  }

  return { stripeAccountId: data.stripe_account_id as string }
}

async function handleStandardBookingTransfer(
  booking: BookingRecord,
  currency: string,
  requestChargeId: string | null,
) {
  if (!booking.pilot_id) {
    return jsonResponse({ error: "Booking has no assigned pilot" }, 400)
  }

  const includesLegacyTipInBaseTransfer = !booking.tip_charge_id && !booking.tip_transfer_id
  const amountInCents = toCents(booking.payment_amount) + (includesLegacyTipInBaseTransfer ? toCents(booking.tip_amount) : 0)
  if (amountInCents <= 0) {
    return jsonResponse({ error: "Booking has no payable amount" }, 400)
  }

  if (booking.transfer_id && booking.transfer_id !== "pending") {
    return jsonResponse({
      transfer_id: booking.transfer_id,
      amount: amountInCents,
      currency,
      is_automotive: false,
    })
  }

  const { stripeAccountId, error: accountError } = await getPilotStripeAccount(booking.pilot_id)
  if (accountError) {
    return accountError
  }

  const claim = await claimBookingTransfer(booking.id, "transfer_id")
  if (claim.error) {
    console.error("Error claiming booking transfer:", claim.error)
    return jsonResponse({ error: "Failed to claim booking transfer" }, 500)
  }

  if (!claim.data) {
    const freshBooking = await fetchBooking(booking.id)
    if (freshBooking?.transfer_id && freshBooking.transfer_id !== "pending") {
      return jsonResponse({
        transfer_id: freshBooking.transfer_id,
        amount: amountInCents,
        currency,
        is_automotive: false,
      })
    }
    return jsonResponse({ error: "Transfer is already being processed for this booking" }, 409)
  }

  const sourceChargeId = requestChargeId || booking.charge_id
  const transferParams: Record<string, unknown> = {
    amount: amountInCents,
    currency,
    destination: stripeAccountId,
    metadata: {
      booking_id: booking.id,
      transfer_type: "booking",
    },
  }

  if (sourceChargeId) {
    transferParams.source_transaction = sourceChargeId
  }

  let transfer: Stripe.Transfer
  try {
    transfer = await stripe.transfers.create(transferParams)
  } catch (error: any) {
    await resetBookingClaim(booking.id, "transfer_id")
    console.error("Error creating booking transfer:", error)
    return jsonResponse({ error: error.message }, 502)
  }

  const finalize = await finalizeBookingClaim(booking.id, "transfer_id", transfer.id)
  if (finalize.error || !finalize.data) {
    console.error("CRITICAL: transfer created but booking update failed", {
      booking_id: booking.id,
      transfer_id: transfer.id,
      error: finalize.error,
    })
    return jsonResponse({
      error: "Transfer was created but database update failed. Contact support.",
      transfer_id: transfer.id,
      requires_reconciliation: true,
    }, 500)
  }

  return jsonResponse({
    transfer_id: transfer.id,
    amount: transfer.amount,
    currency: transfer.currency,
    is_automotive: false,
  })
}

async function handleTipTransfer(
  booking: BookingRecord,
  currency: string,
  requestChargeId: string | null,
) {
  if (booking.specialization === "automotive" || booking.specialization === "search_rescue") {
    return jsonResponse({ error: "Tips are only supported for single-pilot bookings" }, 400)
  }

  if (booking.status !== "completed") {
    return jsonResponse({ error: "Tips can only be transferred after the booking is completed" }, 400)
  }

  if (!booking.pilot_id) {
    return jsonResponse({ error: "Booking has no assigned pilot" }, 400)
  }

  const amountInCents = toCents(booking.tip_amount)
  if (amountInCents <= 0) {
    return jsonResponse({ error: "Booking has no paid tip to transfer" }, 400)
  }

  if (booking.tip_transfer_id && booking.tip_transfer_id !== "pending") {
    return jsonResponse({
      transfer_id: booking.tip_transfer_id,
      amount: amountInCents,
      currency,
      is_tip: true,
    })
  }

  const { stripeAccountId, error: accountError } = await getPilotStripeAccount(booking.pilot_id)
  if (accountError) {
    return accountError
  }

  const sourceChargeId = requestChargeId || booking.tip_charge_id
  if (!sourceChargeId) {
    return jsonResponse({ error: "Missing paid tip charge for transfer" }, 400)
  }

  const claim = await claimBookingTransfer(booking.id, "tip_transfer_id")
  if (claim.error) {
    console.error("Error claiming tip transfer:", claim.error)
    return jsonResponse({ error: "Failed to claim tip transfer" }, 500)
  }

  if (!claim.data) {
    const freshBooking = await fetchBooking(booking.id)
    if (freshBooking?.tip_transfer_id && freshBooking.tip_transfer_id !== "pending") {
      return jsonResponse({
        transfer_id: freshBooking.tip_transfer_id,
        amount: amountInCents,
        currency,
        is_tip: true,
      })
    }
    return jsonResponse({ error: "Tip transfer is already being processed for this booking" }, 409)
  }

  let transfer: Stripe.Transfer
  try {
    transfer = await stripe.transfers.create({
      amount: amountInCents,
      currency,
      destination: stripeAccountId,
      source_transaction: sourceChargeId,
      metadata: {
        booking_id: booking.id,
        transfer_type: "tip",
      },
    })
  } catch (error: any) {
    await resetBookingClaim(booking.id, "tip_transfer_id")
    console.error("Error creating tip transfer:", error)
    return jsonResponse({ error: error.message }, 502)
  }

  const finalize = await finalizeBookingClaim(booking.id, "tip_transfer_id", transfer.id)
  if (finalize.error || !finalize.data) {
    console.error("CRITICAL: tip transfer created but booking update failed", {
      booking_id: booking.id,
      transfer_id: transfer.id,
      error: finalize.error,
    })
    return jsonResponse({
      error: "Tip transfer was created but database update failed. Contact support.",
      transfer_id: transfer.id,
      requires_reconciliation: true,
    }, 500)
  }

  return jsonResponse({
    transfer_id: transfer.id,
    amount: transfer.amount,
    currency: transfer.currency,
    is_tip: true,
  })
}

async function handleAutomotiveTransfer(
  booking: BookingRecord,
  currency: string,
  chargeId: string | null,
) {
  const { data: crewMembers, error: crewError } = await supabase
    .from("booking_crew")
    .select("id, pilot_id, payout_amount, transfer_id, role")
    .eq("booking_id", booking.id)

  if (crewError) {
    return jsonResponse({ error: `Error fetching crew: ${crewError.message}` }, 500)
  }

  if (!crewMembers || crewMembers.length === 0) {
    return jsonResponse({ error: "No crew members found for this automotive booking" }, 400)
  }

  const pilotIds = crewMembers.map((member: CrewMember) => member.pilot_id)
  const { data: pilots, error: pilotsError } = await supabase
    .from("profiles")
    .select("id, stripe_account_id")
    .in("id", pilotIds)

  if (pilotsError || !pilots) {
    return jsonResponse({ error: "Error fetching pilot profiles" }, 500)
  }

  const pilotStripeAccounts: Record<string, string> = {}
  pilots.forEach((pilot) => {
    if (pilot.stripe_account_id) {
      pilotStripeAccounts[pilot.id] = pilot.stripe_account_id
    }
  })

  const transferResults: TransferResult[] = []
  let firstTransferId: string | null = booking.transfer_id && booking.transfer_id !== "pending" ? booking.transfer_id : null

  for (const member of crewMembers as CrewMember[]) {
    const amountInCents = toCents(member.payout_amount)

    if (member.transfer_id && member.transfer_id !== "pending") {
      transferResults.push({
        pilot_id: member.pilot_id,
        transfer_id: member.transfer_id,
        amount: amountInCents,
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
        amount: amountInCents,
        currency,
        success: false,
        error: "Pilot does not have a Stripe connected account",
      })
      continue
    }

    const claim = await claimCrewTransfer(member.id)
    if (claim.error) {
      transferResults.push({
        pilot_id: member.pilot_id,
        transfer_id: "",
        amount: amountInCents,
        currency,
        success: false,
        error: "Failed to claim crew payout",
      })
      continue
    }

    if (!claim.data) {
      const { data: freshMember } = await supabase
        .from("booking_crew")
        .select("transfer_id")
        .eq("id", member.id)
        .maybeSingle()

      if (freshMember?.transfer_id && freshMember.transfer_id !== "pending") {
        transferResults.push({
          pilot_id: member.pilot_id,
          transfer_id: freshMember.transfer_id,
          amount: amountInCents,
          currency,
          success: true,
        })
      } else {
        transferResults.push({
          pilot_id: member.pilot_id,
          transfer_id: "",
          amount: amountInCents,
          currency,
          success: false,
          error: "Transfer already in progress for this crew member",
        })
      }
      continue
    }

    try {
      const transferParams: Record<string, unknown> = {
        amount: amountInCents,
        currency,
        destination: stripeAccountId,
        metadata: {
          booking_id: booking.id,
          crew_member_id: member.id,
          role: member.role,
          transfer_type: "booking",
        },
      }

      if (chargeId) {
        transferParams.source_transaction = chargeId
      }

      const transfer = await stripe.transfers.create(transferParams)
      const finalize = await finalizeCrewClaim(member.id, transfer.id)
      if (finalize.error || !finalize.data) {
        console.error("CRITICAL: crew transfer created but booking_crew update failed", {
          crew_id: member.id,
          transfer_id: transfer.id,
          error: finalize.error,
        })
        transferResults.push({
          pilot_id: member.pilot_id,
          transfer_id: transfer.id,
          amount: transfer.amount,
          currency: transfer.currency,
          success: false,
          error: "Transfer created but database update failed",
          requires_reconciliation: true,
        })
        continue
      }

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
      await resetCrewClaim(member.id)
      console.error(`Error creating transfer for pilot ${member.pilot_id}:`, error)
      transferResults.push({
        pilot_id: member.pilot_id,
        transfer_id: "",
        amount: amountInCents,
        currency,
        success: false,
        error: error.message,
      })
    }
  }

  if (!booking.transfer_id && firstTransferId) {
    await supabase
      .from("bookings")
      .update(updatePayload("transfer_id", firstTransferId))
      .eq("id", booking.id)
      .is("transfer_id", null)
  }

  const successfulTransfers = transferResults.filter((transfer) => transfer.success)
  const failedTransfers = transferResults.filter((transfer) => !transfer.success)
  const totalTransferred = successfulTransfers.reduce((sum, transfer) => sum + transfer.amount, 0)

  return jsonResponse({
    is_automotive: true,
    crew_count: crewMembers.length,
    transfers: transferResults,
    summary: {
      successful: successfulTransfers.length,
      failed: failedTransfers.length,
      total_transferred: totalTransferred,
      currency,
    },
  }, failedTransfers.length === crewMembers.length ? 500 : 200)
}

async function handleSearchRescueTransfer(
  booking: BookingRecord,
  currency: string,
  chargeId: string | null,
) {
  const { data: bookingDetails, error: bookingError } = await supabase
    .from("bookings")
    .select("hourly_rate, final_hours_worked, estimated_flight_hours, is_voluntary")
    .eq("id", booking.id)
    .maybeSingle()

  if (bookingError || !bookingDetails) {
    return jsonResponse({ error: `Error fetching booking: ${bookingError?.message ?? "unknown"}` }, 500)
  }

  if (bookingDetails.is_voluntary) {
    return jsonResponse({
      is_search_rescue: true,
      is_voluntary: true,
      message: "No payment needed for voluntary mission",
    })
  }

  const { data: crewMembers, error: crewError } = await supabase
    .from("booking_crew")
    .select("id, pilot_id, transfer_id")
    .eq("booking_id", booking.id)

  if (crewError) {
    return jsonResponse({ error: `Error fetching crew: ${crewError.message}` }, 500)
  }

  if (!crewMembers || crewMembers.length === 0) {
    return jsonResponse({ error: "No crew members found for this Search & Rescue booking" }, 400)
  }

  const hoursWorked = Number(bookingDetails.final_hours_worked ?? bookingDetails.estimated_flight_hours ?? 0)
  const hourlyRate = Number(bookingDetails.hourly_rate ?? 25)
  const payoutPerPilotDollars = hoursWorked * hourlyRate
  const payoutPerPilotCents = Math.round(payoutPerPilotDollars * 100)

  const pilotIds = crewMembers.map((member: { pilot_id: string }) => member.pilot_id)
  const { data: pilots, error: pilotsError } = await supabase
    .from("profiles")
    .select("id, stripe_account_id")
    .in("id", pilotIds)

  if (pilotsError || !pilots) {
    return jsonResponse({ error: "Error fetching pilot profiles" }, 500)
  }

  const pilotStripeAccounts: Record<string, string> = {}
  pilots.forEach((pilot) => {
    if (pilot.stripe_account_id) {
      pilotStripeAccounts[pilot.id] = pilot.stripe_account_id
    }
  })

  const transferResults: TransferResult[] = []
  let firstTransferId: string | null = booking.transfer_id && booking.transfer_id !== "pending" ? booking.transfer_id : null

  for (const member of crewMembers as Array<{ id: string; pilot_id: string; transfer_id: string | null }>) {
    if (member.transfer_id && member.transfer_id !== "pending") {
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

    const claim = await claimCrewTransfer(member.id)
    if (claim.error) {
      transferResults.push({
        pilot_id: member.pilot_id,
        transfer_id: "",
        amount: payoutPerPilotCents,
        currency,
        success: false,
        error: "Failed to claim crew payout",
      })
      continue
    }

    if (!claim.data) {
      const { data: freshMember } = await supabase
        .from("booking_crew")
        .select("transfer_id")
        .eq("id", member.id)
        .maybeSingle()

      if (freshMember?.transfer_id && freshMember.transfer_id !== "pending") {
        transferResults.push({
          pilot_id: member.pilot_id,
          transfer_id: freshMember.transfer_id,
          amount: payoutPerPilotCents,
          currency,
          success: true,
        })
      } else {
        transferResults.push({
          pilot_id: member.pilot_id,
          transfer_id: "",
          amount: payoutPerPilotCents,
          currency,
          success: false,
          error: "Transfer already in progress for this crew member",
        })
      }
      continue
    }

    try {
      const transferParams: Record<string, unknown> = {
        amount: payoutPerPilotCents,
        currency,
        destination: stripeAccountId,
        metadata: {
          booking_id: booking.id,
          crew_member_id: member.id,
          booking_type: "search_rescue",
          hours_worked: hoursWorked,
          hourly_rate: hourlyRate,
          transfer_type: "booking",
        },
      }

      if (chargeId) {
        transferParams.source_transaction = chargeId
      }

      const transfer = await stripe.transfers.create(transferParams)
      const finalize = await finalizeCrewClaim(member.id, transfer.id)
      if (finalize.error || !finalize.data) {
        console.error("CRITICAL: S&R transfer created but booking_crew update failed", {
          crew_id: member.id,
          transfer_id: transfer.id,
          error: finalize.error,
        })
        transferResults.push({
          pilot_id: member.pilot_id,
          transfer_id: transfer.id,
          amount: transfer.amount,
          currency: transfer.currency,
          success: false,
          error: "Transfer created but database update failed",
          requires_reconciliation: true,
        })
        continue
      }

      if (!firstTransferId) {
        firstTransferId = transfer.id
      }

      await supabase
        .from("booking_crew")
        .update(updatePayload("payout_amount", String(payoutPerPilotDollars)))
        .eq("id", member.id)

      transferResults.push({
        pilot_id: member.pilot_id,
        transfer_id: transfer.id,
        amount: transfer.amount,
        currency: transfer.currency,
        success: true,
      })
    } catch (error: any) {
      await resetCrewClaim(member.id)
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

  if (!booking.transfer_id && firstTransferId) {
    await supabase
      .from("bookings")
      .update(updatePayload("transfer_id", firstTransferId))
      .eq("id", booking.id)
      .is("transfer_id", null)
  }

  const successfulTransfers = transferResults.filter((transfer) => transfer.success)
  const failedTransfers = transferResults.filter((transfer) => !transfer.success)
  const totalTransferred = successfulTransfers.reduce((sum, transfer) => sum + transfer.amount, 0)

  return jsonResponse({
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
  }, failedTransfers.length === crewMembers.length ? 500 : 200)
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    const auth = await requireAuthUser(req)
    if (auth.response) {
      return auth.response
    }

    const {
      booking_id,
      charge_id = null,
      currency = "usd",
      transfer_type = "booking",
    } = await req.json()

    if (!booking_id) {
      return jsonResponse({ error: "Missing required field: booking_id" }, 400)
    }

    if (transfer_type !== "booking" && transfer_type !== "tip") {
      return jsonResponse({ error: "Invalid transfer_type" }, 400)
    }

    const normalizedCurrency = String(currency).toLowerCase()
    if (normalizedCurrency !== "usd") {
      return jsonResponse({ error: "Unsupported currency" }, 400)
    }

    const booking = await fetchBooking(booking_id)
    if (!booking) {
      return jsonResponse({ error: "Booking not found" }, 404)
    }

    const authorized = await isAuthorizedForBooking(auth.user.id, booking, transfer_type)
    if (!authorized) {
      return jsonResponse({ error: "Unauthorized for this booking transfer" }, 403)
    }

    if (transfer_type === "tip") {
      return await handleTipTransfer(booking, normalizedCurrency, charge_id)
    }

    if (booking.specialization === "automotive") {
      return await handleAutomotiveTransfer(booking, normalizedCurrency, charge_id || booking.charge_id)
    }

    if (booking.specialization === "search_rescue") {
      return await handleSearchRescueTransfer(booking, normalizedCurrency, charge_id || booking.charge_id)
    }

    return await handleStandardBookingTransfer(booking, normalizedCurrency, charge_id)
  } catch (error: any) {
    console.error("Error creating transfer:", error)
    return jsonResponse({ error: error.message }, 500)
  }
})
