// Supabase Edge Function to handle Stripe webhook events.
// Handles both course-subscription lifecycle events AND Stripe Identity
// verification lifecycle events. This function is the SOLE authoritative writer
// of public.government_ids.verification_status (service-role key bypasses RLS
// and the status-lock trigger added in migration
// 20260416_lock_verification_status_to_service_role.sql).
//
// Deploy: supabase functions deploy stripe-webhook --no-verify-jwt
// Required secrets:
// - STRIPE_SECRET_KEY
// - STRIPE_WEBHOOK_SECRET
// - SUPABASE_URL
// - SUPABASE_SERVICE_ROLE_KEY
//
// Register webhook URL in Stripe Dashboard:
// https://mzapuczjijqjzdcujetx.functions.supabase.co/stripe-webhook
// Events:
//   checkout.session.completed, customer.subscription.updated,
//   customer.subscription.deleted, invoice.payment_failed,
//   identity.verification_session.verified,
//   identity.verification_session.requires_input,
//   identity.verification_session.canceled

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4"
import Stripe from "https://esm.sh/stripe@14.21.0"

const stripeSecretKey = Deno.env.get("STRIPE_SECRET_KEY")
const webhookSecret = Deno.env.get("STRIPE_WEBHOOK_SECRET")
const supabaseUrl = Deno.env.get("SUPABASE_URL")
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")

if (!stripeSecretKey || !webhookSecret) {
  throw new Error("STRIPE_SECRET_KEY and STRIPE_WEBHOOK_SECRET must be set")
}

if (!supabaseUrl || !supabaseServiceRoleKey) {
  throw new Error("Supabase environment variables are not set")
}

const stripe = new Stripe(stripeSecretKey, {
  httpClient: Stripe.createFetchHttpClient(),
})

