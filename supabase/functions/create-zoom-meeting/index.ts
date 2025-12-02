// Supabase Edge Function to create Zoom meetings for online exam appointments
// Uses Server-to-Server OAuth for authentication

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const ZOOM_ACCOUNT_ID = Deno.env.get("ZOOM_ACCOUNT_ID")
const ZOOM_CLIENT_ID = Deno.env.get("ZOOM_CLIENT_ID")
const ZOOM_CLIENT_SECRET = Deno.env.get("ZOOM_CLIENT_SECRET")

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

interface CreateMeetingRequest {
  topic: string
  scheduled_date: string // ISO 8601 format
  duration_minutes: number
  pilot_email?: string
}

interface ZoomMeetingResponse {
  join_url: string
  meeting_id: number
  password: string
  start_url: string
}

interface ZoomTokenResponse {
  access_token: string
  token_type: string
  expires_in: number
}

/**
 * Get access token using Server-to-Server OAuth
 * https://developers.zoom.us/docs/internal-apps/s2s-oauth/
 */
async function getZoomAccessToken(): Promise<string> {
  if (!ZOOM_ACCOUNT_ID || !ZOOM_CLIENT_ID || !ZOOM_CLIENT_SECRET) {
    throw new Error("Zoom credentials are not configured. Please set ZOOM_ACCOUNT_ID, ZOOM_CLIENT_ID, and ZOOM_CLIENT_SECRET.")
  }

  const credentials = btoa(`${ZOOM_CLIENT_ID}:${ZOOM_CLIENT_SECRET}`)
  
  const tokenResponse = await fetch(
    `https://zoom.us/oauth/token?grant_type=account_credentials&account_id=${ZOOM_ACCOUNT_ID}`,
    {
      method: "POST",
      headers: {
        "Authorization": `Basic ${credentials}`,
        "Content-Type": "application/x-www-form-urlencoded",
      },
    }
  )

  if (!tokenResponse.ok) {
    const errorText = await tokenResponse.text()
    console.error("Zoom OAuth error:", errorText)
    throw new Error(`Failed to get Zoom access token: ${tokenResponse.status}`)
  }

  const tokenData: ZoomTokenResponse = await tokenResponse.json()
  return tokenData.access_token
}

/**
 * Create a Zoom meeting
 * https://developers.zoom.us/docs/api/rest/reference/zoom-api/methods/#operation/meetingCreate
 */
async function createZoomMeeting(
  accessToken: string,
  topic: string,
  startTime: string,
  durationMinutes: number
): Promise<ZoomMeetingResponse> {
  // Use "me" to create meeting for the authenticated user (the account owner)
  const response = await fetch("https://api.zoom.us/v2/users/me/meetings", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      topic: topic,
      type: 2, // Scheduled meeting
      start_time: startTime,
      duration: durationMinutes,
      timezone: "UTC",
      settings: {
        waiting_room: true, // Enable waiting room as requested
        join_before_host: false,
        mute_upon_entry: true,
        auto_recording: "none",
        meeting_authentication: false,
        // Allow participants to join from browser without downloading Zoom
        alternative_hosts_email_notification: true,
      },
    }),
  })

  if (!response.ok) {
    const errorText = await response.text()
    console.error("Zoom API error:", errorText)
    throw new Error(`Failed to create Zoom meeting: ${response.status} - ${errorText}`)
  }

  const meetingData = await response.json()
  
  return {
    join_url: meetingData.join_url,
    meeting_id: meetingData.id,
    password: meetingData.password || "",
    start_url: meetingData.start_url,
  }
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    const { 
      topic, 
      scheduled_date, 
      duration_minutes,
      pilot_email 
    }: CreateMeetingRequest = await req.json()

    // Validate required fields
    if (!topic || !scheduled_date || !duration_minutes) {
      return new Response(
        JSON.stringify({ 
          error: "Missing required fields: topic, scheduled_date, duration_minutes" 
        }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

    // Get Zoom access token
    const accessToken = await getZoomAccessToken()

    // Create the meeting
    const meetingTopic = pilot_email 
      ? `${topic} - ${pilot_email}`
      : topic

    const meeting = await createZoomMeeting(
      accessToken,
      meetingTopic,
      scheduled_date,
      duration_minutes
    )

    console.log(`Created Zoom meeting: ${meeting.meeting_id} for ${meetingTopic}`)

    return new Response(
      JSON.stringify({
        join_url: meeting.join_url,
        meeting_id: meeting.meeting_id.toString(),
        password: meeting.password,
        start_url: meeting.start_url,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    )
  } catch (error: any) {
    console.error("Error creating Zoom meeting:", error)
    
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    )
  }
})

