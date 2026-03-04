-- Fix S&R booking status transitions: status should reflect actual crew capacity
-- 1. Replace join_search_rescue_booking to enforce crew limits and correct status transitions
-- 2. Create leave_search_rescue_booking RPC
-- 3. Data fix: revert prematurely accepted S&R bookings

-- Drop existing function first (return type changed from JSON to JSONB)
DROP FUNCTION IF EXISTS public.join_search_rescue_booking(UUID, UUID);

-- A. Recreate join_search_rescue_booking with correct behavior
CREATE FUNCTION public.join_search_rescue_booking(
    p_booking_id UUID,
    p_pilot_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_booking RECORD;
    v_crew_count INT;
    v_pilot_rank INT;
BEGIN
    -- Lock the booking row to prevent race conditions
    SELECT *
      INTO v_booking
      FROM bookings
     WHERE id = p_booking_id
       FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Booking not found');
    END IF;

    -- Only S&R bookings
    IF v_booking.specialization != 'search_rescue' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Not a Search & Rescue booking');
    END IF;

    -- Only allow joining available bookings (not full/accepted ones)
    IF v_booking.status != 'available' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Booking is not available for joining');
    END IF;

    -- Check if pilot already in crew
    IF EXISTS (
        SELECT 1 FROM booking_crew
         WHERE booking_id = p_booking_id
           AND pilot_id = p_pilot_id
    ) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Already joined this mission');
    END IF;

    -- Count current crew
    SELECT COUNT(*)
      INTO v_crew_count
      FROM booking_crew
     WHERE booking_id = p_booking_id;

    -- Enforce crew limit
    IF v_crew_count >= v_booking.number_of_pilots THEN
        RETURN jsonb_build_object('success', false, 'error', 'Mission crew is already full');
    END IF;

    -- Get pilot rank (1-4 range, default 1 = Ensign)
    SELECT COALESCE(tier, 1) INTO v_pilot_rank
    FROM pilot_stats
    WHERE pilot_id = p_pilot_id;

    IF NOT FOUND THEN
        v_pilot_rank := 1;
    END IF;

    -- Clamp to valid range
    v_pilot_rank := GREATEST(1, LEAST(4, v_pilot_rank));

    -- Insert crew member
    INSERT INTO booking_crew (booking_id, pilot_id, role, rank_at_acceptance, payout_amount, joined_at)
    VALUES (p_booking_id, p_pilot_id, 'crew', v_pilot_rank, 0, NOW());

    -- Update crew count
    v_crew_count := v_crew_count + 1;

    -- Only transition to accepted when crew is full
    IF v_crew_count >= v_booking.number_of_pilots THEN
        UPDATE bookings
           SET status = 'accepted'
         WHERE id = p_booking_id;

        RETURN jsonb_build_object(
            'success', true,
            'message', 'Joined mission — crew is now full'
        );
    ELSE
        RETURN jsonb_build_object(
            'success', true,
            'message', format('Joined mission — %s of %s pilots', v_crew_count, v_booking.number_of_pilots)
        );
    END IF;
END;
$$;

-- Grant execute on recreated function
GRANT EXECUTE ON FUNCTION public.join_search_rescue_booking(UUID, UUID) TO authenticated;

-- B. Create leave_search_rescue_booking RPC
CREATE OR REPLACE FUNCTION public.leave_search_rescue_booking(
    p_booking_id UUID,
    p_pilot_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_booking RECORD;
    v_crew_count INT;
BEGIN
    -- Lock the booking row
    SELECT *
      INTO v_booking
      FROM bookings
     WHERE id = p_booking_id
       FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Booking not found');
    END IF;

    -- Only S&R bookings
    IF v_booking.specialization != 'search_rescue' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Not a Search & Rescue booking');
    END IF;

    -- Only allow leaving available or accepted bookings
    IF v_booking.status NOT IN ('available', 'accepted') THEN
        RETURN jsonb_build_object('success', false, 'error', 'Cannot leave a booking with status: ' || v_booking.status);
    END IF;

    -- Verify pilot is in the crew
    IF NOT EXISTS (
        SELECT 1 FROM booking_crew
         WHERE booking_id = p_booking_id
           AND pilot_id = p_pilot_id
    ) THEN
        RETURN jsonb_build_object('success', false, 'error', 'You are not a member of this mission crew');
    END IF;

    -- Remove the crew member
    DELETE FROM booking_crew
     WHERE booking_id = p_booking_id
       AND pilot_id = p_pilot_id;

    -- Count remaining crew
    SELECT COUNT(*)
      INTO v_crew_count
      FROM booking_crew
     WHERE booking_id = p_booking_id;

    -- If crew drops below required, revert status to available
    IF v_crew_count < v_booking.number_of_pilots AND v_booking.status = 'accepted' THEN
        UPDATE bookings
           SET status = 'available'
         WHERE id = p_booking_id;

        RETURN jsonb_build_object(
            'success', true,
            'message', format('Left mission — crew now %s of %s, booking reopened', v_crew_count, v_booking.number_of_pilots)
        );
    ELSE
        RETURN jsonb_build_object(
            'success', true,
            'message', format('Left mission — crew now %s of %s', v_crew_count, v_booking.number_of_pilots)
        );
    END IF;
END;
$$;

-- Grant execute to authenticated users
GRANT EXECUTE ON FUNCTION public.leave_search_rescue_booking(UUID, UUID) TO authenticated;

-- C. Data fix: revert S&R bookings prematurely set to accepted
UPDATE bookings
   SET status = 'available'
 WHERE specialization = 'search_rescue'
   AND status = 'accepted'
   AND number_of_pilots > (
       SELECT COUNT(*)
         FROM booking_crew
        WHERE booking_crew.booking_id = bookings.id
   );
