// Supabase Edge Function to create Stripe PaymentIntent for exam appointments
// This function creates a PaymentIntent for exam bookings (Flight Review / ROC-A)

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import Stripe from "https://esm.sh/stripe@14.21.0?target=deno"

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

interface ExamPaymentRequest {
  product_id: string
  pilot_id: string
  exam_type: string
  scheduled_date: string
  location_type: string
  location_address?: string
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    const { 
      product_id, 
      pilot_id, 
      exam_type, 
      scheduled_date, 
      location_type,
      location_address 
    }: ExamPaymentRequest = await req.json()

    // Validate required fields
    if (!product_id || !pilot_id || !exam_type || !scheduled_date || !location_type) {
      return new Response(
        JSON.stringify({ 
          error: "Missing required fields: product_id, pilot_id, exam_type, scheduled_date, location_type" 
        }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

    // Validate location_address for in-person exams
    if (location_type === 'in_person' && !location_address) {
      return new Response(
        JSON.stringify({ error: "location_address is required for in-person exams" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

    // Validate flight_review must be in-person
    if (exam_type === 'flight_review' && location_type !== 'in_person') {
      return new Response(
        JSON.stringify({ error: "Flight Review exam must be in-person" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

    // Fetch the product to verify it exists
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

    // Get the price for the product
    let price: Stripe.Price | null = null

    if (product.default_price) {
      const defaultPriceId = typeof product.default_price === 'string' 
        ? product.default_price 
        : product.default_price.id
      price = await stripe.prices.retrieve(defaultPriceId)
    }

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

    // Create or retrieve customer
    let customerId: string | undefined
    
    // Search for existing customer by metadata
    const existingCustomers = await stripe.customers.search({
      query: `metadata['user_id']:'${pilot_id}'`,
    })
    
    if (existingCustomers.data.length > 0) {
      customerId = existingCustomers.data[0].id
    } else {
      // Create new Stripe customer with pilot UUID in metadata
      const newCustomer = await stripe.customers.create({
        metadata: { user_id: pilot_id },
      })
      customerId = newCustomer.id
    }

    // Create ephemeral key for customer
    let ephemeralKeySecret: string | undefined
    try {
      const ephemeralKey = await stripe.ephemeralKeys.create(
        { customer: customerId },
        { apiVersion: "2024-11-20.acacia" }
      )
      ephemeralKeySecret = ephemeralKey.secret
    } catch (error) {
      console.log("Could not create ephemeral key:", error)
    }

    // Create PaymentIntent with exam metadata
    const paymentIntent = await stripe.paymentIntents.create({
      amount: price.unit_amount!,
      currency: price.currency,
      customer: customerId,
      metadata: {
        exam_type: exam_type,
        pilot_id: pilot_id,
        scheduled_date: scheduled_date,
        location_type: location_type,
        location_address: location_address || '',
        product_id: product_id,
        product_name: product.name,
      },
      automatic_payment_methods: {
        enabled: true,
      },
    })

    return new Response(
      JSON.stringify({
        client_secret: paymentIntent.client_secret,
        payment_intent_id: paymentIntent.id,
        customer_id: customerId,
        ephemeral_key_secret: ephemeralKeySecret,
        amount: price.unit_amount,
        currency: price.currency,
        product_name: product.name,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    )
  } catch (error: any) {
    console.error("Error creating exam payment:", error)
    
    if (error.type === 'StripeInvalidRequestError') {
      return new Response(
        JSON.stringify({ error: "Invalid request: " + error.message }),
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

