// Supabase Edge Function to create Stripe Payment Intent for test exam scheduling
// This replaces the need to fetch product IDs from Stripe - uses price directly from course_tests table

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import Stripe from 'https://esm.sh/stripe@14.5.0?target=deno'

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY') as string, {
  apiVersion: '2023-10-16',
  httpClient: Stripe.createFetchHttpClient(),
})

const supabaseUrl = Deno.env.get('SUPABASE_URL') as string
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') as string

interface PaymentRequest {
  test_id: string
  pilot_id: string
  amount: number
  scheduled_date: string
  location_type: string
  location_address?: string
}

serve(async (req) => {
  try {
    // Parse request body
    const {
      test_id,
      pilot_id,
      amount,
      scheduled_date,
      location_type,
      location_address,
    }: PaymentRequest = await req.json()

    // Validate required fields
    if (!test_id || !pilot_id || !amount || !scheduled_date || !location_type) {
      return new Response(
        JSON.stringify({
          error: 'Missing required fields: test_id, pilot_id, amount, scheduled_date, location_type',
        }),
        {
          status: 400,
          headers: { 'Content-Type': 'application/json' },
        }
      )
    }

    // Validate amount is positive
    if (amount <= 0) {
      return new Response(
        JSON.stringify({ error: 'Amount must be greater than 0' }),
        {
          status: 400,
          headers: { 'Content-Type': 'application/json' },
        }
      )
    }

    // Initialize Supabase client
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // Fetch test details to verify price and get test name
    const { data: test, error: testError } = await supabase
      .from('course_tests')
      .select('test_name, price_of_schedule')
      .eq('id', test_id)
      .single()

    if (testError || !test) {
      return new Response(
        JSON.stringify({ error: 'Test not found' }),
        {
          status: 404,
          headers: { 'Content-Type': 'application/json' },
        }
      )
    }

    // Verify that the amount matches the test price
    if (test.price_of_schedule !== amount) {
      return new Response(
        JSON.stringify({
          error: 'Amount mismatch',
          expected: test.price_of_schedule,
          provided: amount,
        }),
        {
          status: 400,
          headers: { 'Content-Type': 'application/json' },
        }
      )
    }

    // Fetch pilot details from 'profiles' table (not pilot_profiles)
    const { data: pilot, error: pilotError } = await supabase
      .from('profiles')
      .select('email, first_name, last_name')
      .eq('id', pilot_id)
      .single()

    if (pilotError || !pilot) {
      return new Response(
        JSON.stringify({ error: 'Pilot not found', details: pilotError?.message }),
        {
          status: 404,
          headers: { 'Content-Type': 'application/json' },
        }
      )
    }

    // Create a new Stripe customer for each payment (or you could store customer_id separately)
    const customer = await stripe.customers.create({
      email: pilot.email,
      name: `${pilot.first_name || ''} ${pilot.last_name || ''}`.trim() || 'Buzz Pilot',
      metadata: {
        pilot_id: pilot_id,
      },
    })

    const customerId = customer.id

    // Create Stripe Payment Intent
    const paymentIntent = await stripe.paymentIntents.create({
      amount: amount, // Amount in cents
      currency: 'usd',
      customer: customerId,
      automatic_payment_methods: {
        enabled: true,
      },
      metadata: {
        pilot_id: pilot_id,
        test_id: test_id,
        scheduled_date: scheduled_date,
        location_type: location_type,
        location_address: location_address || '',
      },
      description: `${test.test_name} - Scheduled Exam`,
    })

    // Create ephemeral key for customer
    const ephemeralKey = await stripe.ephemeralKeys.create(
      { customer: customerId },
      { apiVersion: '2023-10-16' }
    )

    // Return payment intent details
    return new Response(
      JSON.stringify({
        client_secret: paymentIntent.client_secret,
        payment_intent_id: paymentIntent.id,
        customer_id: customerId,
        ephemeral_key_secret: ephemeralKey.secret,
        amount: amount,
        currency: 'usd',
        product_name: test.test_name,
      }),
      {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      }
    )
  } catch (error) {
    console.error('Error creating payment intent:', error)
    return new Response(
      JSON.stringify({
        error: error.message || 'Internal server error',
      }),
      {
        status: 500,
        headers: { 'Content-Type': 'application/json' },
      }
    )
  }
})
