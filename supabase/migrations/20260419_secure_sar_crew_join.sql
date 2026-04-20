-- Gate `join_search_rescue_booking` on the authenticated caller and on
-- identity verification.
--
-- Prior state (20260303_fix_sar_booking_status.sql):
--   The RPC is SECURITY DEFINER, accepts p_pilot_id from the caller, and
--   performs no auth.uid() check and no verification check. Any
--   authenticated user could forge a crew join as another pilot, and the
--   verification requirement enforced at bookings-RLS and at the
--   automotive crew edge function was bypassed entirely for S&R missions.
--
-- Fix:
--   1. Require auth.uid() to be non-null (authenticated session).
--   2. Require p_pilot_id to match auth.uid() — no proxy joins.
--   3. Require the caller to be verified (mirror bookings-create / accept
--      gate from 20260416_require_verification_for_bookings.sql).
--
-- SET search_path = public: SECURITY DEFINER hardening against
-- search_path hijack in case the caller manipulates their session
-- search_path before calling.

DROP FUNCTION IF EXISTS public.join_search_rescue_booking(UUID, UUID);

CREATE FUNCTION public.join_search_rescue_booking(
    p_booking_id UUID,
    p_pilot_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_booking RECORD;
    v_crew_count INT;
    v_pilot_rank INT;
    v_caller UUID;
    v_verified BOOLEAN;
BEGIN
    -- 1. Authentication
    v_caller := auth.uid();
    IF v_caller IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Authentication required');
    END IF;

    -- 2. Supplied pilot_id must be the authenticated user
    IF p_pilot_id IS DISTINCT FROM v_caller THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Unauthorized: pilot_id does not match authenticated user'
        );
    END IF;

    -- 3. Identity verification gate (same bar as bookings RLS, and as the
    --    automotive crew-join edge function)
    SELECT EXISTS (
        SELECT 1
          FROM public.government_ids
         WHERE user_id = v_caller
           AND verification_status = 'verified'
    ) INTO v_verified;

    IF NOT v_verified THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Identity verification required. Please complete government-ID verification in your Account settings before joining crew missions.',
            'code', 'identity_not_verified'
        );
    END IF;

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

GRANT EXECUTE ON FUNCTION public.join_search_rescue_booking(UUID, UUID) TO authenticated;
