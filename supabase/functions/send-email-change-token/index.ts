// Supabase Edge Function to send email change verification token
// Generates a 6-digit token and sends it via email using SMTP

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { SMTPClient } from "https://deno.land/x/denomailer@1.6.0/mod.ts"

// SMTP Configuration - uses main Supabase SMTP settings
// Test account emails — skip sending emails for these users
const TEST_ACCOUNT_EMAILS = ["apptest@buzzbuzzin.com"]

const SMTP_HOST = Deno.env.get("SMTP_HOST") || "mail.buzzbuzzin.com"
const SMTP_PORT = parseInt(Deno.env.get("SMTP_PORT") || "465")
const SMTP_USERNAME = Deno.env.get("SMTP_USERNAME") || "noreply@buzzbuzzin.com"
const SMTP_PASSWORD = Deno.env.get("SMTP_PASSWORD") // Required - must be set in Supabase dashboard
const FROM_EMAIL = Deno.env.get("SMTP_FROM_EMAIL") || "noreply@buzzbuzzin.com"
const FROM_NAME = Deno.env.get("SMTP_FROM_NAME") || "Buzz Inc"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

interface EmailChangeRequest {
  old_email: string
  new_email: string
}

// Generate a random 6-digit token
function generateToken(): string {
  return Math.floor(100000 + Math.random() * 900000).toString()
}

// Generate HTML email template
function generateEmailHtml(oldEmail: string, newEmail: string, token: string): string {
  const currentYear = new Date().getFullYear()
  
  return `<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8" />
  <title>Confirm Email Change</title>
</head>
<body style="margin:0; padding:0; background-color:#EFEFF3; font-family:Arial, sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background-color:#EFEFF3; padding:40px 0;">
    <tr>
      <td align="center">

        <!-- Container -->
        <table width="480" cellpadding="0" cellspacing="0" 
          style="background:#ffffff; border-radius:10px; overflow:hidden; box-shadow:0px 4px 8px rgba(0,0,0,0.08);">

          <!-- Header -->
          <tr>
            <td style="background:#282C35; padding:24px; text-align:center; color:white; font-size:24px; font-weight:bold;">
              Confirm Email Change
            </td>
          </tr>

          <!-- Body -->
          <tr>
            <td style="padding:32px; color:#444444; font-size:16px; line-height:1.6;">
              <p>Hi there,</p>
              <p>You requested to update your email address. Please confirm the change by entering this verification code in the app:</p>

              <p style="padding:12px; background-color:#F4F4F6; border-radius:6px; font-size:14px; line-height:1.5;">
                <strong>Current Email:</strong> ${oldEmail} <br>
                <strong>New Email:</strong> ${newEmail}
              </p>

              <!-- Verification Code Display -->
              <div style="text-align:center; margin:32px 0;">
                <div style="background-color:#282C35; color:white; padding:20px 40px; border-radius:8px; font-size:36px; font-weight:bold; letter-spacing:8px; display:inline-block;">
                  ${token}
                </div>
              </div>

              <p style="text-align:center; color:#7f8c8d; font-size:14px;">
                Enter this code in the Buzz app to verify your email change.
              </p>

              <p style="padding:12px; background-color:#FFF3CD; border-left:4px solid #FFC107; border-radius:4px; font-size:14px; color:#856404;">
                <strong>⏱️ This code expires in 30 minutes.</strong>
              </p>

              <p>If you didn't request this change, you can safely ignore this email.</p>
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="background-color:#F4F4F6; padding:16px; text-align:center; font-size:12px; color:#888888;">
              © ${currentYear} Buzz | All rights reserved
            </td>
          </tr>

        </table>
        <!-- End Container -->

      </td>
    </tr>
  </table>
</body>
</html>`
}

// Generate plain text version
function generateEmailText(oldEmail: string, newEmail: string, token: string): string {
  return `CONFIRM EMAIL CHANGE

Hi there,

You requested to update your email address. Please confirm the change by entering this verification code in the app:

Current Email: ${oldEmail}
New Email: ${newEmail}

VERIFICATION CODE: ${token}

⏱️ This code expires in 30 minutes.

Enter this code in the Buzz app to verify your email change.

If you didn't request this change, you can safely ignore this email.

---
© ${new Date().getFullYear()} Buzz | All rights reserved`
}

serve(async (req) => {
  // Handle CORS preflight requests
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
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    const supabase = createClient(supabaseUrl, supabaseServiceKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    })

    // Verify user
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

    // Parse request body
    const data: EmailChangeRequest = await req.json()

    // Validate required fields
    if (!data.old_email || !data.new_email) {
      return new Response(
        JSON.stringify({ error: "Missing required fields: old_email, new_email" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    // Generate 6-digit token
    const verificationToken = generateToken()

    // Calculate expiration time (30 minutes from now)
    const expiresAt = new Date()
    expiresAt.setMinutes(expiresAt.getMinutes() + 30)

    // Store token in database
    const { error: insertError } = await supabase
      .from("email_change_tokens")
      .insert({
        user_id: user.id,
        old_email: data.old_email,
        new_email: data.new_email,
        token: verificationToken,
        verified: false,
        expires_at: expiresAt.toISOString(),
      })

    if (insertError) {
      console.error("Error inserting token:", insertError)
      return new Response(
        JSON.stringify({ error: "Failed to create verification token" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    // Skip sending email for test accounts (token is still stored for verification tests)
    if (TEST_ACCOUNT_EMAILS.includes(data.old_email) || TEST_ACCOUNT_EMAILS.includes(data.new_email)) {
      console.log(`Skipping email change token email for test account`)
      return new Response(
        JSON.stringify({
          success: true,
          message: "Skipped — test account (token stored)",
          expires_at: expiresAt.toISOString(),
        }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 200,
        }
      )
    }

    // Check if SMTP password is configured
    if (!SMTP_PASSWORD) {
      console.log("SMTP_PASSWORD not configured")
      return new Response(
        JSON.stringify({ error: "Email service not configured" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    // Generate email content
    const htmlContent = generateEmailHtml(data.old_email, data.new_email, verificationToken)
    const textContent = generateEmailText(data.old_email, data.new_email, verificationToken)
    const emailSubject = "Confirm Your Email Change"

    // Create SMTP client and send email
    const client = new SMTPClient({
      connection: {
        hostname: SMTP_HOST,
        port: SMTP_PORT,
        tls: true,
        auth: {
          username: SMTP_USERNAME,
          password: SMTP_PASSWORD,
        },
      },
    })

    try {
      await client.send({
        from: `${FROM_NAME} <${FROM_EMAIL}>`,
        to: data.new_email,
        subject: emailSubject,
        content: textContent,
        html: htmlContent,
      })
      
      await client.close()
      console.log(`Email change verification sent to ${data.new_email} for user ${user.id}`)
    } catch (smtpError: any) {
      console.error("SMTP error:", smtpError)
      
      // Close client safely
      try {
        await client.close()
      } catch (closeError) {
        console.error("Error closing SMTP client:", closeError)
      }
      
      return new Response(
        JSON.stringify({ 
          error: "Failed to send verification email",
          details: smtpError.message 
        }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: "Verification code sent successfully",
        expires_at: expiresAt.toISOString(),
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    )
  } catch (error: any) {
    console.error("Error in send-email-change-token:", error)
    
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    )
  }
})

