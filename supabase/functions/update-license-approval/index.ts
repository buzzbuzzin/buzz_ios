// Supabase Edge Function to update license approval status (v3)
// Uses dedicated license_approval_requests table
// Allows admins to approve or reject Flight Reviewer and ROC-A Examiner license uploads

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

serve(async (req) => {
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

    // Create Supabase client with service role
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    const supabase = createClient(supabaseUrl, supabaseKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    })

    // Verify user is admin
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

    // Check if user is admin
    const { data: profile, error: profileError } = await supabase
      .from("profiles")
      .select("user_type")
      .eq("id", user.id)
      .single()

    if (profileError || profile?.user_type !== "admin") {
      return new Response(
        JSON.stringify({ error: "Forbidden: Admin access required" }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    // Parse request body — now uses requestId instead of licenseId
    const { requestId, status, reviewerNotes } = await req.json()

    if (!requestId || !status) {
      return new Response(
        JSON.stringify({ error: "Missing required fields: requestId, status" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    if (!["pre_approved", "approved", "rejected"].includes(status)) {
      return new Response(
        JSON.stringify({ error: "Invalid status. Must be: pre_approved, approved, or rejected" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    // Get the approval request record
    const { data: approvalRequest, error: requestError } = await supabase
      .from("license_approval_requests")
      .select("*")
      .eq("id", requestId)
      .single()

    if (requestError || !approvalRequest) {
      return new Response(
        JSON.stringify({ error: "Approval request not found" }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    // Validate status transitions:
    //   pending → pre_approved or rejected
    //   pre_approved → approved or rejected
    const allowedTransitions: Record<string, string[]> = {
      pending: ["pre_approved", "rejected"],
      pre_approved: ["approved", "rejected"],
    }
    const allowed = allowedTransitions[approvalRequest.status]
    if (!allowed || !allowed.includes(status)) {
      return new Response(
        JSON.stringify({ error: `Cannot transition from '${approvalRequest.status}' to '${status}'` }),
        { status: 409, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    // Update approval request status
    const updateData: Record<string, unknown> = {
      status: status,
      reviewed_at: new Date().toISOString(),
      reviewed_by: user.id,
      updated_at: new Date().toISOString(),
    }

    // Always set reviewer_notes explicitly
    if (status === "rejected") {
      updateData.reviewer_notes = reviewerNotes || null
    } else if (status === "approved" || status === "pre_approved") {
      updateData.reviewer_notes = null
    }

    const { error: updateError } = await supabase
      .from("license_approval_requests")
      .update(updateData)
      .eq("id", requestId)

    if (updateError) {
      console.error("Error updating approval request:", updateError)
      return new Response(
        JSON.stringify({ error: "Failed to update approval request" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    // Update pilot_special_roles based on license type (only for approved, not pre_approved)
    if (status === "approved") {
      const roleField = approvalRequest.license_type?.includes("Flight Reviewer")
        ? "flight_reviewer"
        : approvalRequest.license_type?.includes("ROC-A Examiner")
        ? "roc_a_examiner"
        : null

      if (roleField) {
        const { error: roleError } = await supabase
          .from("pilot_special_roles")
          .upsert(
            { pilot_id: approvalRequest.pilot_id, [roleField]: true },
            { onConflict: "pilot_id" }
          )

        if (roleError) {
          console.error("Error updating pilot_special_roles:", roleError)
          // Don't fail the request — the approval status is already updated
        }
      }
    } else if (status === "rejected" && approvalRequest.status === "pre_approved") {
      // Only revoke role when rejecting from pre_approved — not from pending,
      // because the pilot may have a legitimate role from a prior approved request
      const roleField = approvalRequest.license_type?.includes("Flight Reviewer")
        ? "flight_reviewer"
        : approvalRequest.license_type?.includes("ROC-A Examiner")
        ? "roc_a_examiner"
        : null

      if (roleField) {
        const { error: roleError } = await supabase
          .from("pilot_special_roles")
          .upsert(
            { pilot_id: approvalRequest.pilot_id, [roleField]: false },
            { onConflict: "pilot_id" }
          )

        if (roleError) {
          console.error("Error updating pilot_special_roles:", roleError)
        }
      }
    }

    // Send push notification to pilot for all status transitions
    {
      const licenseType = approvalRequest.license_type || "License"
      const licenseId = approvalRequest.license_id
      let notifTitle: string
      let notifBody: string
      let notifData: Record<string, string>

      if (status === "approved") {
        notifTitle = "License Approved"
        notifBody = `Your ${licenseType} has been approved!`
        notifData = {
          type: "license_approved",
          ...(licenseId ? { license_id: licenseId } : {}),
        }
      } else if (status === "pre_approved") {
        notifTitle = "License Under Review"
        notifBody = `Your ${licenseType} has passed initial review and is pending final approval.`
        notifData = {
          type: "license_pre_approved",
          ...(licenseId ? { license_id: licenseId } : {}),
        }
      } else if (status === "rejected") {
        notifTitle = "License Needs Attention"
        notifBody = reviewerNotes
          ? `Your ${licenseType} needs attention: ${reviewerNotes}`
          : `Your ${licenseType} needs attention. Please check and re-upload.`
        notifData = {
          type: "license_rejected",
          ...(licenseId ? { license_id: licenseId } : {}),
        }
      } else {
        console.error(`Unhandled status in notification block: ${status}`)
        notifTitle = ""
        notifBody = ""
        notifData = { type: status }
      }

      // Insert in-app notification record
      if (notifTitle) {
        const { error: notifInsertError } = await supabase
          .from("license_notifications")
          .insert({
            recipient_id: approvalRequest.pilot_id,
            type: status,
            license_id: licenseId || null,
            title: notifTitle,
            body: notifBody,
          })

        if (notifInsertError) {
          console.error("Error inserting license notification:", notifInsertError)
        }
      }

      // Send push notification via the existing send-push-notification function
      try {
        await supabase.functions.invoke("send-push-notification", {
          body: {
            user_id: approvalRequest.pilot_id,
            title: notifTitle,
            body: notifBody,
            data: notifData,
          },
        })
      } catch (pushError) {
        // Log but don't fail - the approval status is already updated
        console.error("Error sending push notification:", pushError)
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: `License ${status}`,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )
  } catch (error) {
    console.error("Error:", error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )
  }
})
