// Supabase Edge Function to get booking crew information
// Returns crew members for a booking
// For customers: returns only lead pilot info
// For pilots: returns full crew details

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

const supabaseUrl = Deno.env.get("SUPABASE_URL") || ""
const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || ""

const supabase = createClient(supabaseUrl, supabaseServiceKey)

const RANK_NAMES: Record<number, string> = {
  0: "Ensign",
  1: "Sublieutenant",
  2: "Lieutenant",
  3: "Commander",
  4: "Captain",
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    const { booking_id, requester_id, requester_type } = await req.json()

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

    // Get booking to verify it exists and check specialization
    const { data: booking, error: bookingError } = await supabase
      .from("bookings")
      .select("id, specialization, customer_id, pilot_id, status, required_minimum_rank")
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

    // For non-automotive bookings, return empty crew
    if (booking.specialization !== "automotive") {
      return new Response(
        JSON.stringify({
          is_automotive: false,
          crew: [],
          crew_count: 0,
          max_crew: 1,
          lead_pilot: booking.pilot_id ? { pilot_id: booking.pilot_id } : null,
        }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 200,
        }
      )
    }

    // Get crew members with pilot profile info
    const { data: crewMembers, error: crewError } = await supabase
      .from("booking_crew")
      .select(`
        id,
        pilot_id,
        role,
        rank_at_acceptance,
        payout_amount,
        joined_at,
        transfer_id
      `)
      .eq("booking_id", booking_id)
      .order("rank_at_acceptance", { ascending: false })

    if (crewError) {
      throw new Error(`Error fetching crew: ${crewError.message}`)
    }

    // Get pilot profiles for crew members
    const pilotIds = crewMembers?.map(m => m.pilot_id) || []
    let pilotProfiles: Record<string, any> = {}

    if (pilotIds.length > 0) {
      const { data: profiles } = await supabase
        .from("profiles")
        .select("id, first_name, last_name, call_sign, profile_picture_url")
        .in("id", pilotIds)

      if (profiles) {
        pilotProfiles = profiles.reduce((acc, p) => {
          acc[p.id] = p
          return acc
        }, {} as Record<string, any>)
      }
    }

    // Build crew response with profile info
    const crewWithProfiles = crewMembers?.map(member => {
      const profile = pilotProfiles[member.pilot_id] || {}
      return {
        id: member.id,
        booking_id: booking_id, // Required by Swift model
        pilot_id: member.pilot_id,
        role: member.role,
        rank_at_acceptance: member.rank_at_acceptance, // Swift expects this key name
        rank_name: RANK_NAMES[member.rank_at_acceptance],
        payout_amount: member.payout_amount,
        joined_at: member.joined_at,
        transfer_id: member.transfer_id, // Swift expects transfer_id directly
        pilot_name: profile.first_name && profile.last_name 
          ? `${profile.first_name} ${profile.last_name}` 
          : profile.call_sign || "Unknown",
        call_sign: profile.call_sign,
        profile_picture_url: profile.profile_picture_url,
      }
    }) || []

    // Get dynamic minimum lead rank from booking (customer's choice), fallback to default (2 = Lieutenant)
    const minLeadRank = booking.required_minimum_rank ?? 2

    // Find the lead pilot - only someone with role === "lead" (must meet minimum rank)
    const leadPilot = crewWithProfiles.find(m => m.role === "lead") || null

    // Check if crew has a qualified lead (meets minimum rank requirement with lead role)
    const hasQualifiedLead = leadPilot !== null && leadPilot.rank_at_acceptance >= minLeadRank

    // Determine what to return based on requester type
    const isCustomer = requester_type === "customer" || 
      (requester_id && requester_id === booking.customer_id)
    const isPilotInCrew = requester_id && crewWithProfiles.some(m => m.pilot_id === requester_id)

    // For customers, only show lead pilot info
    if (isCustomer && !isPilotInCrew) {
      return new Response(
        JSON.stringify({
          is_automotive: true,
          crew_count: crewWithProfiles.length,
          max_crew: 4,
          status: booking.status,
          has_qualified_lead: hasQualifiedLead,
          lead_pilot: leadPilot ? {
            pilot_id: leadPilot.pilot_id,
            pilot_name: leadPilot.pilot_name,
            call_sign: leadPilot.call_sign,
            rank_name: leadPilot.rank_name,
            profile_picture_url: leadPilot.profile_picture_url,
          } : null,
          // Don't expose full crew or payout details to customers
        }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 200,
        }
      )
    }

    // Check if last seat is reserved for qualified lead
    const isLastSeatReserved = crewWithProfiles.length === 3 && !hasQualifiedLead

    // For pilots (in crew or viewing available booking), return full details
    return new Response(
      JSON.stringify({
        is_automotive: true,
        crew: crewWithProfiles,
        crew_count: crewWithProfiles.length,
        max_crew: 4,
        status: booking.status,
        has_qualified_lead: hasQualifiedLead,
        is_crew_full: crewWithProfiles.length >= 4,
        is_ready: crewWithProfiles.length >= 4 && hasQualifiedLead,
        lead_pilot: leadPilot,
        total_payout: crewWithProfiles.reduce((sum, m) => sum + Number(m.payout_amount), 0),
        min_lead_rank: minLeadRank,
        min_lead_rank_name: RANK_NAMES[minLeadRank],
        is_last_seat_reserved: isLastSeatReserved,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    )
  } catch (error: any) {
    console.error("Error getting booking crew:", error)
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    )
  }
})

