-- Migration: Add Search & Rescue crew support and flexible payment
-- Description: Extends booking system to support S&R missions with multi-pilot crews
--              and voluntary or hourly-rate payment options

-- Add new columns to bookings table for S&R support
ALTER TABLE public.bookings 
ADD COLUMN IF NOT EXISTS is_voluntary boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS hourly_rate numeric DEFAULT 0,
ADD COLUMN IF NOT EXISTS final_hours_worked double precision;

-- Add comments for documentation
COMMENT ON COLUMN public.bookings.is_voluntary IS 'True if this is a voluntary mission with no payment to pilots';
COMMENT ON COLUMN public.bookings.hourly_rate IS 'Hourly rate per pilot for S&R missions (typically $25)';
COMMENT ON COLUMN public.bookings.final_hours_worked IS 'Actual hours worked, entered by client after mission completion';

-- Update the specialization check constraint to include mapping_surveying if not present
-- (search_rescue should already be included based on existing schema)
DO $$
BEGIN
    -- Check if mapping_surveying is in the constraint, if not, update it
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.check_constraints 
        WHERE constraint_name LIKE '%specialization%' 
        AND check_clause LIKE '%mapping_surveying%'
    ) THEN
        -- Drop and recreate the constraint with all specializations
        ALTER TABLE public.bookings DROP CONSTRAINT IF EXISTS bookings_specialization_check;
        ALTER TABLE public.bookings ADD CONSTRAINT bookings_specialization_check 
            CHECK (specialization IS NULL OR specialization = ANY (ARRAY[
                'automotive'::text, 
                'motion_picture'::text, 
                'real_estate'::text, 
                'agriculture'::text, 
                'inspections'::text, 
                'search_rescue'::text, 
                'logistics'::text, 
                'drone_art'::text, 
                'surveillance_security'::text,
                'mapping_surveying'::text
            ]));
    END IF;
END $$;

-- Create function to calculate S&R payout for a pilot
CREATE OR REPLACE FUNCTION get_search_rescue_payout(hours double precision, hourly_rate numeric)
RETURNS numeric AS $$
BEGIN
    -- Simple calculation: hours × hourly rate
    -- All pilots get the same rate regardless of rank
    RETURN ROUND((hours * hourly_rate)::numeric, 2);
END;
$$ LANGUAGE plpgsql;

-- Create function to calculate total S&R payment
CREATE OR REPLACE FUNCTION calculate_search_rescue_total(
    p_booking_id uuid,
    p_hours double precision
)
RETURNS TABLE (
    total_amount numeric,
    pilot_count integer,
    amount_per_pilot numeric
) AS $$
DECLARE
    v_hourly_rate numeric;
    v_pilot_count integer;
BEGIN
    -- Get hourly rate from booking
    SELECT hourly_rate INTO v_hourly_rate
    FROM public.bookings
    WHERE id = p_booking_id;
    
    -- Count pilots who joined this booking
    SELECT COUNT(*) INTO v_pilot_count
    FROM public.booking_crew
    WHERE booking_id = p_booking_id;
    
    -- Calculate amounts
    amount_per_pilot := ROUND((p_hours * v_hourly_rate)::numeric, 2);
    pilot_count := v_pilot_count;
    total_amount := amount_per_pilot * v_pilot_count;
    
    RETURN NEXT;
END;
$$ LANGUAGE plpgsql;

-- Create function to join a Search & Rescue booking (similar to automotive but simpler)
CREATE OR REPLACE FUNCTION join_search_rescue_booking(
    p_booking_id uuid,
    p_pilot_id uuid
)
RETURNS json AS $$
DECLARE
    v_booking record;
    v_existing_crew integer;
    v_pilot_stats record;
    v_result json;
BEGIN
    -- Get booking details
    SELECT * INTO v_booking
    FROM public.bookings
    WHERE id = p_booking_id;
    
    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'error', 'Booking not found');
    END IF;
    
    -- Verify it's a search_rescue booking
    IF v_booking.specialization != 'search_rescue' THEN
        RETURN json_build_object('success', false, 'error', 'Not a Search & Rescue booking');
    END IF;
    
    -- Check if booking is still available
    IF v_booking.status NOT IN ('available', 'accepted') THEN
        RETURN json_build_object('success', false, 'error', 'Booking is no longer available');
    END IF;
    
    -- Check if pilot already joined
    SELECT COUNT(*) INTO v_existing_crew
    FROM public.booking_crew
    WHERE booking_id = p_booking_id AND pilot_id = p_pilot_id;
    
    IF v_existing_crew > 0 THEN
        RETURN json_build_object('success', false, 'error', 'Already joined this mission');
    END IF;
    
    -- Get pilot stats
    SELECT * INTO v_pilot_stats
    FROM public.pilot_stats
    WHERE pilot_id = p_pilot_id;
    
    -- Insert crew member (no fixed payout yet - calculated at completion)
    INSERT INTO public.booking_crew (
        booking_id,
        pilot_id,
        role,
        rank_at_acceptance,
        payout_amount
    ) VALUES (
        p_booking_id,
        p_pilot_id,
        'crew', -- All S&R participants are crew (no lead concept)
        COALESCE(v_pilot_stats.tier, 0),
        0 -- Payout calculated at completion based on hours
    );
    
    -- Update booking status to accepted if this is the first pilot
    IF v_booking.status = 'available' THEN
        UPDATE public.bookings
        SET status = 'accepted'
        WHERE id = p_booking_id;
    END IF;
    
    RETURN json_build_object(
        'success', true,
        'message', 'Successfully joined the Search & Rescue mission'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_search_rescue_payout(double precision, numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION calculate_search_rescue_total(uuid, double precision) TO authenticated;
GRANT EXECUTE ON FUNCTION join_search_rescue_booking(uuid, uuid) TO authenticated;

