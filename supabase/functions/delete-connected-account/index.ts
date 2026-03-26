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
import { corsHeaders, jsonResponse, requireAuthUser, requireMatchingUserId, requireOwnedStripeAccount, serviceSupabase } from "../_shared/auth.ts"

const stripeSecretKey = Deno.env.get("STRIPE_SECRET_KEY")
if (!stripeSecretKey) {
  throw new Error("STRIPE_SECRET_KEY environment variable is not set")
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    const auth = await requireAuthUser(req)
    if (auth.response) {
      return auth.response
    }

    const { account_id, user_id } = await req.json()
    const userCheck = requireMatchingUserId(auth.user.id, user_id)
    if (userCheck.response) {
      return userCheck.response
    }

    const accountCheck = await requireOwnedStripeAccount(userCheck.userId, account_id)
    if (accountCheck.response) {
      return accountCheck.response
    }

    // Delete the Stripe account
    const stripeResponse = await fetch(`https://api.stripe.com/v1/accounts/${accountCheck.accountId}`, {
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
    const { error: updateError } = await serviceSupabase
      .from("profiles")
      .update({ stripe_account_id: null })
      .eq("id", userCheck.userId)

    if (updateError) {
      console.error("Failed to clear stripe_account_id from profile:", updateError)
      // Log error but don't fail - the Stripe account is already deleted
    }

    return jsonResponse({
        success: true,
        deleted: deleteResult.deleted,
        id: deleteResult.id,
        message: "Payment account removed successfully"
      })
  } catch (error: any) {
    console.error("Error deleting connected account:", error)
    return jsonResponse({
        error: error.message || "Failed to delete account",
        details: error.toString()
      }, 500)
  }
})
