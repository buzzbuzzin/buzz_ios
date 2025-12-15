// Supabase Edge Function to send push notifications via Apple Push Notification Service (APNs)
// Uses JWT authentication with APNs

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { create, getNumericDate } from "https://deno.land/x/djwt@v3.0.1/mod.ts"

// APNs Configuration
const APNS_KEY_ID = Deno.env.get("APNS_KEY_ID") // Apple Push Notification Key ID
const APNS_TEAM_ID = Deno.env.get("APNS_TEAM_ID") // Apple Developer Team ID
const APNS_PRIVATE_KEY = Deno.env.get("APNS_PRIVATE_KEY") // APNs Auth Key (.p8 file contents)
const APNS_BUNDLE_ID = Deno.env.get("APNS_BUNDLE_ID") || "com.buzzbuzzin.buzz" // App Bundle ID

// Use sandbox for development, production for App Store builds
const APNS_HOST = Deno.env.get("APNS_PRODUCTION") === "true" 
  ? "api.push.apple.com" 
  : "api.sandbox.push.apple.com"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

interface PushNotificationRequest {
  user_id: string
  title: string
  body: string
  data?: Record<string, unknown>
  badge?: number
  sound?: string
}

interface APNsPayload {
  aps: {
    alert: {
      title: string
      body: string
    }
    badge?: number
    sound?: string
    "mutable-content"?: number
    "content-available"?: number
  }
  data?: Record<string, unknown>
}

// Cache for JWT token (valid for 1 hour, we'll refresh after 50 minutes)
let cachedJWT: { token: string; expiresAt: number } | null = null

/**
 * Generate JWT token for APNs authentication
 */
async function generateAPNsJWT(): Promise<string> {
  const now = Math.floor(Date.now() / 1000)
  
  // Return cached token if still valid (with 10 minute buffer)
  if (cachedJWT && cachedJWT.expiresAt > now + 600) {
    return cachedJWT.token
  }
  
  if (!APNS_PRIVATE_KEY || !APNS_KEY_ID || !APNS_TEAM_ID) {
    throw new Error("APNs credentials not configured")
  }
  
  // Parse the private key (PEM format)
  const pemContents = APNS_PRIVATE_KEY
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "")
  
  // Import the private key for ES256
  const binaryKey = Uint8Array.from(atob(pemContents), c => c.charCodeAt(0))
  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    binaryKey,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"]
  )
  
  // Create JWT payload
  const payload = {
    iss: APNS_TEAM_ID,
    iat: getNumericDate(0), // Now
  }
  
  // Create the JWT
  const token = await create(
    { alg: "ES256", typ: "JWT", kid: APNS_KEY_ID },
    payload,
    cryptoKey
  )
  
  // Cache for 50 minutes (token valid for 1 hour)
  cachedJWT = {
    token,
    expiresAt: now + 3000
  }
  
  return token
}

/**
 * Send push notification via APNs
 */
async function sendAPNsPush(
  deviceToken: string,
  payload: APNsPayload,
  jwt: string
): Promise<{ success: boolean; error?: string }> {
  const url = `https://${APNS_HOST}/3/device/${deviceToken}`
  
  try {
    const response = await fetch(url, {
      method: "POST",
      headers: {
        "authorization": `bearer ${jwt}`,
        "apns-topic": APNS_BUNDLE_ID,
        "apns-push-type": "alert",
        "apns-priority": "10",
        "apns-expiration": "0", // Immediate delivery only
        "content-type": "application/json",
      },
      body: JSON.stringify(payload),
    })
    
    if (response.ok) {
      return { success: true }
    }
    
    // Handle APNs errors
    const errorBody = await response.text()
    console.error(`APNs error (${response.status}): ${errorBody}`)
    
    // Parse error reason if available
    try {
      const errorJson = JSON.parse(errorBody)
      return { success: false, error: errorJson.reason || `HTTP ${response.status}` }
    } catch {
      return { success: false, error: `HTTP ${response.status}: ${errorBody}` }
    }
  } catch (error: unknown) {
    const errorMessage = error instanceof Error ? error.message : String(error)
    console.error("APNs request error:", errorMessage)
    return { success: false, error: errorMessage }
  }
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    // Verify APNs credentials are configured
    if (!APNS_KEY_ID || !APNS_TEAM_ID || !APNS_PRIVATE_KEY) {
      console.error("APNs credentials not configured")
      return new Response(
        JSON.stringify({ 
          error: "Push notification service not configured",
          details: "Missing APNs credentials"
        }),
        { status: 503, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    // Parse request body
    const data: PushNotificationRequest = await req.json()

    // Validate required fields
    if (!data.user_id || !data.title || !data.body) {
      return new Response(
        JSON.stringify({ 
          error: "Missing required fields: user_id, title, body" 
        }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    // Create Supabase client with service role
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    const supabase = createClient(supabaseUrl, supabaseServiceKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    })

    // Get device tokens for the user
    const { data: tokens, error: tokensError } = await supabase
      .rpc("get_user_device_tokens", { p_user_id: data.user_id })

    if (tokensError) {
      console.error("Error fetching device tokens:", tokensError)
      return new Response(
        JSON.stringify({ 
          error: "Failed to fetch device tokens",
          details: tokensError.message
        }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    if (!tokens || tokens.length === 0) {
      console.log(`No device tokens found for user ${data.user_id}`)
      return new Response(
        JSON.stringify({ 
          success: false,
          message: "No device tokens registered for user",
          sent: 0
        }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    // Generate APNs JWT
    const jwt = await generateAPNsJWT()

    // Build APNs payload
    const payload: APNsPayload = {
      aps: {
        alert: {
          title: data.title,
          body: data.body,
        },
        sound: data.sound || "default",
        "mutable-content": 1,
      },
    }

    if (data.badge !== undefined) {
      payload.aps.badge = data.badge
    }

    if (data.data) {
      payload.data = data.data
    }

    // Send to all iOS device tokens
    const results: { token: string; success: boolean; error?: string }[] = []
    const invalidTokens: string[] = []

    for (const tokenRecord of tokens) {
      if (tokenRecord.platform !== "ios") {
        continue // Skip non-iOS tokens for APNs
      }

      const result = await sendAPNsPush(tokenRecord.token, payload, jwt)
      results.push({
        token: tokenRecord.token.substring(0, 8) + "...", // Truncate for logging
        ...result
      })

      // Track invalid tokens for cleanup
      if (!result.success && result.error) {
        const invalidReasons = ["BadDeviceToken", "Unregistered", "ExpiredToken"]
        if (invalidReasons.some(reason => result.error!.includes(reason))) {
          invalidTokens.push(tokenRecord.token)
        }
      }
    }

    // Clean up invalid tokens
    if (invalidTokens.length > 0) {
      console.log(`Cleaning up ${invalidTokens.length} invalid tokens`)
      for (const token of invalidTokens) {
        await supabase
          .from("device_tokens")
          .update({ is_active: false })
          .eq("token", token)
      }
    }

    const successCount = results.filter(r => r.success).length
    const failCount = results.filter(r => !r.success).length

    console.log(`Push notifications sent: ${successCount} success, ${failCount} failed for user ${data.user_id}`)

    return new Response(
      JSON.stringify({
        success: successCount > 0,
        message: `Sent ${successCount} notification(s)`,
        sent: successCount,
        failed: failCount,
        results
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )
  } catch (error: unknown) {
    const errorMessage = error instanceof Error ? error.message : String(error)
    console.error("Error in send-push-notification:", errorMessage)
    
    return new Response(
      JSON.stringify({ error: errorMessage }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )
  }
})

