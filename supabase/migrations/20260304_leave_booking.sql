-- Add RPCs for pilots to leave/withdraw from bookings
-- 1. leave_automotive_booking - for automotive crew bookings
-- 2. withdraw_from_booking - for non-crew (single pilot) bookings
-- (S&R already has leave_search_rescue_booking from 20260303)

-- A. leave_automotive_booking RPC
CREATE OR REPLACE FUNCTION public.leave_automotive_booking(
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
    v_was_lead BOOLEAN;
    v_new_lead RECORD;
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

    -- Only automotive bookings
    IF v_booking.specialization != 'automotive' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Not an automotive booking');
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
        RETURN jsonb_build_object('success', false, 'error', 'You are not a member of this crew');
    END IF;

    -- Check if leaving pilot is the lead
    SELECT (role = 'lead')
      INTO v_was_lead
      FROM booking_crew
     WHERE booking_id = p_booking_id
       AND pilot_id = p_pilot_id;

    -- Remove the crew member
    DELETE FROM booking_crew
     WHERE booking_id = p_booking_id
       AND pilot_id = p_pilot_id;

    -- If leaving pilot was the lead, reassign lead to next highest-ranked member
    IF v_was_lead THEN
        SELECT *
          INTO v_new_lead
          FROM booking_crew
         WHERE booking_id = p_booking_id
         ORDER BY rank_at_acceptance DESC, joined_at ASC
         LIMIT 1;

        IF FOUND THEN
            UPDATE booking_crew
               SET role = 'lead'
             WHERE id = v_new_lead.id;
        END IF;
    END IF;

    -- Count remaining crew
    SELECT COUNT(*)
      INTO v_crew_count
      FROM booking_crew
     WHERE booking_id = p_booking_id;

    -- If crew drops below 4, revert status to available and clear pilot_id
    IF v_crew_count < 4 AND v_booking.status = 'accepted' THEN
        UPDATE bookings
           SET status = 'available',
               pilot_id = NULL
         WHERE id = p_booking_id;

        RETURN jsonb_build_object(
            'success', true,
            'message', format('Left crew — %s of 4 pilots remaining, booking reopened', v_crew_count)
        );
    ELSE
        -- Clear pilot_id if leaving pilot was the lead
        IF v_was_lead THEN
            UPDATE bookings
               SET pilot_id = NULL
             WHERE id = p_booking_id;
        END IF;

        RETURN jsonb_build_object(
            'success', true,
            'message', format('Left crew — %s of 4 pilots remaining', v_crew_count)
        );
    END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.leave_automotive_booking(UUID, UUID) TO authenticated;

-- B. withdraw_from_booking RPC (non-crew single-pilot bookings)
CREATE OR REPLACE FUNCTION public.withdraw_from_booking(
    p_booking_id UUID,
    p_pilot_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_booking RECORD;
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

    -- Only non-crew bookings
    IF v_booking.specialization IN ('automotive', 'search_rescue') THEN
        RETURN jsonb_build_object('success', false, 'error', 'Use the crew-specific leave function for crew bookings');
    END IF;

    -- Only allow withdrawing from accepted bookings
    IF v_booking.status != 'accepted' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Cannot withdraw from a booking with status: ' || v_booking.status);
    END IF;

    -- Verify this pilot is assigned (IS DISTINCT FROM handles NULL safely)
    IF v_booking.pilot_id IS DISTINCT FROM p_pilot_id THEN
        RETURN jsonb_build_object('success', false, 'error', 'You are not assigned to this booking');
    END IF;

    -- Clear pilot and revert to available
    UPDATE bookings
       SET pilot_id = NULL,
           status = 'available'
     WHERE id = p_booking_id;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Withdrawn from booking — booking is now available again'
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.withdraw_from_booking(UUID, UUID) TO authenticated;
