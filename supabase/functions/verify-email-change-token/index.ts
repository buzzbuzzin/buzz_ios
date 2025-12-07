// Supabase Edge Function to verify email change token
// Verifies the 6-digit token and updates user email if valid

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

interface VerifyTokenRequest {
  token: string
  new_email: string
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    // Get authorization header
    const authHeader = req.headers.get("Authorization")
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "Missing authorization header" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    // Create Supabase client with service role key for admin operations
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    const supabase = createClient(supabaseUrl, supabaseServiceKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    })

    // Verify user
    const token = authHeader.replace("Bearer ", "")
    const {
      data: { user },
      error: authError,
    } = await supabase.auth.getUser(token)

    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: "Unauthorized" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    // Parse request body
    const data: VerifyTokenRequest = await req.json()

    // Validate required fields
    if (!data.token || !data.new_email) {
      return new Response(
        JSON.stringify({ error: "Missing required fields: token, new_email" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    // Validate token format (6 digits)
    if (!/^\d{6}$/.test(data.token)) {
      return new Response(
        JSON.stringify({ error: "Invalid token format" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    // Find the token in database
    const { data: tokenData, error: tokenError } = await supabase
      .from("email_change_tokens")
      .select("*")
      .eq("user_id", user.id)
      .eq("token", data.token)
      .eq("new_email", data.new_email)
      .eq("verified", false)
      .single()

    if (tokenError || !tokenData) {
      console.log("Token not found or already verified:", tokenError)
      return new Response(
        JSON.stringify({ error: "Invalid or expired verification code" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    // Check if token has expired
    const expiresAt = new Date(tokenData.expires_at)
    const now = new Date()
    
    if (now > expiresAt) {
      return new Response(
        JSON.stringify({ error: "Verification code has expired" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    // Update the user's email in auth.users table using service role
    const { error: updateAuthError } = await supabase.auth.admin.updateUserById(
      user.id,
      { email: data.new_email }
    )

    if (updateAuthError) {
      console.error("Error updating auth email:", updateAuthError)
      return new Response(
        JSON.stringify({ error: "Failed to update email address" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    // Update the email in profiles table
    const { error: updateProfileError } = await supabase
      .from("profiles")
      .update({ email: data.new_email })
      .eq("id", user.id)

    if (updateProfileError) {
      console.error("Error updating profile email:", updateProfileError)
      // Don't fail the request if profile update fails - auth email is more important
      // The profile email can be synced later
    }

    // Mark token as verified
    const { error: markVerifiedError } = await supabase
      .from("email_change_tokens")
      .update({ verified: true })
      .eq("id", tokenData.id)

    if (markVerifiedError) {
      console.error("Error marking token as verified:", markVerifiedError)
      // Don't fail the request - the email was successfully changed
    }

    console.log(`Email successfully changed for user ${user.id} to ${data.new_email}`)

    return new Response(
      JSON.stringify({
        success: true,
        message: "Email address updated successfully",
        new_email: data.new_email,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    )
  } catch (error: any) {
    console.error("Error in verify-email-change-token:", error)
    
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    )
  }
})

