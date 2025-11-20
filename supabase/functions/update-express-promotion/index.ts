// Supabase Edge Function to update express promotion application status
// Allows admins to verify or reject applications and automatically promotes pilots

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

    // Create Supabase client
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
    const { applicationId, status, rejectionReason } = await req.json()

    if (!applicationId || !status) {
      return new Response(
        JSON.stringify({ error: "Missing required fields: applicationId, status" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    if (!["in_review", "verified", "rejected"].includes(status)) {
      return new Response(
        JSON.stringify({ error: "Invalid status. Must be: in_review, verified, or rejected" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    // Get the application
    const { data: application, error: appError } = await supabase
      .from("express_promotion_applications")
      .select("*")
      .eq("id", applicationId)
      .single()

    if (appError || !application) {
      return new Response(
        JSON.stringify({ error: "Application not found" }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    // Update application status
    const updateData: any = {
      status,
      reviewed_at: new Date().toISOString(),
      reviewed_by: user.id,
      updated_at: new Date().toISOString(),
    }

    if (status === "rejected" && rejectionReason) {
      updateData.rejection_reason = rejectionReason
    } else if (status === "verified") {
      updateData.rejection_reason = null
    }

    const { error: updateError } = await supabase
      .from("express_promotion_applications")
      .update(updateData)
      .eq("id", applicationId)

    if (updateError) {
      console.error("Error updating application:", updateError)
      return new Response(
        JSON.stringify({ error: "Failed to update application" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    // If verified, update pilot tier
    if (status === "verified") {
      // Get current pilot stats
      const { data: pilotStats, error: statsError } = await supabase
        .from("pilot_stats")
        .select("tier, total_flight_hours")
        .eq("pilot_id", application.pilot_id)
        .single()

      if (statsError) {
        console.error("Error fetching pilot stats:", statsError)
        // Continue anyway - the application is updated
      } else if (pilotStats) {
        // Only promote if current tier is lower than target tier
        if (pilotStats.tier < application.target_tier) {
          const { error: promoteError } = await supabase
            .from("pilot_stats")
            .update({
              tier: application.target_tier,
              updated_at: new Date().toISOString(),
            })
            .eq("pilot_id", application.pilot_id)

          if (promoteError) {
            console.error("Error promoting pilot:", promoteError)
            // Log but don't fail - application status is already updated
          } else {
            console.log(
              `✅ Pilot ${application.pilot_id} promoted to tier ${application.target_tier}`
            )
          }
        }
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: `Application ${status === "verified" ? "verified and pilot promoted" : "updated"}`,
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

