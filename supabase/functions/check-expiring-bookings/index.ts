// Supabase Edge Function to check for expiring and expired bookings
// Sends notifications for bookings expiring within 24 hours
// and updates expired bookings to 'expired' status
//
// This function is designed to be called by a pg_cron job or external scheduler
// Schedule: Every hour (0 * * * *)

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

/**
 * Send push notification to a user via the send-push-notification edge function
 */
async function sendPushNotification(
  supabaseUrl: string,
  serviceRoleKey: string,
  userId: string,
  title: string,
  body: string,
  data: Record<string, string>
): Promise<{ success: boolean; message: string }> {
  try {
    const response = await fetch(`${supabaseUrl}/functions/v1/send-push-notification`, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${serviceRoleKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        user_id: userId,
        title,
        body,
        data,
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
  console.log("Starting expiring bookings check...")

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

    const now = new Date().toISOString()
    const in24Hours = new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString()

    let notifiedCount = 0
    let expiredCount = 0

    // 1. Find bookings expiring within 24 hours that haven't been notified
    const { data: expiringBookings, error: expiringError } = await supabase
      .from("bookings")
      .select("id, customer_id, location_name, expires_at")
      .eq("status", "available")
      .eq("expiration_notified", false)
      .not("expires_at", "is", null)
      .gt("expires_at", now)
      .lte("expires_at", in24Hours)

    if (expiringError) {
      console.error("Error querying expiring bookings:", expiringError)
    } else {
      const bookings = expiringBookings || []
      console.log(`Found ${bookings.length} booking(s) expiring within 24 hours`)

      for (const booking of bookings) {
        // Send notification to customer
        const pushResult = await sendPushNotification(
          supabaseUrl,
          supabaseServiceKey,
          booking.customer_id,
          "Booking Expiring Soon",
          `Your booking for ${booking.location_name} is expiring soon. Update the date to keep it active.`,
          {
            type: "booking_expiring",
            booking_id: booking.id,
          }
        )

        if (pushResult.success) {
          console.log(`Notified customer for booking ${booking.id}`)
        } else {
          console.log(`Failed to notify for booking ${booking.id}: ${pushResult.message}`)
        }

        // Mark as notified regardless of push success to prevent duplicates
        const { error: updateError } = await supabase
          .from("bookings")
          .update({ expiration_notified: true })
          .eq("id", booking.id)

        if (updateError) {
          console.error(`Failed to mark booking ${booking.id} as notified:`, updateError)
        } else {
          notifiedCount++
        }

        // Small delay between notifications to avoid rate limiting
        if (bookings.indexOf(booking) < bookings.length - 1) {
          await new Promise(resolve => setTimeout(resolve, 100))
        }
      }
    }

    // 2. Find and expire bookings past their expires_at date
    const { data: expiredBookings, error: expiredError } = await supabase
      .from("bookings")
      .select("id, customer_id, location_name")
      .eq("status", "available")
      .not("expires_at", "is", null)
      .lte("expires_at", now)

    if (expiredError) {
      console.error("Error querying expired bookings:", expiredError)
    } else {
      const bookings = expiredBookings || []
      console.log(`Found ${bookings.length} booking(s) to expire`)

      for (const booking of bookings) {
        const { error: updateError } = await supabase
          .from("bookings")
          .update({ status: "expired" })
          .eq("id", booking.id)

        if (updateError) {
          console.error(`Failed to expire booking ${booking.id}:`, updateError)
        } else {
          expiredCount++
          console.log(`Expired booking ${booking.id}`)
        }
      }
    }

    const duration = Date.now() - startTime
    console.log(`Expiring bookings check completed in ${duration}ms: ${notifiedCount} notified, ${expiredCount} expired`)

    return new Response(
      JSON.stringify({
        success: true,
        notified: notifiedCount,
        expired: expiredCount,
        duration_ms: duration,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )
  } catch (error: unknown) {
    const errorMessage = error instanceof Error ? error.message : String(error)
    console.error("Error in check-expiring-bookings:", errorMessage)

    return new Response(
      JSON.stringify({
        error: errorMessage,
        duration_ms: Date.now() - startTime,
      }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )
  }
})
