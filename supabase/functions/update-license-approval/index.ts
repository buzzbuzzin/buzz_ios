// Supabase Edge Function to update license approval status
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

    // Parse request body
    const { licenseId, status, reviewerNotes } = await req.json()

    if (!licenseId || !status) {
      return new Response(
        JSON.stringify({ error: "Missing required fields: licenseId, status" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    if (!["approved", "rejected"].includes(status)) {
      return new Response(
        JSON.stringify({ error: "Invalid status. Must be: approved or rejected" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    // Get the license record
    const { data: license, error: licenseError } = await supabase
      .from("pilot_licenses")
      .select("*")
      .eq("id", licenseId)
      .single()

    if (licenseError || !license) {
      return new Response(
        JSON.stringify({ error: "License not found" }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    // Fix #3: Prevent overwriting already-final decisions
    if (license.approval_status && license.approval_status !== "pending") {
      return new Response(
        JSON.stringify({ error: "License has already been reviewed" }),
        { status: 409, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    // Update license approval status
    const updateData: Record<string, unknown> = {
      approval_status: status,
      reviewed_at: new Date().toISOString(),
      reviewed_by: user.id,
    }

    // Fix #4: Always set reviewer_notes explicitly for both statuses
    if (status === "rejected") {
      updateData.reviewer_notes = reviewerNotes || null
    } else if (status === "approved") {
      updateData.reviewer_notes = null
    }

    const { error: updateError } = await supabase
      .from("pilot_licenses")
      .update(updateData)
      .eq("id", licenseId)

    if (updateError) {
      console.error("Error updating license:", updateError)
      return new Response(
        JSON.stringify({ error: "Failed to update license" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    // Send push notification to pilot
    const licenseType = license.license_type || "License"
    let notifTitle: string
    let notifBody: string
    let notifData: Record<string, string>

    if (status === "approved") {
      notifTitle = "License Approved"
      notifBody = `Your ${licenseType} has been approved!`
      notifData = {
        type: "license_approved",
        license_id: licenseId,
      }
    } else {
      notifTitle = "License Needs Attention"
      notifBody = reviewerNotes
        ? `Your ${licenseType} needs attention: ${reviewerNotes}`
        : `Your ${licenseType} needs attention. Please check and re-upload.`
      notifData = {
        type: "license_rejected",
        license_id: licenseId,
      }
    }

    // Send push notification via the existing send-push-notification function
    try {
      await supabase.functions.invoke("send-push-notification", {
        body: {
          user_id: license.pilot_id,
          title: notifTitle,
          body: notifBody,
          data: notifData,
        },
      })
    } catch (pushError) {
      // Log but don't fail - the approval status is already updated
      console.error("Error sending push notification:", pushError)
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
