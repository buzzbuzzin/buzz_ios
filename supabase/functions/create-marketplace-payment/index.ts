// Supabase Edge Function to create Stripe PaymentIntent for marketplace transactions
// Calculates 10% platform fee and stores marketplace metadata
// Follows same pattern as create-payment-intent

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import Stripe from "https://esm.sh/stripe@14.21.0?target=deno"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const stripeSecretKey = Deno.env.get("STRIPE_SECRET_KEY")
if (!stripeSecretKey) {
  throw new Error("STRIPE_SECRET_KEY environment variable is not set")
}

const supabaseUrl = Deno.env.get("SUPABASE_URL")!
const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!

const stripe = new Stripe(stripeSecretKey, {
  httpClient: Stripe.createFetchHttpClient(),
})

const supabase = createClient(supabaseUrl, supabaseServiceKey)

const PLATFORM_FEE_PERCENTAGE = 0.10 // 10%

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
      .select("id, buyer_id, seller_id, amount, platform_fee, seller_payout, payment_intent_id, status")
      .eq("id", transaction_id)
      .single()

    if (txError || !transaction) {
      return new Response(
        JSON.stringify({ error: "Transaction not found" }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    // Verify the authenticated user is the buyer (unconditional check)
    if (user.id !== transaction.buyer_id) {
      return new Response(
        JSON.stringify({ error: "Unauthorized: user is not the buyer for this transaction" }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    // Idempotency: if transaction already has a payment_intent_id, validate and return it
    if (transaction.payment_intent_id === "pending") {
      return new Response(
        JSON.stringify({ error: "Transaction is already being processed by another request, please retry" }),
        { status: 409, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    if (transaction.payment_intent_id) {
      const existingPI = await stripe.paymentIntents.retrieve(transaction.payment_intent_id)
      // If the PaymentIntent is in a failed/canceled state, fall through to create a new one
      if (existingPI.status !== 'canceled' && existingPI.status !== 'requires_payment_method') {
        return new Response(
          JSON.stringify({
            client_secret: existingPI.client_secret,
            payment_intent_id: existingPI.id,
            platform_fee: Math.round(Number(transaction.platform_fee) * 100),
            seller_payout: Math.round(Number(transaction.seller_payout) * 100),
          }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 }
        )
      }
      // PaymentIntent is canceled or failed — will create a new one below
    }

    // Atomic claim: prevent concurrent PaymentIntent creation via optimistic lock
    const claimFilter = transaction.payment_intent_id
      ? `payment_intent_id.eq.${transaction.payment_intent_id}`
      : "payment_intent_id.is.null"
    const { data: claimed, error: claimError } = await supabase
      .from("marketplace_transactions")
      .update({ payment_intent_id: 'pending', updated_at: new Date().toISOString() })
      .eq("id", transaction_id)
      .or(claimFilter)
      .select()

    if (claimError || !claimed || claimed.length === 0) {
      // Another request already claimed it — try to return the existing PaymentIntent
      const { data: freshTx } = await supabase
        .from("marketplace_transactions")
        .select("payment_intent_id, platform_fee, seller_payout")
        .eq("id", transaction_id)
        .single()

      if (freshTx?.payment_intent_id && freshTx.payment_intent_id !== 'pending') {
        const existingPI = await stripe.paymentIntents.retrieve(freshTx.payment_intent_id)
        return new Response(
          JSON.stringify({
            client_secret: existingPI.client_secret,
            payment_intent_id: existingPI.id,
            platform_fee: Math.round(Number(freshTx.platform_fee) * 100),
            seller_payout: Math.round(Number(freshTx.seller_payout) * 100),
          }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 }
        )
      }

      return new Response(
        JSON.stringify({ error: "Transaction is being processed by another request, please retry" }),
        { status: 409, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    // Use DB-stored amount (stored in dollars, convert to cents for Stripe)
    const amountCents = Math.round(Number(transaction.amount) * 100)
    const platformFeeCents = Math.round(amountCents * PLATFORM_FEE_PERCENTAGE)
    const sellerPayoutCents = amountCents - platformFeeCents
    const previousPaymentIntentId = transaction.payment_intent_id

    const restoreClaim = async () => {
      const { error: restoreError } = await supabase
        .from("marketplace_transactions")
        .update({
          payment_intent_id: previousPaymentIntentId,
          updated_at: new Date().toISOString(),
        })
        .eq("id", transaction_id)
        .eq("payment_intent_id", "pending")

      if (restoreError) {
        console.error("Failed to restore marketplace transaction claim:", restoreError)
      }
    }

    let paymentIntent: Stripe.PaymentIntent | null = null

    try {
      // Create or retrieve Stripe customer using verified user.id
      let customerId: string
      const existingCustomers = await stripe.customers.search({
        query: `metadata['user_id']:'${user.id}'`,
      })

      if (existingCustomers.data.length > 0) {
        customerId = existingCustomers.data[0].id
      } else {
        const newCustomer = await stripe.customers.create({
          metadata: { user_id: user.id },
        })
        customerId = newCustomer.id
      }

      // Create ephemeral key
      let ephemeralKeySecret: string | undefined
      try {
        const ephemeralKey = await stripe.ephemeralKeys.create(
          { customer: customerId },
          { apiVersion: "2024-11-20.acacia" }
        )
        ephemeralKeySecret = ephemeralKey.secret
      } catch (error) {
        console.log("Could not create ephemeral key:", error)
      }

      // Create PaymentIntent with marketplace metadata
      // Currency is hardcoded server-side to "usd" — do not accept from client
      paymentIntent = await stripe.paymentIntents.create({
        amount: amountCents,
        currency: "usd",
        customer: customerId,
        transfer_group: `marketplace_${transaction_id}`,
        metadata: {
          marketplace_transaction_id: transaction_id,
          seller_id: transaction.seller_id,
          platform_fee_cents: platformFeeCents.toString(),
          seller_payout_cents: sellerPayoutCents.toString(),
          buyer_id: user.id, // Use verified user.id, not client-supplied value
        },
        automatic_payment_methods: {
          enabled: true,
        },
      })

      // Store payment_intent_id and calculated fees on the transaction.
      // Do NOT mark status as 'paid' here — status should only change to 'paid'
      // via webhook when payment_intent.succeeded fires.
      const { error: finalizeError } = await supabase
        .from("marketplace_transactions")
        .update({
          payment_intent_id: paymentIntent.id,
          platform_fee: (platformFeeCents / 100).toFixed(2),
          seller_payout: (sellerPayoutCents / 100).toFixed(2),
          updated_at: new Date().toISOString(),
        })
        .eq("id", transaction_id)
        .eq("payment_intent_id", "pending")

      if (finalizeError) {
        console.error("Failed to finalize marketplace payment intent:", finalizeError)

        try {
          await stripe.paymentIntents.cancel(paymentIntent.id)
        } catch (cancelError) {
          console.error("Failed to cancel orphaned marketplace PaymentIntent:", cancelError)
        }

        await restoreClaim()

        return new Response(
          JSON.stringify({ error: "Failed to persist marketplace payment intent. Please retry." }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 500 }
        )
      }

      return new Response(
        JSON.stringify({
          client_secret: paymentIntent.client_secret,
          payment_intent_id: paymentIntent.id,
          customer_id: customerId,
          ephemeral_key_secret: ephemeralKeySecret,
          platform_fee: platformFeeCents,
          seller_payout: sellerPayoutCents,
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 }
      )
    } catch (error) {
      if (paymentIntent) {
        try {
          await stripe.paymentIntents.cancel(paymentIntent.id)
        } catch (cancelError) {
          console.error("Failed to cancel marketplace PaymentIntent after error:", cancelError)
        }
      }

      await restoreClaim()
      throw error
    }
  } catch (error: any) {
    console.error("Error creating marketplace payment:", error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )
  }
})
