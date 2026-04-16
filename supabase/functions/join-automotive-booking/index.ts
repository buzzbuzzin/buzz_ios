// Supabase Edge Function to handle pilot joining an automotive booking crew
// This function implements the crew system where 4 pilots can join a booking
// with rank-based fixed payouts

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

const supabaseUrl = Deno.env.get("SUPABASE_URL") || ""
const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || ""

const supabase = createClient(supabaseUrl, supabaseServiceKey)

// Rank-based payout amounts in dollars
const RANK_PAYOUTS: Record<number, number> = {
  1: 350.00,  // Sublieutenant
  2: 450.00,  // Lieutenant
  3: 550.00,  // Commander
  4: 650.00,  // Captain
}

const RANK_NAMES: Record<number, string> = {
  0: "Ensign",
  1: "Sublieutenant",
  2: "Lieutenant",
  3: "Commander",
  4: "Captain",
}

const MAX_CREW_SIZE = 4
const DEFAULT_MIN_LEAD_RANK = 2  // Default: Lieutenant or above required (can be overridden by booking)

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    const { booking_id, pilot_id } = await req.json()

    // Validate required fields
    if (!booking_id || !pilot_id) {
      return new Response(
        JSON.stringify({ error: "Missing required fields: booking_id, pilot_id" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

    // Identity verification gate. booking_crew RLS only permits service-role
    // inserts, so this function is the only entry point for crew joins —
    // mirror the bookings RLS verification requirement here. Stripe-webhook
    // is the authoritative writer of verification_status (see migration
    // 20260416_lock_verification_status_to_service_role.sql).
    const { data: govId, error: govErr } = await supabase
      .from("government_ids")
      .select("verification_status")
      .eq("user_id", pilot_id)
      .maybeSingle()

    if (govErr) {
      console.error("[join-automotive-booking] government_ids lookup error:", govErr)
      return new Response(
        JSON.stringify({ error: "Unable to verify identity status. Try again." }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    if (!govId || govId.verification_status !== "verified") {
      return new Response(
        JSON.stringify({
          error: "Identity verification required. Please complete government-ID verification in your Account settings before joining crew missions.",
          code: "identity_not_verified",
          verification_status: govId?.verification_status ?? "missing",
        }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    // Get booking details including required_minimum_rank
    const { data: booking, error: bookingError } = await supabase
      .from("bookings")
      .select("id, status, specialization, customer_id, required_minimum_rank")
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

    // Validate booking is automotive specialization
    if (booking.specialization !== "automotive") {
      return new Response(
        JSON.stringify({ error: "This function is only for automotive bookings" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

    // Validate booking is still available (not yet fully crewed)
    if (booking.status !== "available") {
      return new Response(
        JSON.stringify({ error: "Booking is no longer available for joining" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

    // Get pilot's rank from pilot_stats
    const { data: pilotStats, error: statsError } = await supabase
      .from("pilot_stats")
      .select("tier")
      .eq("pilot_id", pilot_id)
      .single()

    if (statsError || !pilotStats) {
      return new Response(
        JSON.stringify({ error: "Pilot stats not found. Please complete your profile setup." }),
        {
          status: 404,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

    const pilotRank = pilotStats.tier

    // Reject Ensigns (tier 0) - they cannot participate in automotive bookings
    if (pilotRank < 1) {
      return new Response(
        JSON.stringify({ 
          error: "Ensigns cannot participate in automotive bookings. Minimum rank required: Sublieutenant.",
          pilot_rank: RANK_NAMES[pilotRank]
        }),
        {
          status: 403,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

    // Check if pilot is already in this crew
    const { data: existingMembership } = await supabase
      .from("booking_crew")
      .select("id")
      .eq("booking_id", booking_id)
      .eq("pilot_id", pilot_id)
      .single()

    if (existingMembership) {
      return new Response(
        JSON.stringify({ error: "You have already joined this booking crew" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

    // Get current crew members
    const { data: currentCrew, error: crewError } = await supabase
      .from("booking_crew")
      .select("id, pilot_id, rank_at_acceptance, role")
      .eq("booking_id", booking_id)

    if (crewError) {
      throw new Error(`Error fetching crew: ${crewError.message}`)
    }

    const crewCount = currentCrew?.length || 0

    // Check crew capacity
    if (crewCount >= MAX_CREW_SIZE) {
      return new Response(
        JSON.stringify({ error: "Crew is already full (4/4 pilots)" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

    // Get dynamic minimum lead rank from booking (customer's choice), fallback to default
    const minLeadRank = booking.required_minimum_rank ?? DEFAULT_MIN_LEAD_RANK

    // Check if crew already has a qualified lead
    const qualifiedCrewMembers = currentCrew?.filter(m => m.rank_at_acceptance >= minLeadRank) || []
    const hasQualifiedLeadAlready = qualifiedCrewMembers.length > 0

    // RESERVE LAST SEAT FOR QUALIFIED LEAD:
    // If crew has 3 members but no qualified lead, the 4th seat is reserved
    // Only pilots with rank >= minLeadRank can take the last spot
    if (crewCount === MAX_CREW_SIZE - 1 && !hasQualifiedLeadAlready) {
      if (pilotRank < minLeadRank) {
        return new Response(
          JSON.stringify({ 
            error: `The last crew spot is reserved for ${RANK_NAMES[minLeadRank]}+ pilots to ensure the crew has a qualified lead.`,
            required_rank: RANK_NAMES[minLeadRank],
            your_rank: RANK_NAMES[pilotRank]
          }),
          {
            status: 403,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          }
        )
      }
    }

    // Calculate payout based on rank
    const payoutAmount = RANK_PAYOUTS[pilotRank] || 0
    if (payoutAmount === 0) {
      return new Response(
        JSON.stringify({ error: "Invalid pilot rank for payout calculation" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

    // Determine role - only pilots with rank >= minLeadRank can be lead
    // Lead is the highest-ranked qualified pilot in the crew
    const highestQualifiedRank = qualifiedCrewMembers.reduce((max, member) => 
      Math.max(max, member.rank_at_acceptance), 0)
    
    // Pilot can only be lead if they meet minimum lead rank AND have the highest qualified rank
    const canBeLead = pilotRank >= minLeadRank
    const isHighestQualified = canBeLead && pilotRank > highestQualifiedRank
    const role = isHighestQualified ? "lead" : "crew"

    // Insert new crew member
    const { data: newMember, error: insertError } = await supabase
      .from("booking_crew")
      .insert({
        booking_id,
        pilot_id,
        role,
        rank_at_acceptance: pilotRank,
        payout_amount: payoutAmount,
      })
      .select()
      .single()

    if (insertError) {
      throw new Error(`Error adding to crew: ${insertError.message}`)
    }

    // If this pilot is the new lead, update previous lead to crew
    if (isHighestQualified && qualifiedCrewMembers.length > 0) {
      const previousLead = currentCrew?.find(m => m.role === "lead")
      if (previousLead) {
        await supabase
          .from("booking_crew")
          .update({ role: "crew" })
          .eq("id", previousLead.id)
      }
    }

    // Check if crew is now complete and has valid composition
    const newCrewCount = crewCount + 1
    const hasQualifiedLead = pilotRank >= minLeadRank || 
      (currentCrew?.some(m => m.rank_at_acceptance >= minLeadRank) || false)

    let bookingAccepted = false

    if (newCrewCount === MAX_CREW_SIZE && hasQualifiedLead) {
      // Crew is complete with a qualified lead - accept the booking
      // Find the lead pilot (highest rank)
      const allCrewRanks = [...(currentCrew || []).map(m => ({ 
        pilot_id: m.pilot_id, 
        rank: m.rank_at_acceptance 
      })), { pilot_id, rank: pilotRank }]
      
      const leadPilot = allCrewRanks.reduce((lead, member) => 
        member.rank > lead.rank ? member : lead, allCrewRanks[0])

      // Update booking status to accepted and set lead as pilot_id
      const { error: updateError } = await supabase
        .from("bookings")
        .update({ 
          status: "accepted",
          pilot_id: leadPilot.pilot_id
        })
        .eq("id", booking_id)

      if (updateError) {
        console.error("Error updating booking status:", updateError)
      } else {
        bookingAccepted = true
        
        // TODO: Notify all crew members that the booking is now accepted
        // This would require a notification system (push notifications, email, or in-app)
        // For now, crew members will see the status change when they open the app
        console.log(`Automotive booking ${booking_id} is now accepted with full crew of ${MAX_CREW_SIZE} pilots`)
      }
    }

    // Return success response
    return new Response(
      JSON.stringify({
        success: true,
        message: `Successfully joined crew as ${role}`,
        crew_member: {
          id: newMember.id,
          role,
          rank: RANK_NAMES[pilotRank],
          payout_amount: payoutAmount,
        },
        crew_status: {
          current_count: newCrewCount,
          max_count: MAX_CREW_SIZE,
          has_qualified_lead: hasQualifiedLead,
          booking_accepted: bookingAccepted,
        }
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    )
  } catch (error: any) {
    console.error("Error joining automotive booking:", error)
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    )
  }
})

