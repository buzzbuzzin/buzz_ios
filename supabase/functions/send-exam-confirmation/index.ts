// Supabase Edge Function to send exam confirmation emails
// Uses direct SMTP connection to your mail server

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { SMTPClient } from "https://deno.land/x/denomailer@1.6.0/mod.ts"

// SMTP Configuration - uses EXAM_EMAIL_ prefix to avoid conflicts with other SMTP configs
const SMTP_HOST = Deno.env.get("EXAM_EMAIL_HOST") || "mail.buzzacademy.world"
const SMTP_PORT = parseInt(Deno.env.get("EXAM_EMAIL_PORT") || "465")
const SMTP_USERNAME = Deno.env.get("EXAM_EMAIL_USERNAME") || "hello@buzzacademy.world"
const SMTP_PASSWORD = Deno.env.get("EXAM_EMAIL_PASSWORD")
const FROM_EMAIL = Deno.env.get("EXAM_EMAIL_FROM") || "hello@buzzacademy.world"
const FROM_NAME = Deno.env.get("EXAM_EMAIL_FROM_NAME") || "Buzz Academy"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

interface ExamConfirmationRequest {
  pilot_id: string
  pilot_email: string
  exam_type: string
  exam_type_display: string
  scheduled_date: string
  duration_minutes: number
  location_type: string
  location_address?: string
  meeting_link?: string
  zoom_meeting_password?: string
  appointment_id: string
}

function formatDate(dateString: string): string {
  const date = new Date(dateString)
  return date.toLocaleDateString('en-US', {
    weekday: 'long',
    year: 'numeric',
    month: 'long',
    day: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
    timeZoneName: 'short'
  })
}

// Helper function to remove trailing whitespace from each line
function trimLines(str: string): string {
  return str.split('\n').map(line => line.trimEnd()).join('\n')
}

function generateEmailHtml(data: ExamConfirmationRequest): string {
  const formattedDate = formatDate(data.scheduled_date)
  const isOnline = data.location_type === 'online'
  const currentYear = new Date().getFullYear()

  // Build Zoom meeting section for online exams (inline to avoid whitespace)
  let zoomSection = ''
  if (isOnline && data.meeting_link) {
    const passwordHtml = data.zoom_meeting_password
      ? `<p style="font-size:14px;color:#7f8c8d;margin:8px 0 0 0;"><strong>Password:</strong> ${data.zoom_meeting_password}</p>`
      : ''
    zoomSection = `<p style="margin-top:24px;margin-bottom:8px;font-weight:bold;color:#282C35;">Zoom Meeting Details:</p><p style="text-align:center;margin:16px 0;"><a href="${data.meeting_link}" style="background-color:#282C35;text-decoration:none;color:white;padding:14px 28px;border-radius:6px;font-weight:bold;display:inline-block;">Join Zoom Meeting</a></p><p style="font-size:14px;word-break:break-word;color:#7f8c8d;margin:0;"><strong>Meeting Link:</strong> <a href="${data.meeting_link}" style="color:#2563EB;">${data.meeting_link}</a></p>${passwordHtml}`
  }

  // Build location section for in-person exams (inline to avoid whitespace)
  let locationSection = ''
  if (!isOnline && data.location_address) {
    locationSection = `<p style="margin-top:24px;margin-bottom:8px;font-weight:bold;color:#282C35;">Location:</p><p style="font-size:14px;color:#7f8c8d;margin:0;">${data.location_address}</p>`
  }

  // Build reminder items
  const reminderItems = isOnline
    ? '<li>Please be ready 10 minutes before your scheduled time</li><li>Ensure you have a stable internet connection and working camera/microphone</li><li>Results will be provided immediately after completion</li>'
    : '<li>Please be ready 10 minutes before your scheduled time</li><li>Bring valid government-issued identification</li><li>Results will be provided immediately after completion</li>'

  // Use trimLines to remove any trailing whitespace from each line
  const html = trimLines(`<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8"/>
<title>Exam Confirmed</title>
</head>
<body style="margin:0;padding:0;background-color:#EFEFF3;font-family:Arial,sans-serif;">
<table width="100%" cellpadding="0" cellspacing="0" style="background-color:#EFEFF3;padding:40px 0;">
<tr>
<td align="center">
<table width="480" cellpadding="0" cellspacing="0" style="background:#ffffff;border-radius:10px;overflow:hidden;box-shadow:0px 4px 8px rgba(0,0,0,0.08);">
<tr>
<td style="background:#282C35;padding:24px;text-align:center;color:white;font-size:24px;font-weight:bold;">
Exam Confirmed
</td>
</tr>
<tr>
<td style="padding:32px;color:#444444;font-size:16px;line-height:1.6;">
<p style="margin:0 0 16px 0;">Hi there,</p>
<p style="margin:0 0 16px 0;">Great news! Your <strong>${data.exam_type_display}</strong> has been successfully scheduled. Here are your appointment details:</p>
<table width="100%" cellpadding="12" cellspacing="0" style="background-color:#F4F4F6;border-radius:8px;margin:24px 0;">
<tr>
<td style="color:#666666;width:40%;">Exam Type:</td>
<td style="font-weight:bold;color:#282C35;">${data.exam_type_display}</td>
</tr>
<tr>
<td style="color:#666666;">Date &amp; Time:</td>
<td style="font-weight:bold;color:#282C35;">${formattedDate}</td>
</tr>
<tr>
<td style="color:#666666;">Duration:</td>
<td style="font-weight:bold;color:#282C35;">${data.duration_minutes} minutes</td>
</tr>
<tr>
<td style="color:#666666;">Format:</td>
<td style="font-weight:bold;color:#282C35;">${isOnline ? 'Online (Zoom)' : 'In-Person'}</td>
</tr>
</table>
${zoomSection}${locationSection}
<p style="margin-top:24px;margin-bottom:8px;font-weight:bold;color:#282C35;">Important Reminders:</p>
<ul style="color:#666666;padding-left:20px;margin:0 0 16px 0;">
${reminderItems}
</ul>
<p style="margin-top:24px;padding:16px;background-color:#FFF3CD;border-radius:8px;font-size:14px;color:#856404;">
<strong>Reschedule Policy:</strong> Exam fees are non-refundable. You may reschedule up to 24 hours before your scheduled time at no additional cost. Rescheduling is not available within 24 hours of your exam.
</p>
<p style="margin-top:24px;margin-bottom:16px;">If you have any questions, please don't hesitate to contact our support team.</p>
<p style="margin:0;">See you soon!</p>
</td>
</tr>
<tr>
<td style="background-color:#F4F4F6;padding:16px;text-align:center;font-size:12px;color:#888888;">
&copy; ${currentYear} Buzz Inc. | All rights reserved
</td>
</tr>
</table>
</td>
</tr>
</table>
</body>
</html>`)

  return html
}

