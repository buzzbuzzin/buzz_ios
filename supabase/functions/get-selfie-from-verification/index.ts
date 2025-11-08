// Supabase Edge Function to retrieve selfie image from Stripe verification
// This function retrieves the selfie image from a completed verification session

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import Stripe from "https://esm.sh/stripe@14.21.0?target=deno"

const stripeSecretKey = Deno.env.get("STRIPE_SECRET_KEY")
if (!stripeSecretKey) {
  throw new Error("STRIPE_SECRET_KEY environment variable is not set")
}

const stripe = new Stripe(stripeSecretKey, {
  apiVersion: "2023-10-16",
  httpClient: Stripe.createFetchHttpClient(),
})

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    // Parse request body
    const { session_id } = await req.json()

    if (!session_id) {
      return new Response(
        JSON.stringify({ error: "session_id is required" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

    // Retrieve the verification session with expanded verification report
    const verificationSession = await stripe.identity.verificationSessions.retrieve(
      session_id,
      {
        expand: ["last_verification_report"],
      }
    )

    // Check if verification was successful
    if (verificationSession.status !== "verified") {
      return new Response(
        JSON.stringify({
          verified: false,
          error: "Verification was not successful",
        }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

    // Get the verification report
    const verificationReport = verificationSession.last_verification_report
    if (!verificationReport || typeof verificationReport === "string") {
      return new Response(
        JSON.stringify({
          verified: false,
          error: "Verification report not found",
        }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

    // Check if selfie check passed
    const selfieCheck = verificationReport.selfie
    if (!selfieCheck || selfieCheck.status !== "verified") {
      return new Response(
        JSON.stringify({
          verified: false,
          error: "Selfie verification failed",
        }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

    // Get the selfie file ID
    const selfieFileId = selfieCheck.selfie
    if (!selfieFileId || typeof selfieFileId !== "string") {
      return new Response(
        JSON.stringify({
          verified: false,
          error: "Selfie file not found",
        }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

    // Retrieve the file from Stripe
    const file = await stripe.files.retrieve(selfieFileId)
    
    // Create a file link to get a temporary URL for the file
    // File links expire after 1 hour by default
    const fileLink = await stripe.fileLinks.create({
      file: selfieFileId,
      expires_at: Math.floor(Date.now() / 1000) + 3600, // 1 hour from now
    })

    if (!fileLink.url) {
      return new Response(
        JSON.stringify({
          verified: false,
          error: "Could not retrieve selfie image URL",
        }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

    // Return the selfie image URL
    return new Response(
      JSON.stringify({
        verified: true,
        selfie_image_url: fileLink.url,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    )
  } catch (error) {
    console.error("Error retrieving selfie from verification:", error)
    return new Response(
      JSON.stringify({
        verified: false,
        error: error.message || "Failed to retrieve selfie from verification",
      }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    )
  }
})

