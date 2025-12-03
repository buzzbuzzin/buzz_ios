-- Migration: Add booking_crew table for automotive multi-pilot bookings
-- Date: 2025-12-03
-- Description: Implements crew system where 4 pilots can join an automotive booking
--              with rank-based fixed payouts

-- Create booking_crew table
CREATE TABLE IF NOT EXISTS public.booking_crew (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  booking_id uuid NOT NULL,
  pilot_id uuid NOT NULL,
  role text NOT NULL CHECK (role IN ('lead', 'crew')),
  rank_at_acceptance integer NOT NULL CHECK (rank_at_acceptance >= 1 AND rank_at_acceptance <= 4),
  payout_amount numeric NOT NULL,
  transfer_id text,
  joined_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT booking_crew_pkey PRIMARY KEY (id),
  CONSTRAINT booking_crew_booking_id_fkey FOREIGN KEY (booking_id) REFERENCES public.bookings(id) ON DELETE CASCADE,
  CONSTRAINT booking_crew_pilot_id_fkey FOREIGN KEY (pilot_id) REFERENCES public.profiles(id),
  CONSTRAINT booking_crew_unique_pilot UNIQUE (booking_id, pilot_id)
);

-- Create index for efficient queries
CREATE INDEX IF NOT EXISTS idx_booking_crew_booking_id ON public.booking_crew(booking_id);
CREATE INDEX IF NOT EXISTS idx_booking_crew_pilot_id ON public.booking_crew(pilot_id);

-- Add comment for documentation
COMMENT ON TABLE public.booking_crew IS 'Tracks crew members for automotive bookings (4 pilots per booking)';
COMMENT ON COLUMN public.booking_crew.role IS 'lead = highest ranked pilot, crew = other pilots';
COMMENT ON COLUMN public.booking_crew.rank_at_acceptance IS 'Pilot tier at time of joining: 1=Sublieutenant, 2=Lieutenant, 3=Commander, 4=Captain';
COMMENT ON COLUMN public.booking_crew.payout_amount IS 'Fixed payout based on rank: $350/$450/$550/$650';

-- Create function to get payout amount based on rank
CREATE OR REPLACE FUNCTION get_rank_payout(rank_tier integer)
RETURNS numeric AS $$
BEGIN
  CASE rank_tier
    WHEN 1 THEN RETURN 350.00;  -- Sublieutenant
    WHEN 2 THEN RETURN 450.00;  -- Lieutenant
    WHEN 3 THEN RETURN 550.00;  -- Commander
    WHEN 4 THEN RETURN 650.00;  -- Captain
    ELSE RETURN 0;
  END CASE;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION get_rank_payout IS 'Returns fixed payout amount based on pilot rank tier for automotive bookings';

-- Enable RLS on booking_crew table
ALTER TABLE public.booking_crew ENABLE ROW LEVEL SECURITY;

-- Policy: Pilots can view their own crew memberships
CREATE POLICY "Pilots can view own crew memberships"
  ON public.booking_crew
  FOR SELECT
  USING (auth.uid() = pilot_id);

-- Note: Pilots viewing other crew members for the same booking is handled by
-- the get-booking-crew edge function which uses service role.
-- We don't add a self-referencing policy here to avoid infinite recursion.

-- Policy: Customers can view crew for their bookings
CREATE POLICY "Customers can view crew for their bookings"
  ON public.booking_crew
  FOR SELECT
  USING (
    booking_id IN (
      SELECT id FROM public.bookings WHERE customer_id = auth.uid()
    )
  );

-- Policy: Service role can do everything (for edge functions)
CREATE POLICY "Service role full access"
  ON public.booking_crew
  FOR ALL
  USING (auth.role() = 'service_role');