function generateEmailText(data: ExamConfirmationRequest): string {
  const formattedDate = formatDate(data.scheduled_date)
  const isOnline = data.location_type === 'online'

  const lines: string[] = [
    'EXAM CONFIRMED!',
    '',
    `Your ${data.exam_type_display} has been successfully scheduled.`,
    '',
    'APPOINTMENT DETAILS',
    `- Exam Type: ${data.exam_type_display}`,
    `- Date & Time: ${formattedDate}`,
    `- Duration: ${data.duration_minutes} minutes`,
    `- Format: ${isOnline ? 'Online (Zoom)' : 'In-Person'}`,
  ]

  if (isOnline && data.meeting_link) {
    lines.push('')
    lines.push('ZOOM MEETING DETAILS')
    lines.push(`Join Link: ${data.meeting_link}`)
    if (data.zoom_meeting_password) {
      lines.push(`Password: ${data.zoom_meeting_password}`)
    }
  } else if (data.location_address) {
    lines.push('')
    lines.push('LOCATION')
    lines.push(data.location_address)
  }

  lines.push('')
  lines.push('IMPORTANT REMINDERS')
  lines.push('- Please be ready 10 minutes before your scheduled time')
  lines.push(isOnline
    ? '- Ensure you have a stable internet connection and working camera/microphone'
    : '- Bring valid government-issued identification')
  lines.push('- Results will be provided immediately after completion')
  lines.push('')
  lines.push('RESCHEDULE POLICY')
  lines.push('Exam fees are non-refundable. You may reschedule your exam up to 24 hours before the scheduled time at no additional cost. Rescheduling is not available within 24 hours of your exam.')
  lines.push('')
  lines.push('---')
  lines.push('This email was sent by Buzz App.')
  lines.push('If you have any questions, please contact our support team.')

  return lines.join('\n')
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    const data: ExamConfirmationRequest = await req.json()

    // Validate required fields
    if (!data.pilot_email || !data.exam_type || !data.scheduled_date) {
      return new Response(
        JSON.stringify({ 
          error: "Missing required fields: pilot_email, exam_type, scheduled_date" 
        }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

    // Check if SMTP password is configured
    if (!SMTP_PASSWORD) {
      console.log("SMTP_PASSWORD not configured, skipping email")
      return new Response(
        JSON.stringify({ 
          success: true,
          warning: "Email service not configured (missing SMTP_PASSWORD), but appointment was created successfully"
        }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 200,
        }
      )
    }

    // Generate email content
    const htmlContent = generateEmailHtml(data)
    const emailSubject = `Exam Confirmed: ${data.exam_type_display} - ${formatDate(data.scheduled_date)}`

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
      // Generate plain text version
      const textContent = generateEmailText(data)

      await client.send({
        from: `${FROM_NAME} <${FROM_EMAIL}>`,
        to: data.pilot_email,
        subject: emailSubject,
        content: textContent,
        html: htmlContent,
      })
      
      await client.close()
      console.log(`Confirmation email sent to ${data.pilot_email} for appointment ${data.appointment_id}`)
    } catch (smtpError: any) {
      console.error("SMTP error:", smtpError)
      await client.close()
      
      return new Response(
        JSON.stringify({ 
          success: true,
          warning: "Email could not be sent, but appointment was created successfully",
          error: smtpError.message
        }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 200,
        }
      )
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: "Confirmation email sent successfully"
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    )
  } catch (error: any) {
    console.error("Error in send-exam-confirmation:", error)
    
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    )
  }
})

