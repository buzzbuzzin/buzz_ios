// Supabase Edge Function to clean up stale Hanger Spaces
// Should be invoked as a scheduled cron job (e.g., every 15 minutes)
// Ends spaces that have no active participants or have been live for more than 12 hours

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
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    const supabase = createClient(supabaseUrl, supabaseServiceKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    })

    const now = new Date()
    const twelveHoursAgo = new Date(now.getTime() - 12 * 60 * 60 * 1000).toISOString()

    // End spaces that have been live for more than 12 hours
    const { data: staleByTime, error: timeError } = await supabase
      .from("hanger_spaces")
      .update({ status: "ended", ended_at: now.toISOString(), updated_at: now.toISOString() })
      .eq("status", "live")
      .lt("started_at", twelveHoursAgo)
      .select("id")

    if (timeError) {
      console.error("Error ending stale spaces by time:", timeError)
    }

    // End spaces with no active participants (listener_count + speaker_count == 0)
    const { data: staleByParticipants, error: participantError } = await supabase
      .from("hanger_spaces")
      .update({ status: "ended", ended_at: now.toISOString(), updated_at: now.toISOString() })
      .eq("status", "live")
      .eq("listener_count", 0)
      .eq("speaker_count", 0)
      .select("id")

    if (participantError) {
      console.error("Error ending stale spaces by participants:", participantError)
    }

    const endedByTime = staleByTime?.length ?? 0
    const endedByParticipants = staleByParticipants?.length ?? 0
    const totalEnded = endedByTime + endedByParticipants

    console.log(`Cleanup complete: ended ${totalEnded} stale spaces (${endedByTime} by time, ${endedByParticipants} by empty participants)`)

    return new Response(
      JSON.stringify({
        success: true,
        ended_by_time: endedByTime,
        ended_by_empty_participants: endedByParticipants,
        total_ended: totalEnded
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )
  } catch (error: unknown) {
    const errorMessage = error instanceof Error ? error.message : String(error)
    console.error("Error in cleanup-stale-spaces:", errorMessage)
    return new Response(
      JSON.stringify({ error: errorMessage }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )
  }
})
