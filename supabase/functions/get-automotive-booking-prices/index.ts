// Supabase Edge Function to get automotive booking prices from Stripe
// Fetches subscription, first-time, and non-subscription prices

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

// Subscription-tier booking prices (for clients with active subscription)
const SUBSCRIPTION_PRODUCT_ID = "prod_TOW3rxsrI5xCs3"
const SUBSCRIPTION_PRICE_MAP: Record<string, string> = {
  "captain": "price_1SRj1FHxYl3GWOrz670Z6XuY",
  "commander": "price_1SVPNAHxYl3GWOrz3DuhDtBW",
  "lieutenant": "price_1SVPNAHxYl3GWOrzYtGbRZIn",
  "sub-lieutenant": "price_1SVPNAHxYl3GWOrzf8faB65K",
}

// First-time booking prices (for clients without subscription, first booking)
const FIRST_TIME_PRODUCT_ID = "prod_TeWRCH2oCZZ6HX"
const FIRST_TIME_PRICE_MAP: Record<string, string> = {
  "captain": "price_1ShDnQHxYl3GWOrza0ZgMG9B",
  "commander": "price_1ShDnbHxYl3GWOrzwznoJo4x",
  "lieutenant": "price_1ShDnjHxYl3GWOrzECVNxlg0",
  "sub-lieutenant": "price_1ShDnwHxYl3GWOrzz7iwZlim",
}

// Non-subscription booking prices (for returning clients without subscription)
const NON_SUBSCRIPTION_PRODUCT_ID = "prod_TeWRCH2oCZZ6HX"
const NON_SUBSCRIPTION_PRICE_MAP: Record<string, string> = {
  "captain": "price_1ShDOKHxYl3GWOrzJ6uCOqRH",
  "commander": "price_1ShDPIHxYl3GWOrzMLXJTOwW",
  "lieutenant": "price_1ShDPIHxYl3GWOrzKxe99tYo",
  "sub-lieutenant": "price_1ShDPIHxYl3GWOrzyNG4NGHb",
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
    console.log("🔍 Fetching automotive booking prices from Stripe...")

    // Fetch all three sets of prices in parallel
    const [subscriptionPrices, firstTimePrices, nonSubscriptionPrices] = await Promise.all([
      fetchPrices(SUBSCRIPTION_PRICE_MAP, "subscription"),
      fetchPrices(FIRST_TIME_PRICE_MAP, "first-time"),
      fetchPrices(NON_SUBSCRIPTION_PRICE_MAP, "non-subscription"),
    ])

    console.log(`✅ Fetched ${subscriptionPrices.length} subscription prices`)
    console.log(`✅ Fetched ${firstTimePrices.length} first-time prices`)
    console.log(`✅ Fetched ${nonSubscriptionPrices.length} non-subscription prices`)

    if (subscriptionPrices.length === 0 && firstTimePrices.length === 0 && nonSubscriptionPrices.length === 0) {
      return new Response(
        JSON.stringify({
          error: "No prices found. Please verify price IDs in Stripe.",
          subscriptionPrices: [],
          firstTimePrices: [],
          nonSubscriptionPrices: [],
        }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 200,
        }
      )
    }

    return new Response(
      JSON.stringify({
        subscriptionProductId: SUBSCRIPTION_PRODUCT_ID,
        subscriptionPrices: subscriptionPrices,
        firstTimeProductId: FIRST_TIME_PRODUCT_ID,
        firstTimePrices: firstTimePrices,
        nonSubscriptionProductId: NON_SUBSCRIPTION_PRODUCT_ID,
        nonSubscriptionPrices: nonSubscriptionPrices,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    )
  } catch (error: any) {
    console.error("Error fetching automotive booking prices:", error)
    return new Response(
      JSON.stringify({
        error: error.message,
        subscriptionPrices: [],
        firstTimePrices: [],
        nonSubscriptionPrices: [],
      }),
      {
        status: 200, // Return 200 to prevent retries
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    )
  }
})
