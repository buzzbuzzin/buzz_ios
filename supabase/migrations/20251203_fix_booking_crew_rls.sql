-- Migration: Fix infinite recursion in booking_crew RLS policies
-- Date: 2025-12-03
-- Description: Removes the recursive policy that caused infinite recursion error

-- Drop the problematic recursive policy
DROP POLICY IF EXISTS "Pilots can view crew for their bookings" ON public.booking_crew;

-- The remaining policies are sufficient:
-- 1. "Pilots can view own crew memberships" - pilots see their own records
-- 2. "Customers can view crew for their bookings" - customers see crew for their bookings (no recursion, queries bookings table)
-- 3. "Service role full access" - edge functions can do everything

-- If pilots need to see other crew members for the same booking, 
-- they should use the get-booking-crew edge function which uses service role

