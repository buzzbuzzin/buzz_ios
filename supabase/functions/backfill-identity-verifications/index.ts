// One-shot backfill of Stripe Identity verification state into Supabase.
// Admin-only: requires SUPABASE_SERVICE_ROLE_KEY in Authorization header.
// Idempotent and safe to re-run; however the live stripe-webhook keeps DB
// in sync, so this is now only useful as a recovery tool.
//
// Semantics: a user is 'verified' if ANY Stripe session for them reached
// 'verified'. Otherwise, 'rejected' if at least one session is in a terminal
// failure state (requires_input / canceled). Non-terminal sessions are ignored.
//
// Usage:
//   curl -X POST \
//     -H "Authorization: Bearer <SUPABASE_SERVICE_ROLE_KEY>" \
//     -H "Content-Type: application/json" \
//     -d '{"dry_run": true}' \
//     https://mzapuczjijqjzdcujetx.functions.supabase.co/backfill-identity-verifications
//
// Deployed with verify_jwt=false so we can do our own admin check.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4"
import Stripe from "https://esm.sh/stripe@14.21.0?target=deno"

const stripeSecretKey = Deno.env.get("STRIPE_SECRET_KEY")
const supabaseUrl = Deno.env.get("SUPABASE_URL")
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")

if (!stripeSecretKey) throw new Error("STRIPE_SECRET_KEY not set")
if (!supabaseUrl || !supabaseServiceRoleKey) throw new Error("Supabase env vars not set")

const stripe = new Stripe(stripeSecretKey, {
  apiVersion: "2023-10-16",
  httpClient: Stripe.createFetchHttpClient(),
})

const supabaseAdmin = createClient(supabaseUrl, supabaseServiceRoleKey, {
  auth: { autoRefreshToken: false, persistSession: false },
})

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
}

type Decision = {
  user_id: string
  status: "verified" | "rejected"
  session_id: string
  session_created: number
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders })

  const auth = req.headers.get("authorization") || ""
  if (auth !== `Bearer ${supabaseServiceRoleKey}`) {
    return new Response(
      JSON.stringify({ error: "unauthorized" }),
      { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )
  }

  let dryRun = false
  try {
    if (req.method === "POST") {
      const body = await req.text()
      if (body) dryRun = !!JSON.parse(body).dry_run
    }
  } catch {}

  const report = {
    scanned_sessions: 0,
    unique_users: 0,
    verified_written: 0,
    rejected_written: 0,
    skipped_non_terminal: 0,
    skipped_no_user_id: 0,
    skipped_already_correct: 0,
    planned_writes: [] as Array<{ user_id: string; status: string; session_id: string }>,
    errors: [] as Array<{ session_id?: string; user_id?: string; reason: string }>,
    dry_run: dryRun,
  }

  try {
    // Collapse all terminal sessions to one decision per user.
    // Rule: verified beats rejected; within the same status, newest session_created wins.
    const decisions = new Map<string, Decision>()

    for await (const session of stripe.identity.verificationSessions.list({ limit: 100 })) {
      report.scanned_sessions += 1

      let status: "verified" | "rejected" | null = null
      if (session.status === "verified") status = "verified"
      else if (session.status === "requires_input" || session.status === "canceled") status = "rejected"
      else { report.skipped_non_terminal += 1; continue }

      const metadata = session.metadata || {}
      let userId =
        (metadata.supabase_user_id as string | undefined) ??
        (metadata.user_id as string | undefined) ??
        null

      if (!userId) {
        const { data: existing } = await supabaseAdmin
          .from("government_ids")
          .select("user_id")
          .eq("stripe_session_id", session.id)
          .maybeSingle()
        userId = existing?.user_id ?? null
      }

      if (!userId) {
        report.skipped_no_user_id += 1
        report.errors.push({ session_id: session.id, reason: "no user_id in metadata and no row match" })
        continue
      }

      const candidate: Decision = {
        user_id: userId,
        status,
        session_id: session.id,
        session_created: session.created,
      }

      const current = decisions.get(userId)
      if (!current) { decisions.set(userId, candidate); continue }
      if (current.status === "verified" && candidate.status === "rejected") continue
      if (current.status === "rejected" && candidate.status === "verified") {
        decisions.set(userId, candidate); continue
      }
      if (candidate.session_created > current.session_created) decisions.set(userId, candidate)
    }

    report.unique_users = decisions.size

    for (const [userId, d] of decisions) {
      const { data: current } = await supabaseAdmin
        .from("government_ids")
        .select("verification_status, stripe_session_id")
        .eq("user_id", userId)
        .maybeSingle()

      if (
        current &&
        current.verification_status === d.status &&
        current.stripe_session_id === d.session_id
      ) {
        report.skipped_already_correct += 1
        continue
      }

      if (dryRun) {
        report.planned_writes.push({ user_id: userId, status: d.status, session_id: d.session_id })
        if (d.status === "verified") report.verified_written += 1
        else report.rejected_written += 1
        continue
      }

      const { error } = await supabaseAdmin
        .from("government_ids")
        .upsert(
          { user_id: userId, stripe_session_id: d.session_id, verification_status: d.status },
          { onConflict: "user_id" }
        )

      if (error) {
        report.errors.push({ user_id: userId, session_id: d.session_id, reason: error.message })
        continue
      }

      if (d.status === "verified") report.verified_written += 1
      else report.rejected_written += 1
    }

    return new Response(JSON.stringify(report, null, 2), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    })
  } catch (err) {
    console.error("[backfill] Fatal error:", err)
    return new Response(
      JSON.stringify({ error: err instanceof Error ? err.message : "unknown", partial_report: report }, null, 2),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )
  }
})
