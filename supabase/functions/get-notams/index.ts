// Supabase Edge Function to fetch NOTAMs for nearby airports
// Uses Notamify API with Bearer token authentication

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const NOTAMIFY_API_KEY = Deno.env.get("NOTAMIFY_API_KEY")

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

interface GetNotamsRequest {
  latitude: number
  longitude: number
  radiusDegrees?: number // Default 0.5 (~55km)
}

interface METARStation {
  icaoId: string
  name?: string
  lat?: number
  lon?: number
}

interface NotamifyNotam {
  id: string
  notam_number: string
  icao_code: string
  location: string
  message: string
  icao_message: string
  starts_at: string
  ends_at: string
  issued_at: string
  is_permanent: boolean
  is_estimated: boolean
  interpretation: {
    category: string
    subcategory?: string
    excerpt: string
    description: string
    affected_elements?: Array<{
      type: string
      identifier: string
      effect: string
      details: string
    }>
    schedules?: Array<{
      description: string
      source: string
      rrule?: string
      duration_hrs?: number
      is_sunrise_sunset: boolean
    }>
  }
}

interface NotamifyResponse {
  notams: NotamifyNotam[]
  page: number
  per_page: number
  total_count: number
}

/**
 * Fetch nearby airports using aviationweather.gov METAR endpoint
 * Returns up to 5 ICAO codes for airports near the given coordinates
 */
async function getNearbyAirportICAOs(
  latitude: number,
  longitude: number,
  radiusDegrees: number
): Promise<string[]> {
  const minLat = latitude - radiusDegrees
  const maxLat = latitude + radiusDegrees
  const minLon = longitude - radiusDegrees
  const maxLon = longitude + radiusDegrees

  const url = `https://aviationweather.gov/api/data/metar?bbox=${minLat},${minLon},${maxLat},${maxLon}&format=json&hours=2`

  const response = await fetch(url, {
    headers: {
      "User-Agent": "Buzz/1.0",
      "Accept": "application/json",
    },
  })

  if (!response.ok) {
    if (response.status === 204) {
      return [] // No airports found in area
    }
    throw new Error(`Aviation weather API error: ${response.status}`)
  }

  const stations: METARStation[] = await response.json()

  // Extract unique ICAO codes, limit to 5 (Notamify API limit)
  const icaoCodes = [...new Set(
    stations
      .filter(s => s.icaoId && s.icaoId.length === 4)
      .map(s => s.icaoId)
  )].slice(0, 5)

  return icaoCodes
}

/**
 * Fetch NOTAMs from Notamify API for the given ICAO codes
 */
async function fetchNotams(icaoCodes: string[]): Promise<NotamifyNotam[]> {
  if (!NOTAMIFY_API_KEY) {
    throw new Error("NOTAMIFY_API_KEY environment variable is not set")
  }

  if (icaoCodes.length === 0) {
    return []
  }

  // Build URL with multiple location parameters
  const locationParams = icaoCodes.map(code => `location=${code}`).join("&")
  const url = `https://api.notamify.com/api/v2/notams?${locationParams}`

  const response = await fetch(url, {
    method: "GET",
    headers: {
      "Authorization": `Bearer ${NOTAMIFY_API_KEY}`,
      "Accept": "application/json",
    },
  })

  if (!response.ok) {
    const errorText = await response.text()
    console.error("Notamify API error:", errorText)
    throw new Error(`Notamify API error: ${response.status} - ${errorText}`)
  }

  const data: NotamifyResponse = await response.json()
  return data.notams || []
}

/**
 * Transform Notamify response to our app's format
 */
function transformNotams(notams: NotamifyNotam[]) {
  return notams.map(notam => ({
    id: notam.id,
    notamNumber: notam.notam_number || "",
    icaoCode: notam.icao_code || "",
    location: notam.location || "",
    message: notam.message || "",
    rawText: notam.icao_message || "",
    startsAt: notam.starts_at || new Date().toISOString(),
    endsAt: notam.ends_at || new Date(2099, 0, 1).toISOString(),
    issuedAt: notam.issued_at || new Date().toISOString(),
    isPermanent: notam.is_permanent ?? false,
    isEstimated: notam.is_estimated ?? false,
    interpretation: notam.interpretation ? {
      category: notam.interpretation.category || "OTHER",
      subcategory: notam.interpretation.subcategory || null,
      excerpt: notam.interpretation.excerpt || "",
      description: notam.interpretation.description || "",
      affectedElements: notam.interpretation.affected_elements?.map(el => ({
        type: el.type || "",
        identifier: el.identifier || "",
        effect: el.effect || "",
        details: el.details || "",
      })) || [],
      schedules: notam.interpretation.schedules?.map(s => ({
        description: s.description || "",
        source: s.source || "",
        durationHours: s.duration_hrs || null,
        isSunriseSunset: s.is_sunrise_sunset ?? false,
      })) || [],
    } : {
      category: "OTHER",
      subcategory: null,
      excerpt: "",
      description: "No interpretation available",
      affectedElements: [],
      schedules: [],
    },
  }))
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    const { 
      latitude, 
      longitude, 
      radiusDegrees = 0.5 
    }: GetNotamsRequest = await req.json()

    // Validate required fields
    if (latitude === undefined || longitude === undefined) {
      return new Response(
        JSON.stringify({
          error: "Missing required fields: latitude, longitude",
          notams: [],
          airports: [],
          totalCount: 0
        }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

    // Validate coordinates
    if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
      return new Response(
        JSON.stringify({
          error: "Invalid coordinates",
          notams: [],
          airports: [],
          totalCount: 0
        }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

    // Step 1: Get nearby airport ICAO codes
    console.log(`Fetching nearby airports for (${latitude}, ${longitude}) with radius ${radiusDegrees}`)
    const icaoCodes = await getNearbyAirportICAOs(latitude, longitude, radiusDegrees)
    
    if (icaoCodes.length === 0) {
      console.log("No nearby airports found")
      return new Response(
        JSON.stringify({ 
          notams: [],
          airports: [],
          message: "No nearby airports found"
        }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 200,
        }
      )
    }

    console.log(`Found ${icaoCodes.length} nearby airports: ${icaoCodes.join(", ")}`)

    // Step 2: Fetch NOTAMs for those airports
    const notams = await fetchNotams(icaoCodes)
    console.log(`Fetched ${notams.length} NOTAMs`)

    // Step 3: Transform and return
    const transformedNotams = transformNotams(notams)

    return new Response(
      JSON.stringify({
        notams: transformedNotams,
        airports: icaoCodes,
        totalCount: notams.length,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    )
  } catch (error: any) {
    console.error("Error fetching NOTAMs:", error)
    
    return new Response(
      JSON.stringify({
        error: error.message,
        notams: [],
        airports: [],
        totalCount: 0
      }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    )
  }
})
