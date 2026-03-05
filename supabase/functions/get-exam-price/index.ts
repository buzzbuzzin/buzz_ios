// Supabase Edge Function to fetch exam price from Stripe product ID
// This function retrieves the active price for a given Stripe product

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import Stripe from "https://esm.sh/stripe@14.21.0?target=deno"

const supabaseUrl = Deno.env.get("SUPABASE_URL") as string
const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") as string

const stripeSecretKey = Deno.env.get("STRIPE_SECRET_KEY")
if (!stripeSecretKey) {
  throw new Error("STRIPE_SECRET_KEY environment variable is not set")
}

const stripe = new Stripe(stripeSecretKey, {
  httpClient: Stripe.createFetchHttpClient(),
})

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    // Authenticate the caller
    const authHeader = req.headers.get("Authorization")
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "Missing authorization header" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } }
    })
    const { data: { user }, error: authError } = await supabase.auth.getUser()
    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: "Unauthorized" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    const { product_id } = await req.json()

    // Validate required fields
    if (!product_id) {
      return new Response(
        JSON.stringify({ error: "Missing required field: product_id" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

    // Fetch the product to get its name
    const product = await stripe.products.retrieve(product_id)

    if (!product.active) {
      return new Response(
        JSON.stringify({ error: "Product is not active" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

    // Fetch the default price for the product
    // First, try to get the default price
    let price: Stripe.Price | null = null

    if (product.default_price) {
      const defaultPriceId = typeof product.default_price === 'string' 
        ? product.default_price 
        : product.default_price.id
      price = await stripe.prices.retrieve(defaultPriceId)
    }

    // If no default price, search for active prices
    if (!price || !price.active) {
      const prices = await stripe.prices.list({
        product: product_id,
        active: true,
        limit: 1,
      })

      if (prices.data.length === 0) {
        return new Response(
          JSON.stringify({ error: "No active price found for this product" }),
          {
            status: 404,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          }
        )
      }

      price = prices.data[0]
    }

    return new Response(
      JSON.stringify({
        product_id: product.id,
        price_id: price.id,
        unit_amount: price.unit_amount,
        currency: price.currency,
        product_name: product.name,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    )
  } catch (error: any) {
    console.error("Error fetching exam price:", error)
    
    // Handle Stripe-specific errors
    if (error.type === 'StripeInvalidRequestError') {
      return new Response(
        JSON.stringify({ error: "Invalid product ID" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

    return new Response(
      JSON.stringify({ error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    )
  }
})

