// Supabase Edge Function to get real estate booking prices from Stripe
// Fetches prices based on property size (under 5,000 sq ft or above 5,000 sq ft)

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import Stripe from "https://esm.sh/stripe@14.21.0?target=deno&no-check"

const stripeSecretKey = Deno.env.get("STRIPE_SECRET_KEY")
if (!stripeSecretKey) {
  throw new Error("STRIPE_SECRET_KEY environment variable is not set")
}

const stripe = new Stripe(stripeSecretKey, {
  httpClient: Stripe.createFetchHttpClient(),
  apiVersion: "2024-11-20.acacia",
})

// Under 5,000 sq ft property prices
const UNDER_5000_PRODUCT_ID = "prod_TPbEVKDoBBsN08"
const UNDER_5000_PRICE_MAP: Record<string, string> = {
  "captain": "price_1SSm2BHxYl3GWOrz3E35qysX",
  "commander": "price_1ShCwEHxYl3GWOrzd3z6dJrc",
  "lieutenant": "price_1ShCxDHxYl3GWOrz076LOC1s",
  "sub-lieutenant": "price_1ShCxUHxYl3GWOrzDEmQb725",
  "ensign": "price_1ShCxjHxYl3GWOrzVy0vW5RD",
}

// Above 5,000 sq ft property prices
const ABOVE_5000_PRODUCT_ID = "prod_TeWOxB87WBDqdI"
const ABOVE_5000_PRICE_MAP: Record<string, string> = {
  "captain": "price_1ShDLuHxYl3GWOrzQwd5IIjK",
  "commander": "price_1ShDN4HxYl3GWOrzk5BM452O",
  "lieutenant": "price_1ShDN4HxYl3GWOrzLqut62lj",
  "sub-lieutenant": "price_1ShDN4HxYl3GWOrzu78s9lR8",
  "ensign": "price_1ShDN4HxYl3GWOrz1AUaxbcv",
}

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

interface PriceInfo {
  rank: string
  rankTier: number
  priceId: string
  amount: number
  currency: string
}

function getRankTier(rank: string): number {
  switch (rank) {
    case "captain": return 4
    case "commander": return 3
    case "lieutenant": return 2
    case "sub-lieutenant": return 1
    case "ensign": return 0
    default: return 0
  }
}

async function fetchPrices(priceMap: Record<string, string>, label: string): Promise<PriceInfo[]> {
  const prices: PriceInfo[] = []

  for (const [rank, priceId] of Object.entries(priceMap)) {
    try {
      const price = await stripe.prices.retrieve(priceId)
      
      prices.push({
        rank: rank,
        rankTier: getRankTier(rank),
        priceId: priceId,
        amount: price.unit_amount || 0,
        currency: price.currency,
      })

      console.log(`✅ [${label}] Fetched price for ${rank}: ${price.unit_amount} ${price.currency}`)
    } catch (e) {
      console.error(`❌ [${label}] Failed to fetch price for ${rank} (${priceId}):`, e)
      // Continue with other prices even if one fails
    }
  }

  // Sort by rank tier (highest first)
  prices.sort((a, b) => b.rankTier - a.rankTier)
  
  return prices
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    console.log("🔍 Fetching real estate booking prices from Stripe...")

    // Fetch both sets of prices in parallel
    const [under5000Prices, above5000Prices] = await Promise.all([
      fetchPrices(UNDER_5000_PRICE_MAP, "under-5000"),
      fetchPrices(ABOVE_5000_PRICE_MAP, "above-5000"),
    ])

    console.log(`✅ Fetched ${under5000Prices.length} under-5000 sq ft prices`)
    console.log(`✅ Fetched ${above5000Prices.length} above-5000 sq ft prices`)

    if (under5000Prices.length === 0 && above5000Prices.length === 0) {
      return new Response(
        JSON.stringify({
          error: "No prices found. Please verify price IDs in Stripe.",
          under5000Prices: [],
          above5000Prices: [],
        }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 200,
        }
      )
    }

    return new Response(
      JSON.stringify({
        under5000ProductId: UNDER_5000_PRODUCT_ID,
        under5000Prices: under5000Prices,
        above5000ProductId: ABOVE_5000_PRODUCT_ID,
        above5000Prices: above5000Prices,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    )
  } catch (error: any) {
    console.error("Error fetching real estate booking prices:", error)
    return new Response(
      JSON.stringify({
        error: error.message,
        under5000Prices: [],
        above5000Prices: [],
      }),
      {
        status: 200, // Return 200 to prevent retries
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    )
  }
})