const supabaseAdmin = createClient(supabaseUrl, supabaseServiceRoleKey, {
  auth: { autoRefreshToken: false, persistSession: false },
})

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, stripe-signature",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    const body = await req.text()
    const sig = req.headers.get("stripe-signature")

    if (!sig) {
      console.error("Missing stripe-signature header")
      return new Response(
        JSON.stringify({ error: "Missing stripe-signature header" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    let event: Stripe.Event
    try {
      // constructEventAsync is required on Deno because the synchronous variant
      // depends on Node-style crypto that isn't available at edge runtime.
      event = await stripe.webhooks.constructEventAsync(body, sig, webhookSecret!)
    } catch (err: any) {
      console.error("Webhook signature verification failed:", err.message)
      return new Response(
        JSON.stringify({ error: `Webhook Error: ${err.message}` }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    console.log(`[stripe-webhook] Received event: ${event.type} (${event.id})`)

    switch (event.type) {
      // ----- Course subscriptions -------------------------------------------
      case "checkout.session.completed":
        await handleCheckoutSessionCompleted(event.data.object as Stripe.Checkout.Session)
        break

      case "customer.subscription.updated":
        await handleSubscriptionUpdated(event.data.object as Stripe.Subscription)
        break

      case "customer.subscription.deleted":
        await handleSubscriptionDeleted(event.data.object as Stripe.Subscription)
        break

      case "invoice.payment_failed":
        await handleInvoicePaymentFailed(event.data.object as Stripe.Invoice)
        break

      // ----- Identity verification ------------------------------------------
      case "identity.verification_session.verified":
        await handleIdentityVerificationSession(
          event.data.object as Stripe.Identity.VerificationSession,
          "verified"
        )
        break

      case "identity.verification_session.requires_input":
      case "identity.verification_session.canceled":
        await handleIdentityVerificationSession(
          event.data.object as Stripe.Identity.VerificationSession,
          "rejected"
        )
        break

      case "identity.verification_session.created":
      case "identity.verification_session.processing":
        // Intermediate states — the row is already 'pending' from
        // create-verification-session. Nothing to do.
        break

      default:
        console.log(`Unhandled event type: ${event.type}`)
    }

    return new Response(
      JSON.stringify({ received: true }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )
  } catch (error: any) {
    console.error("Error processing webhook:", error)
    return new Response(
      JSON.stringify({ error: error.message || "Internal server error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )
  }
})

// =============================================================================
// Identity verification handler
// =============================================================================

/**
 * Writes verification_status to government_ids for the user who owns the
 * VerificationSession. Authoritative: this is the only code path allowed to
 * transition verification_status off 'pending' (see migration
 * 20260416_lock_verification_status_to_service_role.sql).
 */
async function handleIdentityVerificationSession(
  session: Stripe.Identity.VerificationSession,
  status: "verified" | "rejected"
) {
  // Support both the current key (user_id) and a forward-compatible key
  // (supabase_user_id) to make the metadata contract explicit.
  const metadata = session.metadata || {}
  const userId =
    (metadata.supabase_user_id as string | undefined) ??
    (metadata.user_id as string | undefined) ??
    null

  if (!userId) {
    // Fall back to looking up the row by stripe_session_id (covers legacy
    // sessions created without metadata).
    console.warn(
      `[identity-webhook] Session ${session.id} has no user metadata — falling back to stripe_session_id lookup`
    )

    const { data: existing, error: lookupErr } = await supabaseAdmin
      .from("government_ids")
      .select("user_id")
      .eq("stripe_session_id", session.id)
      .maybeSingle()

    if (lookupErr || !existing) {
      console.error(
        `[identity-webhook] No government_ids row matches session ${session.id}:`,
        lookupErr
      )
      return
    }

    await writeVerificationStatus(existing.user_id, session.id, status)
    return
  }

  await writeVerificationStatus(userId, session.id, status)
}

async function writeVerificationStatus(
  userId: string,
  sessionId: string,
  status: "verified" | "rejected"
) {
  // Upsert on user_id (UNIQUE). Both:
  //   - creates the row if it didn't exist yet (edge-case: webhook fires before
  //     create-verification-session's upsert round-trips), and
  //   - updates the status + session_id when the row already exists.
  const { error } = await supabaseAdmin
    .from("government_ids")
    .upsert(
      {
        user_id: userId,
        stripe_session_id: sessionId,
        verification_status: status,
      },
      { onConflict: "user_id" }
    )

  if (error) {
    console.error(
      `[identity-webhook] Error upserting verification status for user ${userId}:`,
      error
    )
    return
  }

  console.log(
    `[identity-webhook] user=${userId} session=${sessionId} status=${status}`
  )
}

// =============================================================================
// Subscription lifecycle (unchanged)
// =============================================================================

async function handleCheckoutSessionCompleted(session: Stripe.Checkout.Session) {
  const userId = session.metadata?.supabase_user_id
  const courseId = session.metadata?.course_id
  const subscriptionId = session.subscription as string | null
  const customerId = session.customer as string | null

  if (!userId || !courseId || !subscriptionId) {
    console.error("[stripe-webhook] Missing metadata in checkout session:", {
      userId,
      courseId,
      subscriptionId,
    })
    return
  }

  const subscription = await stripe.subscriptions.retrieve(subscriptionId)

  const priceId = subscription.items.data[0]?.price?.id || null
  const periodStart = new Date(subscription.current_period_start * 1000).toISOString()
  const periodEnd = new Date(subscription.current_period_end * 1000).toISOString()

  const { error } = await supabaseAdmin
    .from("course_subscriptions")
    .upsert(
      {
        pilot_id: userId,
        course_id: courseId,
        stripe_subscription_id: subscriptionId,
        stripe_price_id: priceId,
        stripe_customer_id: customerId,
        source: "stripe",
        status: subscription.status,
        current_period_start: periodStart,
        current_period_end: periodEnd,
        updated_at: new Date().toISOString(),
      },
      { onConflict: "pilot_id,course_id,source" }
    )

  if (error) {
    console.error("[stripe-webhook] Error upserting subscription:", error)
    return
  }

  console.log("[stripe-webhook] Subscription created/updated:", {
    user_id: userId,
    course_id: courseId,
    subscription_id: subscriptionId,
    status: subscription.status,
    period_end: periodEnd,
  })
}

async function handleSubscriptionUpdated(subscription: Stripe.Subscription) {
  const userId = subscription.metadata?.supabase_user_id
  const courseId = subscription.metadata?.course_id

  if (!userId || !courseId) {
    console.error("[stripe-webhook] Missing metadata in subscription:", subscription.id)
    return
  }

  const periodStart = new Date(subscription.current_period_start * 1000).toISOString()
  const periodEnd = new Date(subscription.current_period_end * 1000).toISOString()
  const priceId = subscription.items.data[0]?.price?.id || null

  const { error } = await supabaseAdmin
    .from("course_subscriptions")
    .update({
      status: subscription.status,
      stripe_price_id: priceId,
      current_period_start: periodStart,
      current_period_end: periodEnd,
      updated_at: new Date().toISOString(),
    })
    .eq("stripe_subscription_id", subscription.id)

  if (error) {
    console.error("[stripe-webhook] Error updating subscription:", error)
    return
  }

  console.log("[stripe-webhook] Subscription updated:", {
    subscription_id: subscription.id,
    status: subscription.status,
    period_end: periodEnd,
  })
}

async function handleSubscriptionDeleted(subscription: Stripe.Subscription) {
  const { error } = await supabaseAdmin
    .from("course_subscriptions")
    .update({
      status: "canceled",
      updated_at: new Date().toISOString(),
    })
    .eq("stripe_subscription_id", subscription.id)

  if (error) {
    console.error("[stripe-webhook] Error canceling subscription:", error)
    return
  }

  console.log("[stripe-webhook] Subscription canceled:", subscription.id)
}

async function handleInvoicePaymentFailed(invoice: Stripe.Invoice) {
  const subscriptionId = invoice.subscription as string | null
  if (!subscriptionId) return

  const { error } = await supabaseAdmin
    .from("course_subscriptions")
    .update({
      status: "past_due",
      updated_at: new Date().toISOString(),
    })
    .eq("stripe_subscription_id", subscriptionId)

  if (error) {
    console.error("[stripe-webhook] Error marking subscription past_due:", error)
    return
  }

  console.log("[stripe-webhook] Subscription marked past_due:", subscriptionId)
}
