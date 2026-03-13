-- Migration: Seed two completed bookings for TORQUE and WOLF (demo purposes)
-- Customer: EA DPW (looked up by first_name/last_name)
-- Created: 2026-03-12

-- Booking 1: TORQUE as pilot, EA DPW as customer — Real Estate drone photography in Ithaca, NY
INSERT INTO public.bookings (
  id, customer_id, pilot_id,
  location_lat, location_lng, location_name,
  description, payment_amount, tip_amount,
  status, specialization, estimated_flight_hours,
  scheduled_date, end_date,
  required_minimum_rank,
  customer_completed, pilot_completed, completed_at,
  pilot_rated, customer_rated,
  is_internal_test,
  created_at
)
SELECT
  'a1b2c3d4-0001-4000-8000-000000000001'::uuid,
  customer.id,
  torque.id,
  42.4534, -76.4735, 'Cayuga Heights, Ithaca, NY',
  'Aerial photography and video for luxury lakefront property listing. Capture exterior shots, surrounding landscape, and proximity to Cayuga Lake.',
  500.00, 50.00,
  'completed', 'real_estate', 2.5,
  '2026-03-01 10:00:00+00'::timestamptz,
  '2026-03-01 12:30:00+00'::timestamptz,
  0,
  true, true, '2026-03-01 12:30:00+00'::timestamptz,
  true, true,
  false,
  '2026-02-25 14:00:00+00'::timestamptz
FROM public.profiles torque, public.profiles customer
WHERE torque.call_sign = 'TORQUE'
  AND customer.first_name = 'EA' AND customer.last_name = 'DPW'
  AND NOT EXISTS (
    SELECT 1 FROM public.bookings WHERE id = 'a1b2c3d4-0001-4000-8000-000000000001'::uuid
  );

-- Booking 2: WOLF as pilot, EA DPW as customer — Agriculture inspection near Hamilton, ON
INSERT INTO public.bookings (
  id, customer_id, pilot_id,
  location_lat, location_lng, location_name,
  description, payment_amount, tip_amount,
  status, specialization, estimated_flight_hours,
  scheduled_date, end_date,
  required_minimum_rank,
  customer_completed, pilot_completed, completed_at,
  pilot_rated, customer_rated,
  is_internal_test,
  created_at
)
SELECT
  'a1b2c3d4-0002-4000-8000-000000000002'::uuid,
  customer.id,
  wolf.id,
  43.2557, -79.8711, 'Hamilton, Ontario, Canada',
  'Crop health assessment and NDVI mapping for 200-acre vineyard. Identify irrigation issues and pest damage using multispectral imaging.',
  750.00, 100.00,
  'completed', 'agriculture', 3.0,
  '2026-02-22 09:00:00+00'::timestamptz,
  '2026-02-22 12:00:00+00'::timestamptz,
  1,
  true, true, '2026-02-22 12:00:00+00'::timestamptz,
  true, true,
  false,
  '2026-02-15 09:00:00+00'::timestamptz
FROM public.profiles wolf, public.profiles customer
WHERE wolf.call_sign = 'WOLF'
  AND customer.first_name = 'EA' AND customer.last_name = 'DPW'
  AND NOT EXISTS (
    SELECT 1 FROM public.bookings WHERE id = 'a1b2c3d4-0002-4000-8000-000000000002'::uuid
  );
