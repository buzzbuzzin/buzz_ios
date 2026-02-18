// Supabase Edge Function to release marketplace funds to seller
// Called when buyer confirms receipt of shipped item
// Transfers seller_payout amount to seller's Stripe Connect account

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import Stripe from "https://esm.sh/stripe@14.21.0?target=deno"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const stripeSecretKey = Deno.env.get("STRIPE_SECRET_KEY")
if (!stripeSecretKey) {
  throw new Error("STRIPE_SECRET_KEY environment variable is not set")
}

const supabaseUrl = Deno.env.get("SUPABASE_URL") || ""
const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || ""

const stripe = new Stripe(stripeSecretKey, {
  httpClient: Stripe.createFetchHttpClient(),
})

const supabase = createClient(supabaseUrl, supabaseServiceKey)

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    // Verify the caller's identity via JWT
    const authHeader = req.headers.get("Authorization")
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "Missing Authorization header" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    const userClient = createClient(supabaseUrl, Deno.env.get("SUPABASE_ANON_KEY") || "", {
      global: { headers: { Authorization: authHeader } },
      auth: { autoRefreshToken: false, persistSession: false },
    })
    const { data: { user }, error: authError } = await userClient.auth.getUser()
    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: "Invalid or expired token" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    const { transaction_id } = await req.json()

    if (!transaction_id) {
      return new Response(
        JSON.stringify({ error: "Missing required field: transaction_id" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    // Fetch transaction from DB — use DB-stored values instead of client-supplied data
    const { data: transaction, error: txError } = await supabase
      .from("marketplace_transactions")
      .select("id, buyer_id, seller_id, seller_payout, payment_intent_id, transfer_id, status")
      .eq("id", transaction_id)
      .single()

    if (txError || !transaction) {
      return new Response(
        JSON.stringify({ error: "Transaction not found" }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    // Verify the authenticated user is the buyer (only buyer can release funds)
    if (user.id !== transaction.buyer_id) {
      return new Response(
        JSON.stringify({ error: "Unauthorized: only the buyer can release funds" }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    // Atomic claim: use UPDATE with WHERE as optimistic lock to prevent TOCTOU races.
    // Only claims the transaction if it's in a releasable status and hasn't been claimed yet.
    const { data: claimed, error: claimError } = await supabase
      .from("marketplace_transactions")
      .update({ transfer_id: 'pending', status: 'releasing', updated_at: new Date().toISOString() })
      .eq("id", transaction_id)
      .is("transfer_id", null)
      .in("status", ["delivered", "meetup_completed"])
      .select()

    if (claimError || !claimed || claimed.length === 0) {
      return new Response(
        JSON.stringify({ error: "Transaction already claimed or not in a releasable state" }),
        { status: 409, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    // Get seller's Stripe connected account ID using DB-stored seller_id
    const { data: seller, error: sellerError } = await supabase
      .from("profiles")
      .select("stripe_account_id")
      .eq("id", transaction.seller_id)
      .single()

    if (sellerError || !seller) {
      return new Response(
        JSON.stringify({ error: "Seller not found" }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    if (!seller.stripe_account_id) {
      return new Response(
        JSON.stringify({ error: "Seller does not have a Stripe connected account" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    // Use DB-stored seller_payout (stored in dollars, convert to cents for Stripe)
    const sellerPayoutCents = Math.round(Number(transaction.seller_payout) * 100)

    // Get charge ID from the PaymentIntent (using DB-stored payment_intent_id)
    let chargeId: string | undefined
    if (transaction.payment_intent_id) {
      try {
        const paymentIntent = await stripe.paymentIntents.retrieve(transaction.payment_intent_id)
        if (paymentIntent.latest_charge) {
          chargeId = typeof paymentIntent.latest_charge === 'string'
            ? paymentIntent.latest_charge
            : paymentIntent.latest_charge.id
        }
      } catch (error) {
        console.error("Error retrieving PaymentIntent:", error)
      }
    }

    // Create transfer to seller's connected account
    const transferParams: any = {
      amount: sellerPayoutCents,
      currency: "usd",
      destination: seller.stripe_account_id,
      metadata: {
        marketplace_transaction_id: transaction_id,
        type: "marketplace_payout",
      },
    }

    if (chargeId) {
      transferParams.source_transaction = chargeId
    }

    let transfer
    try {
      transfer = await stripe.transfers.create(transferParams)
    } catch (stripeError: any) {
      // Stripe transfer failed — reset the claim so it can be retried
      await supabase
        .from("marketplace_transactions")
        .update({ transfer_id: null, status: transaction.status, updated_at: new Date().toISOString() })
        .eq("id", transaction_id)
      console.error("Stripe transfer failed, claim reset:", stripeError)
      return new Response(
        JSON.stringify({ error: `Stripe transfer failed: ${stripeError.message}` }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    // Update transaction with transfer details — check for errors
    const { error: updateError } = await supabase
      .from("marketplace_transactions")
      .update({
        transfer_id: transfer.id,
        charge_id: chargeId || null,
        status: "completed",
        completed_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      })
      .eq("id", transaction_id)

    if (updateError) {
      // CRITICAL: Stripe transfer was created but DB update failed.
      // Requires manual reconciliation.
      console.error("CRITICAL: Stripe transfer created but DB update failed:", {
        transfer_id: transfer.id,
        transaction_id,
        error: updateError,
      })
      return new Response(
        JSON.stringify({
          error: "Payment was transferred but database update failed. Contact support.",
          transfer_id: transfer.id,
          requires_reconciliation: true,
        }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    return new Response(
      JSON.stringify({
        transfer_id: transfer.id,
        amount: transfer.amount,
        currency: transfer.currency,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 }
    )
  } catch (error: any) {
    console.error("Error releasing marketplace funds:", error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )
  }
})
