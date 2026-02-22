// Supabase Edge Function to generate LiveKit room tokens for Hanger Spaces
// Uses LiveKit Server SDK for JWT generation

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { AccessToken } from "npm:livekit-server-sdk@2"

const LIVEKIT_API_KEY = Deno.env.get("LIVEKIT_API_KEY")
const LIVEKIT_API_SECRET = Deno.env.get("LIVEKIT_API_SECRET")
const LIVEKIT_WS_URL = Deno.env.get("LIVEKIT_WS_URL") // e.g., wss://your-project.livekit.cloud

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

interface TokenRequest {
  room_name: string
  user_name: string // display name (call_sign)
  can_publish: boolean // true for host/speaker, false for listener
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    if (!LIVEKIT_API_KEY || !LIVEKIT_API_SECRET || !LIVEKIT_WS_URL) {
      console.error("LiveKit credentials not configured")
      return new Response(
        JSON.stringify({
          error: "LiveKit service not configured",
          details: "Missing LiveKit credentials"
        }),
        { status: 503, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    // Verify the requesting user is authenticated
    const authHeader = req.headers.get("Authorization")
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!
    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader! } },
    })
    const { data: { user }, error: authError } = await supabase.auth.getUser()
    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: "Unauthorized" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    const data: TokenRequest = await req.json()

    if (!data.room_name || !data.user_name) {
      return new Response(
        JSON.stringify({ error: "Missing required fields: room_name, user_name" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    const at = new AccessToken(LIVEKIT_API_KEY, LIVEKIT_API_SECRET, {
      identity: user.id,
      name: data.user_name,
      ttl: "6h",
    })

    at.addGrant({
      room: data.room_name,
      roomJoin: true,
      canPublish: data.can_publish,
      canSubscribe: true,
      canPublishData: true,
    })

    const token = await at.toJwt()

    return new Response(
      JSON.stringify({ token, ws_url: LIVEKIT_WS_URL }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )
  } catch (error: unknown) {
    const errorMessage = error instanceof Error ? error.message : String(error)
    console.error("Error in generate-livekit-token:", errorMessage)
    return new Response(
      JSON.stringify({ error: errorMessage }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )
  }
})
