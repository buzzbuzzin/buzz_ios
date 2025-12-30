// Supabase Edge Function to apply referral credits to a booking after payment
// This function deducts credits from the user's balance and updates the booking record
// Should be called after successful payment

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
    const {
      booking_id,
      customer_id,
      credits_used,      // Credits used in dollars
      original_amount,   // Original amount in cents
      final_amount,      // Final amount in cents (what was charged)
    } = await req.json()

    // Validate required fields
    if (!booking_id || !customer_id) {
      return new Response(
        JSON.stringify({ error: "Missing required fields: booking_id, customer_id" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

    // If no credits used, just update booking with amounts
    if (!credits_used || credits_used <= 0) {
      const { error: bookingError } = await supabase
        .from("bookings")
        .update({
          original_amount: original_amount / 100, // Convert cents to dollars
          credits_applied: 0,
          final_amount: final_amount / 100,
        })
        .eq("id", booking_id)

      if (bookingError) {
        console.error("Error updating booking:", bookingError)
        return new Response(
          JSON.stringify({ error: "Failed to update booking record" }),
          {
            status: 500,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          }
        )
      }

      return new Response(
        JSON.stringify({
          success: true,
          credits_used: 0,
          new_balance: null,
        }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

    // Get user's current credit balance
    const { data: profile, error: profileError } = await supabase
      .from("profiles")
      .select("referral_credits")
      .eq("id", customer_id)
      .single()

    if (profileError || !profile) {
      return new Response(
        JSON.stringify({ error: "User profile not found" }),
        {
          status: 404,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

    const currentCredits = profile.referral_credits || 0

    // Validate sufficient credits
    if (credits_used > currentCredits) {
      return new Response(
        JSON.stringify({
          error: "Insufficient credits",
          available_credits: currentCredits,
          requested_credits: credits_used,
        }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

    // Calculate new balance
    const newBalance = currentCredits - credits_used

    // Update user's credit balance
    const { error: updateProfileError } = await supabase
      .from("profiles")
      .update({ referral_credits: newBalance })
      .eq("id", customer_id)

    if (updateProfileError) {
      console.error("Error updating profile credits:", updateProfileError)
      return new Response(
        JSON.stringify({ error: "Failed to deduct credits from balance" }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

    // Update booking with credit information
    const { error: bookingError } = await supabase
      .from("bookings")
      .update({
        original_amount: original_amount / 100, // Convert cents to dollars
        credits_applied: credits_used,
        final_amount: final_amount / 100,
      })
      .eq("id", booking_id)

    if (bookingError) {
      console.error("Error updating booking:", bookingError)
      // Try to rollback the credit deduction
      await supabase
        .from("profiles")
        .update({ referral_credits: currentCredits })
        .eq("id", customer_id)

      return new Response(
        JSON.stringify({ error: "Failed to update booking record" }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

    return new Response(
      JSON.stringify({
        success: true,
        credits_used: credits_used,
        new_balance: newBalance,
        booking_updated: true,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    )
  } catch (error) {
    console.error("Error applying booking credits:", error)
    return new Response(
      JSON.stringify({ error: error.message || "Failed to apply booking credits" }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    )
  }
})

