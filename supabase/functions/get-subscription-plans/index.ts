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
const DEFAULT_PRODUCT_ID = Deno.env.get("STRIPE_PRODUCT_ID") || "prod_TOW3rxsrI5xCs3" // Default Product ID

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    // Get product_id from request body or query params, or use default
    let productId = DEFAULT_PRODUCT_ID
    
    if (req.method === "POST") {
      try {
        const body = await req.json()
        console.log("📥 Received POST body:", JSON.stringify(body))
        if (body && body.product_id && body.product_id !== null && body.product_id !== undefined) {
          productId = body.product_id
          console.log("📦 Using product_id from POST body:", productId)
        } else {
          console.log("⚠️ No product_id in POST body, using default:", DEFAULT_PRODUCT_ID)
        }
      } catch (e) {
        console.log("⚠️ Could not parse POST body:", e)
      }
    } else if (req.method === "GET") {
      const url = new URL(req.url)
      const queryProductId = url.searchParams.get("product_id")
      if (queryProductId) {
        productId = queryProductId
        console.log("📦 Using product_id from query params:", productId)
      }
    }
    
    console.log("🔍 Fetching plans for product:", productId)

    // Fetch all prices for the specified product
    const prices = await stripe.prices.list({
      product: productId,
      active: true,
    })
    
    console.log(`✅ Found ${prices.data.length} prices for product ${productId}`)

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

    // Fetch the product details to get the product name and description
    // If we can't fetch product details, return an error - no hardcoded fallbacks
    let productName: string | null = null
    let productDescription: string | null = null
    try {
      const product = await stripe.products.retrieve(productId)
      productName = product.name || null
      productDescription = product.description || product.metadata?.description || null
      console.log(`📦 Product name: ${productName}, description: ${productDescription}`)
      
      if (!productName) {
        return new Response(
          JSON.stringify({ 
            plans: [],
            error: `Product ${productId} exists but has no name. Please set a product name in Stripe Dashboard.`
          }),
          {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          }
        )
      }
    } catch (e) {
      console.error("❌ Could not fetch product details:", e)
      return new Response(
        JSON.stringify({ 
          plans: [],
          error: `Failed to fetch product ${productId} from Stripe: ${e.message}. Please verify the product exists and your Stripe keys are correct.`
        }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

    // Map Stripe prices to plan format
    const plans = prices.data.map((price) => {
      console.log(`💰 Processing price ${price.id}:`)
      console.log(`   - Nickname: ${price.nickname || "(empty)"}`)
      console.log(`   - Metadata: ${JSON.stringify(price.metadata || {})}`)
      
      // Extract features from metadata if available, or use defaults
      let features: string[] = []
      
      if (price.metadata?.features) {
        // If features are stored as comma-separated string in metadata
        features = price.metadata.features.split(",").map((f: string) => f.trim())
      } else if (price.metadata?.feature) {
        // Single feature
        features = [price.metadata.feature]
      } else {
        // No default features - let Stripe metadata handle it
        features = []
      }

      // Get the plan name: use price nickname, or product name (which we know exists)
      // IMPORTANT: Price nickname takes priority over product name
      // If you want to use product name, clear the price nickname in Stripe
      let planName = price.nickname
      if (!planName || planName.trim() === "") {
        // If no nickname, use product name (guaranteed to exist at this point)
        planName = productName!
        console.log(`   - Using product name (no nickname): ${planName}`)
      } else {
        console.log(`   - Using price nickname: ${planName}`)
      }
      
      // Remove everything after comma if it exists (comma is used as separator for description)
      if (planName.includes(",")) {
        planName = planName.split(",")[0].trim()
        console.log(`   - Plan name after comma removal: ${planName}`)
      }

      // For description: use everything after comma in nickname, or price metadata, or product description
      // Priority: 1) nickname after comma, 2) price metadata.description, 3) product description
      let description = ""
      if (price.nickname && price.nickname.includes(",")) {
        description = price.nickname.split(",").slice(1).join(",").trim()
        console.log(`   - Description from nickname: ${description}`)
      } else if (price.metadata?.description) {
        description = price.metadata.description
        console.log(`   - Description from price metadata: ${description}`)
      } else if (productDescription) {
        description = productDescription
        console.log(`   - Description from product: ${description}`)
      } else {
        console.log(`   - No description found`)
      }
      // If description is still empty, leave it empty - let the UI handle it

      // Determine interval: use metadata if available, otherwise use recurring interval
      // No default fallback - if it's not recurring and no metadata, return empty string
      let interval = ""
      if (price.metadata?.interval) {
        interval = price.metadata.interval
      } else if (price.recurring?.interval) {
        interval = price.recurring.interval
      }
      // If no interval is found (one-time price with no metadata), leave it empty
      // The UI should handle empty intervals appropriately

      const plan = {
        id: price.id,
        name: planName,
        description: description,
        price_id: price.id,
        amount: price.unit_amount || 0,
        currency: price.currency,
        interval: interval,
        features: features,
      }
      
      console.log(`   ✅ Final plan: name="${plan.name}", description="${plan.description}", interval="${plan.interval}"`)
      
      return plan
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
      errorMessage = `Product ID mode mismatch. Ensure your Stripe keys match the product's mode (test/live).`
    } else if (error.message?.includes("No such product")) {
      errorMessage = `Product ID not found. Please check your Stripe Dashboard.`
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

