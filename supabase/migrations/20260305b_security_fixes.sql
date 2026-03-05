-- ============================================================
-- Migration: Security fixes for Test Center
-- Date: 2026-03-05
-- Fixes: C2, C3, C9, I1, I2
-- ============================================================

-- ============================================================
-- C2: Revoke approve/reject_test_result from authenticated role
-- These SECURITY DEFINER functions let any authenticated user
-- approve/reject any test result. Only service_role should call them.
-- ============================================================

REVOKE EXECUTE ON FUNCTION public.approve_test_result FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.reject_test_result FROM authenticated;

-- ============================================================
-- C3: Restrict RLS UPDATE policy to prevent status escalation
-- Previously, pilots could update ANY column including status='completed'
-- Now: pilots can cancel or reschedule, but never mark as completed
-- ============================================================

DROP POLICY IF EXISTS "Pilots can update own pending or confirmed exam appointments" ON public.exam_appointments;

CREATE POLICY "Pilots can update own pending or confirmed exam appointments"
  ON public.exam_appointments
  FOR UPDATE
  USING (
    auth.uid() = pilot_id
    AND status IN ('pending', 'confirmed')
  )
  WITH CHECK (
    auth.uid() = pilot_id
    AND status IN ('pending', 'confirmed', 'cancelled')
  );

-- Additional trigger to prevent pilots from modifying payment fields
CREATE OR REPLACE FUNCTION public.protect_exam_payment_fields()
RETURNS TRIGGER AS $$
BEGIN
  -- Allow service_role to modify anything
  IF current_setting('role', true) = 'service_role' THEN
    RETURN NEW;
  END IF;

  -- Prevent modification of payment-related fields
  IF OLD.stripe_payment_intent_id IS DISTINCT FROM NEW.stripe_payment_intent_id
     OR OLD.stripe_charge_id IS DISTINCT FROM NEW.stripe_charge_id
     OR OLD.payment_amount IS DISTINCT FROM NEW.payment_amount
     OR OLD.pilot_id IS DISTINCT FROM NEW.pilot_id
     OR OLD.exam_type IS DISTINCT FROM NEW.exam_type THEN
    RAISE EXCEPTION 'Cannot modify protected fields (payment, pilot_id, exam_type)';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_protect_exam_payment_fields ON public.exam_appointments;
CREATE TRIGGER trigger_protect_exam_payment_fields
  BEFORE UPDATE ON public.exam_appointments
  FOR EACH ROW
  EXECUTE FUNCTION public.protect_exam_payment_fields();

-- ============================================================
-- C9: Protect start_url from being read by students
-- The start_url gives Zoom host privileges - only examiners should see it
-- ============================================================

REVOKE SELECT (start_url) ON public.exam_appointments FROM authenticated;

-- ============================================================
-- I1: Enforce 24-hour reschedule rule at the database level
-- Prevents updates to scheduled_date within 24 hours of exam
-- ============================================================

CREATE OR REPLACE FUNCTION public.prevent_last_minute_reschedule()
RETURNS TRIGGER AS $$
BEGIN
  -- Only check if scheduled_date is being changed (reschedule)
  IF OLD.scheduled_date IS DISTINCT FROM NEW.scheduled_date THEN
    -- Allow service_role to bypass this check (for admin operations)
    IF current_setting('role', true) = 'service_role' THEN
      RETURN NEW;
    END IF;
    -- Block reschedule within 24 hours of the original exam time
    IF OLD.scheduled_date - NOW() < INTERVAL '24 hours' THEN
      RAISE EXCEPTION 'Cannot reschedule within 24 hours of the exam';
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_prevent_last_minute_reschedule ON public.exam_appointments;
CREATE TRIGGER trigger_prevent_last_minute_reschedule
  BEFORE UPDATE ON public.exam_appointments
  FOR EACH ROW
  EXECUTE FUNCTION public.prevent_last_minute_reschedule();

-- ============================================================
-- I2: Prevent double-booking (same pilot + exam type)
-- Only one active appointment per pilot per exam type
-- ============================================================

CREATE UNIQUE INDEX IF NOT EXISTS idx_exam_appointments_unique_active
  ON public.exam_appointments (pilot_id, exam_type)
  WHERE status IN ('pending', 'confirmed');

-- ============================================================
-- I3: Update exam_type CHECK to include ground_school_test
-- The Swift model has 3 enum cases but DB only allowed 2
-- ============================================================

ALTER TABLE public.exam_appointments
  DROP CONSTRAINT IF EXISTS exam_appointments_exam_type_check;

-- Use a name that won't conflict
DO $$
BEGIN
  -- Try to drop the unnamed check constraint on exam_type
  -- PostgreSQL auto-names it, so we need to find it
  EXECUTE (
    SELECT 'ALTER TABLE public.exam_appointments DROP CONSTRAINT ' || conname
    FROM pg_constraint
    WHERE conrelid = 'public.exam_appointments'::regclass
      AND contype = 'c'
      AND pg_get_constraintdef(oid) LIKE '%exam_type%'
      AND conname != 'exam_appointments_flight_review_in_person'
    LIMIT 1
  );
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'No exam_type check constraint found to drop: %', SQLERRM;
END $$;

ALTER TABLE public.exam_appointments
  ADD CONSTRAINT exam_appointments_exam_type_check
  CHECK (exam_type IN ('flight_review', 'roc_a', 'ground_school_test'));

-- Update the flight_review in-person constraint to also handle ground_school_test
ALTER TABLE public.exam_appointments
  DROP CONSTRAINT IF EXISTS exam_appointments_flight_review_in_person;

ALTER TABLE public.exam_appointments
  ADD CONSTRAINT exam_appointments_flight_review_in_person
  CHECK (
    (exam_type = 'flight_review' AND location_type = 'in_person') OR
    (exam_type = 'roc_a') OR
    (exam_type = 'ground_school_test')
  );
