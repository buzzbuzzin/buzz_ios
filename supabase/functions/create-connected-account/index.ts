// Supabase Edge Function to create Stripe Express connected account
// This function creates an Express connected account for pilots
//
// Setup instructions:
// 1. Deploy: supabase functions deploy create-connected-account
// 2. Set Stripe secret key: supabase secrets set STRIPE_SECRET_KEY=sk_test_...
//
// Request body:
// {
//   "user_id": "uuid",
//   "email": "user@example.com",
//   "country": "US" (optional, defaults to platform country)
// }

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const stripeSecretKey = Deno.env.get("STRIPE_SECRET_KEY")
if (!stripeSecretKey) {
  throw new Error("STRIPE_SECRET_KEY environment variable is not set")
}

const supabaseUrl = Deno.env.get("SUPABASE_URL")
const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")

if (!supabaseUrl || !supabaseServiceKey) {
  throw new Error("SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY environment variables must be set")
}

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
    const body = await req.json()
    const { user_id, email, country = "US" } = body

    if (!user_id) {
      return new Response(
        JSON.stringify({ error: "user_id is required" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

    console.log("Creating connected account for user:", user_id)

    // Check if user already has a connected account
    const { data: profile, error: profileError } = await supabase
      .from("profiles")
      .select("stripe_account_id")
      .eq("id", user_id)
      .single()

    if (profileError) {
      console.error("Error fetching profile:", profileError)
      return new Response(
        JSON.stringify({ 
          error: "Failed to fetch user profile",
          details: profileError.message 
        }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

    if (profile?.stripe_account_id) {
      console.log("Account already exists:", profile.stripe_account_id)
      return new Response(
        JSON.stringify({
          account_id: profile.stripe_account_id,
          already_exists: true,
        }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

    // Get user profile to prefill information
    const { data: userProfile, error: userProfileError } = await supabase
      .from("profiles")
      .select("first_name, last_name, email")
      .eq("id", user_id)
      .single()

    if (userProfileError) {
      console.error("Error fetching user profile details:", userProfileError)
      // Continue anyway - we can still create account with provided email
    }

    const accountEmail = email || userProfile?.email
    if (!accountEmail) {
      return new Response(
        JSON.stringify({ error: "Email is required to create Stripe account" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

    console.log("Creating Stripe Express account...")
    
    // Create Express connected account using the new API format
    // Reference: https://docs.stripe.com/api/accounts/create
    // For Express accounts, we need to specify the controller object
    let account
    try {
      // Use direct HTTP call to avoid Deno compatibility issues with Stripe SDK
      const stripeResponse = await fetch("https://api.stripe.com/v1/accounts", {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${stripeSecretKey}`,
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body: new URLSearchParams({
          country: country,
          email: accountEmail,
          "controller[stripe_dashboard][type]": "express",
          "controller[fees][payer]": "application",
          "controller[losses][payments]": "application",
          "capabilities[card_payments][requested]": "true",
          "capabilities[transfers][requested]": "true",
          "business_type": "individual",
          "metadata[user_id]": user_id,
        }).toString(),
      })

      if (!stripeResponse.ok) {
        const errorData = await stripeResponse.json()
        console.error("Stripe API error response:", errorData)
        
        // Provide user-friendly error messages
        const errorMessage = errorData.error?.message || stripeResponse.statusText
        let userFriendlyMessage = errorMessage
        
        if (errorMessage.includes("signed up for Connect")) {
          userFriendlyMessage = "Stripe Connect is not enabled. Please enable Stripe Connect in your Stripe Dashboard (Settings → Connect) and try again."
        }
        
        throw new Error(`Stripe API error: ${userFriendlyMessage}`)
      }

      account = await stripeResponse.json()
      console.log("Stripe account created via direct API:", account.id)
    } catch (stripeError: any) {
      console.error("Error creating Stripe account:", stripeError)
      console.error("Error message:", stripeError.message)
      console.error("Error stack:", stripeError.stack)
      
      // Re-throw with better error message
      throw new Error(`Failed to create Stripe account: ${stripeError.message}`)
    }

    console.log("Stripe account created:", account.id)

    // Update profile with Stripe account ID
    const { error: updateError } = await supabase
      .from("profiles")
      .update({ stripe_account_id: account.id })
      .eq("id", user_id)

    if (updateError) {
      console.error("Error updating profile with stripe_account_id:", updateError)
      // Continue anyway - account was created, but log the error
      // Return success but include a warning
      return new Response(
        JSON.stringify({
          account_id: account.id,
          already_exists: false,
          warning: "Account created but failed to update profile. Please contact support.",
        }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

    console.log("Profile updated successfully")

    return new Response(
      JSON.stringify({
        account_id: account.id,
        already_exists: false,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    )
  } catch (error: any) {
    console.error("Error creating connected account:", error)
    console.error("Error stack:", error.stack)
    console.error("Error details:", JSON.stringify(error, null, 2))
    
    // Provide more detailed error information
    const errorMessage = error.message || "Failed to create connected account"
    const errorDetails = error.type ? `Stripe ${error.type}: ${errorMessage}` : errorMessage
    
    return new Response(
      JSON.stringify({ 
        error: errorDetails,
        type: error.type || "unknown_error"
      }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    )
  }
})

