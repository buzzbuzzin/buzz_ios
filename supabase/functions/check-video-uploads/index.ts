// Supabase Edge Function to check for pilots who haven't uploaded video
// after completing a booking and send reminder push notifications
//
// This function is designed to be called by a pg_cron job or external scheduler
// Schedule: Every hour (0 * * * *)

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

interface PilotNeedingReminder {
  booking_id: string
  pilot_id: string
  pilot_email: string
  completed_at: string
  hours_since_completion: number
}

interface PushNotificationResult {
  booking_id: string
  pilot_id: string
  success: boolean
  message: string
}

/**
 * Send push notification to a pilot
 */
async function sendPushNotification(
  supabaseUrl: string,
  serviceRoleKey: string,
  pilotId: string,
  bookingId: string,
  hoursSinceCompletion: number
): Promise<{ success: boolean; message: string }> {
  const title = "📹 Video Upload Reminder"
  const body = `Don't forget to upload your video footage from your recent booking. It's been ${Math.floor(hoursSinceCompletion)} hours since completion.`
  
  try {
    const response = await fetch(`${supabaseUrl}/functions/v1/send-push-notification`, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${serviceRoleKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        user_id: pilotId,
        title,
        body,
        data: {
          type: "video_upload_reminder",
          booking_id: bookingId,
        }
      }),
    })
    
    const result = await response.json()
    
    if (result.success || result.sent > 0) {
      return { success: true, message: `Notification sent (${result.sent} device(s))` }
    } else {
      return { 
        success: false, 
        message: result.message || result.error || "Failed to send notification"
      }
    }
  } catch (error: unknown) {
    const errorMessage = error instanceof Error ? error.message : String(error)
    return { success: false, message: errorMessage }
  }
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  const startTime = Date.now()
  console.log("Starting video upload check...")

  try {
    // Create Supabase client with service role for full access
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    const supabase = createClient(supabaseUrl, supabaseServiceKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    })

    // Get pilots who need video upload reminders
    const { data: pilotsNeedingReminder, error: queryError } = await supabase
      .rpc("get_pilots_needing_video_upload_reminder")

    if (queryError) {
      console.error("Error querying pilots:", queryError)
      return new Response(
        JSON.stringify({ 
          error: "Failed to query pilots needing reminders",
          details: queryError.message
        }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    const pilots = (pilotsNeedingReminder || []) as PilotNeedingReminder[]
    console.log(`Found ${pilots.length} pilot(s) needing video upload reminders`)

    if (pilots.length === 0) {
      return new Response(
        JSON.stringify({
          success: true,
          message: "No pilots need video upload reminders at this time",
          processed: 0,
          duration_ms: Date.now() - startTime
        }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    // Process each pilot
    const results: PushNotificationResult[] = []
    let successCount = 0
    let failCount = 0

    for (const pilot of pilots) {
      console.log(`Processing pilot ${pilot.pilot_id} for booking ${pilot.booking_id} (${Math.floor(pilot.hours_since_completion)}h since completion)`)
      
      // Send push notification
      const pushResult = await sendPushNotification(
        supabaseUrl,
        supabaseServiceKey,
        pilot.pilot_id,
        pilot.booking_id,
        pilot.hours_since_completion
      )
      
      // Record the reminder regardless of push success
      // This prevents sending duplicate reminders
      const { error: recordError } = await supabase
        .rpc("record_video_upload_reminder", {
          p_booking_id: pilot.booking_id,
          p_pilot_id: pilot.pilot_id,
          p_reminder_type: "24h"
        })
      
      if (recordError) {
        console.error(`Failed to record reminder for booking ${pilot.booking_id}:`, recordError)
      }
      
      results.push({
        booking_id: pilot.booking_id,
        pilot_id: pilot.pilot_id,
        success: pushResult.success,
        message: pushResult.message
      })
      
      if (pushResult.success) {
        successCount++
        console.log(`✓ Reminder sent to pilot ${pilot.pilot_id}`)
      } else {
        failCount++
        console.log(`✗ Failed to send reminder to pilot ${pilot.pilot_id}: ${pushResult.message}`)
      }
      
      // Small delay between notifications to avoid rate limiting
      if (pilots.indexOf(pilot) < pilots.length - 1) {
        await new Promise(resolve => setTimeout(resolve, 100))
      }
    }

    const duration = Date.now() - startTime
    console.log(`Video upload check completed in ${duration}ms: ${successCount} sent, ${failCount} failed`)

    return new Response(
      JSON.stringify({
        success: true,
        message: `Processed ${pilots.length} pilot(s)`,
        processed: pilots.length,
        notifications_sent: successCount,
        notifications_failed: failCount,
        duration_ms: duration,
        results
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )
  } catch (error: unknown) {
    const errorMessage = error instanceof Error ? error.message : String(error)
    console.error("Error in check-video-uploads:", errorMessage)
    
    return new Response(
      JSON.stringify({ 
        error: errorMessage,
        duration_ms: Date.now() - startTime
      }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )
  }
})

