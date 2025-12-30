// Supabase Edge Function to get referral statistics for a user
// Returns total referrals, credits earned, pending referrals, and referral history

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const supabaseUrl = Deno.env.get("SUPABASE_URL")!
const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!

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
    const { user_id } = await req.json()

    if (!user_id) {
      return new Response(
        JSON.stringify({ error: "user_id is required" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

    // Get user's referral code
    const { data: codeRecord } = await supabase
      .from("referral_codes")
      .select("code, created_at")
      .eq("user_id", user_id)
      .single()

    // Get user's available credits from profile
    const { data: profile } = await supabase
      .from("profiles")
      .select("referral_credits")
      .eq("id", user_id)
      .single()

    // Get all referrals where this user is the referrer
    const { data: referrals, error: referralsError } = await supabase
      .from("referrals")
      .select(`
        id,
        referee_id,
        status,
        credit_amount,
        credited_at,
        created_at
      `)
      .eq("referrer_id", user_id)
      .order("created_at", { ascending: false })

    if (referralsError) {
      console.error("Error fetching referrals:", referralsError)
    }

    // Get referee names for display
    const referralList = referrals || []
    const refereeIds = referralList.map((r) => r.referee_id)
    
    let refereeProfiles: Record<string, { first_name: string; last_name: string }> = {}
    if (refereeIds.length > 0) {
      const { data: profiles } = await supabase
        .from("profiles")
        .select("id, first_name, last_name")
        .in("id", refereeIds)

      if (profiles) {
        refereeProfiles = profiles.reduce((acc, p) => {
          acc[p.id] = { first_name: p.first_name, last_name: p.last_name }
          return acc
        }, {} as Record<string, { first_name: string; last_name: string }>)
      }
    }

    // Calculate statistics
    const totalReferrals = referralList.length
    const completedReferrals = referralList.filter((r) => r.status === "completed").length
    const pendingReferrals = referralList.filter((r) => r.status === "pending").length
    const totalCreditsEarned = referralList
      .filter((r) => r.status === "completed")
      .reduce((sum, r) => sum + (r.credit_amount || 0), 0)
    const availableCredits = profile?.referral_credits || 0

    // Build referral history with referee names
    const referralHistory = referralList.map((r) => {
      const referee = refereeProfiles[r.referee_id]
      return {
        id: r.id,
        referee_name: referee 
          ? `${referee.first_name || ""} ${(referee.last_name || "").charAt(0) || ""}`.trim() || "Anonymous"
          : "Anonymous",
        status: r.status,
        credit_amount: r.credit_amount,
        credited_at: r.credited_at,
        created_at: r.created_at,
      }
    })

    return new Response(
      JSON.stringify({
        referral_code: codeRecord?.code || null,
        total_referrals: totalReferrals,
        completed_referrals: completedReferrals,
        pending_referrals: pendingReferrals,
        total_credits_earned: totalCreditsEarned,
        available_credits: availableCredits,
        referral_history: referralHistory,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    )
  } catch (error) {
    console.error("Error getting referral stats:", error)
    return new Response(
      JSON.stringify({ error: error.message || "Failed to get referral stats" }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    )
  }
})

