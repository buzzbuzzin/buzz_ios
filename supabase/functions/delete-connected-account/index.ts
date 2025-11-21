// Supabase Edge Function to delete Stripe connected account
// This function deletes a Stripe Express connected account
//
// Setup instructions:
// 1. Deploy: supabase functions deploy delete-connected-account
// 2. Set Stripe secret key: supabase secrets set STRIPE_SECRET_KEY=sk_test_...
//
// Request body:
// {
//   "account_id": "acct_xxx",
//   "user_id": "uuid"
// }

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3"

const stripeSecretKey = Deno.env.get("STRIPE_SECRET_KEY")
if (!stripeSecretKey) {
  throw new Error("STRIPE_SECRET_KEY environment variable is not set")
}

const supabaseUrl = Deno.env.get("SUPABASE_URL")!
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!

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
    const { account_id, user_id } = await req.json()

    if (!account_id) {
      return new Response(
        JSON.stringify({ error: "account_id is required" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

    if (!user_id) {
      return new Response(
        JSON.stringify({ error: "user_id is required" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

    // Verify the user owns this account
    const supabase = createClient(supabaseUrl, supabaseServiceRoleKey)
    const { data: profile, error: profileError } = await supabase
      .from("profiles")
      .select("stripe_account_id")
      .eq("id", user_id)
      .single()

    if (profileError) {
      throw new Error(`Failed to verify account ownership: ${profileError.message}`)
    }

    if (profile.stripe_account_id !== account_id) {
      return new Response(
        JSON.stringify({ error: "Account does not belong to this user" }),
        {
          status: 403,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

    // Delete the Stripe account
    const stripeResponse = await fetch(`https://api.stripe.com/v1/accounts/${account_id}`, {
      method: "DELETE",
      headers: {
        "Authorization": `Bearer ${stripeSecretKey}`,
      },
    })

    if (!stripeResponse.ok) {
      const errorData = await stripeResponse.json()
      throw new Error(errorData.error?.message || "Failed to delete account")
    }

    const deleteResult = await stripeResponse.json()

    // Remove stripe_account_id from user's profile
    const { error: updateError } = await supabase
      .from("profiles")
      .update({ stripe_account_id: null })
      .eq("id", user_id)

    if (updateError) {
      console.error("Failed to clear stripe_account_id from profile:", updateError)
      // Log error but don't fail - the Stripe account is already deleted
    }

    return new Response(
      JSON.stringify({
        success: true,
        deleted: deleteResult.deleted,
        id: deleteResult.id,
        message: "Payment account removed successfully"
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    )
  } catch (error: any) {
    console.error("Error deleting connected account:", error)
    return new Response(
      JSON.stringify({ 
        error: error.message || "Failed to delete account",
        details: error.toString()
      }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    )
  }
})

