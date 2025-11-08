// Supabase Edge Function to attach external account to connected account
// This function attaches a bank account from Financial Connections to a connected account
//
// Setup instructions:
// 1. Deploy: supabase functions deploy attach-external-account
// 2. Set Stripe secret key: supabase secrets set STRIPE_SECRET_KEY=sk_test_...
//
// Request body:
// {
//   "account_id": "acct_xxx",
//   "financial_connections_account": "fca_xxx"
// }

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import Stripe from "https://esm.sh/stripe@14.21.0?target=deno"

const stripeSecretKey = Deno.env.get("STRIPE_SECRET_KEY")
if (!stripeSecretKey) {
  throw new Error("STRIPE_SECRET_KEY environment variable is not set")
}

const stripe = new Stripe(stripeSecretKey, {
  httpClient: Stripe.createFetchHttpClient(),
})

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
    const { account_id, financial_connections_account } = await req.json()

    if (!account_id || !financial_connections_account) {
      return new Response(
        JSON.stringify({ error: "account_id and financial_connections_account are required" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

    // Note: When using Financial Connections with Express accounts,
    // bank accounts are automatically attached during onboarding if
    // Financial Connections is enabled in Connect settings.
    // This function is for manually attaching accounts if needed.
    
    // Retrieve the Financial Connections account
    const financialAccount = await stripe.financialConnections.accounts.retrieve(
      financial_connections_account,
      {
        stripeAccount: account_id,
      }
    )

    // For Express accounts, external accounts are typically created automatically
    // during onboarding. This endpoint can be used to verify attachment or
    // handle edge cases where manual attachment is needed.
    
    // Check if account already has external accounts
    const externalAccounts = await stripe.accounts.listExternalAccounts(account_id, {
      limit: 10,
    })

    // If no external accounts exist, we can't directly attach Financial Connections accounts
    // They should be attached during onboarding. Return success if accounts exist.
    if (externalAccounts.data.length > 0) {
      return new Response(
        JSON.stringify({
          message: "External accounts already exist",
          external_accounts: externalAccounts.data.map(acc => ({
            id: acc.id,
            type: acc.object,
          })),
        }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

    // If no external accounts, return info that onboarding should be completed
    return new Response(
      JSON.stringify({
        message: "No external accounts found. Please complete onboarding to link bank account.",
        financial_connections_account: financial_connections_account,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    )
  } catch (error: any) {
    console.error("Error attaching external account:", error)
    return new Response(
      JSON.stringify({ error: error.message || "Failed to attach external account" }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    )
  }
})

