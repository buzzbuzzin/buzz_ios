// Supabase Edge Function to generate or retrieve a unique referral code for a user
// This function returns the user's existing code or creates a new one

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const supabaseUrl = Deno.env.get("SUPABASE_URL")!
const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!

const supabase = createClient(supabaseUrl, supabaseServiceKey)

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

// Generate a cryptographically secure 8-character alphanumeric code
function generateCode(): string {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789" // Removed confusing characters (0, O, 1, I)
  const array = new Uint8Array(8)
  crypto.getRandomValues(array)
  return Array.from(array)
    .map((byte) => chars[byte % chars.length])
    .join("")
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

    // Check if user already has a referral code
    const { data: existingCode, error: fetchError } = await supabase
      .from("referral_codes")
      .select("*")
      .eq("user_id", user_id)
      .single()

    if (existingCode && !fetchError) {
      // Return existing code
      return new Response(
        JSON.stringify({
          code: existingCode.code,
          created_at: existingCode.created_at,
          is_new: false,
        }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

    // Generate a new unique code
    let newCode: string
    let isUnique = false
    let attempts = 0
    const maxAttempts = 10

    while (!isUnique && attempts < maxAttempts) {
      newCode = generateCode()
      
      // Check if code already exists
      const { data: existing } = await supabase
        .from("referral_codes")
        .select("id")
        .eq("code", newCode)
        .single()

      if (!existing) {
        isUnique = true
      }
      attempts++
    }

    if (!isUnique) {
      return new Response(
        JSON.stringify({ error: "Failed to generate unique code. Please try again." }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

    // Insert the new code
    const { data: insertedCode, error: insertError } = await supabase
      .from("referral_codes")
      .insert({
        user_id: user_id,
        code: newCode!,
      })
      .select()
      .single()

    if (insertError) {
      console.error("Error inserting referral code:", insertError)
      return new Response(
        JSON.stringify({ error: "Failed to create referral code" }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

    return new Response(
      JSON.stringify({
        code: insertedCode.code,
        created_at: insertedCode.created_at,
        is_new: true,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    )
  } catch (error) {
    console.error("Error generating referral code:", error)
    return new Response(
      JSON.stringify({ error: error.message || "Failed to generate referral code" }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    )
  }
})

