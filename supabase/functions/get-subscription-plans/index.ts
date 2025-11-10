// Supabase Edge Function to get available subscription plans
// Fetches prices from Stripe for the Automotive Flight Package product

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
// Using a more recent Stripe version that has better Deno compatibility
import Stripe from "https://esm.sh/stripe@14.21.0?target=deno&no-check"

const stripeSecretKey = Deno.env.get("STRIPE_SECRET_KEY")
if (!stripeSecretKey) {
  throw new Error("STRIPE_SECRET_KEY environment variable is not set")
}

const stripe = new Stripe(stripeSecretKey, {
  httpClient: Stripe.createFetchHttpClient(),
  apiVersion: "2023-10-16", // Pin API version for consistency
})

// IMPORTANT: Use the TEST MODE product ID if using test keys, or LIVE MODE product ID if using live keys
// You can find your test mode product ID in Stripe Dashboard > Products (make sure you're in Test mode)
const PRODUCT_ID = Deno.env.get("STRIPE_PRODUCT_ID") || "prod_TOW3rxsrI5xCs3" // Product ID

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    // Fetch all prices for the Automotive Flight Package product
    const prices = await stripe.prices.list({
      product: PRODUCT_ID,
      active: true,
    })

    if (prices.data.length === 0) {
      return new Response(
        JSON.stringify({ 
          plans: [],
          error: "No prices found for this product. Please create prices in Stripe Dashboard."
        }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

    // Map Stripe prices to plan format
    const plans = prices.data.map((price) => {
      // Extract features from metadata if available, or use defaults based on price
      let features: string[] = []
      
      if (price.metadata?.features) {
        // If features are stored as comma-separated string in metadata
        features = price.metadata.features.split(",").map((f: string) => f.trim())
      } else {
        // Default features based on price amount (you can customize this)
        const amount = price.unit_amount || 0
        if (amount < 4000) {
          features = ["5 flight credits", "Standard support"]
        } else if (amount < 8000) {
          features = ["15 flight credits", "Priority support", "20% discount"]
        } else {
          features = ["Unlimited credits", "24/7 support", "30% discount"]
        }
      }

      return {
        id: price.id,
        name: price.nickname || `Automotive Flight Package - ${price.recurring?.interval || "month"}`,
        description: price.metadata?.description || "Automotive flight package subscription",
        price_id: price.id,
        amount: price.unit_amount || 0,
        currency: price.currency,
        interval: price.recurring?.interval || "month",
        features: features,
      }
    })

    // Sort plans by amount (ascending)
    plans.sort((a, b) => a.amount - b.amount)

    return new Response(
      JSON.stringify({ plans }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    )
  } catch (error) {
    console.error("Error fetching plans:", error)
    
    // Provide helpful error message for product mismatch
    let errorMessage = error.message
    if (error.message?.includes("similar object exists")) {
      errorMessage = `Product ID '${PRODUCT_ID}' mode mismatch. Ensure your Stripe keys match the product's mode (test/live).`
    } else if (error.message?.includes("No such product")) {
      errorMessage = `Product ID '${PRODUCT_ID}' not found. Please check your Stripe Dashboard.`
    }
    
    // Return 200 with empty plans array to prevent iOS from retrying
    // The error message is included for debugging but won't cause retries
    return new Response(
      JSON.stringify({ 
        error: errorMessage,
        plans: [] // Return empty array so UI doesn't break
      }),
      {
        status: 200, // Return 200 instead of 400 to prevent retries
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    )
  }
})

