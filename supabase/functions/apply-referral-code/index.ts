// Supabase Edge Function to apply a referral code when a new user signs up
// This function links the new user (referee) to the referrer

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const supabaseUrl = Deno.env.get("SUPABASE_URL")!
const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!

const supabase = createClient(supabaseUrl, supabaseServiceKey)

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

const REFERRAL_CREDIT_AMOUNT = 25.0

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    const { referee_id, referral_code } = await req.json()

    if (!referee_id || !referral_code) {
      return new Response(
        JSON.stringify({ error: "referee_id and referral_code are required" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

    // Normalize the referral code (uppercase, trim whitespace)
    const normalizedCode = referral_code.toUpperCase().trim()

    // Look up the referral code to find the referrer
    const { data: codeRecord, error: codeError } = await supabase
      .from("referral_codes")
      .select("user_id, code")
      .eq("code", normalizedCode)
      .single()

    if (codeError || !codeRecord) {
      return new Response(
        JSON.stringify({ error: "Invalid referral code" }),
        {
          status: 404,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

    const referrerId = codeRecord.user_id

    // Check if the referrer is trying to refer themselves
    if (referrerId === referee_id) {
      return new Response(
        JSON.stringify({ error: "You cannot use your own referral code" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

    // Check if this referee has already been referred
    const { data: existingReferral } = await supabase
      .from("referrals")
      .select("id")
      .eq("referee_id", referee_id)
      .single()

    if (existingReferral) {
      return new Response(
        JSON.stringify({ error: "This account has already been referred" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

    // Create the referral record (status: pending until government ID is verified)
    const { data: referral, error: insertError } = await supabase
      .from("referrals")
      .insert({
        referrer_id: referrerId,
        referee_id: referee_id,
        referral_code: normalizedCode,
        status: "pending",
        credit_amount: REFERRAL_CREDIT_AMOUNT,
      })
      .select()
      .single()

    if (insertError) {
      console.error("Error creating referral:", insertError)
      return new Response(
        JSON.stringify({ error: "Failed to apply referral code" }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

    // Update the referee's profile with referred_by
    await supabase
      .from("profiles")
      .update({ referred_by: referrerId })
      .eq("id", referee_id)

    return new Response(
      JSON.stringify({
        success: true,
        referral_id: referral.id,
        referrer_id: referrerId,
        message: "Referral code applied successfully. Credit will be awarded after ID verification.",
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    )
  } catch (error) {
    console.error("Error applying referral code:", error)
    return new Response(
      JSON.stringify({ error: error.message || "Failed to apply referral code" }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    )
  }
})

