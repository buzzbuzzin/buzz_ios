-- Require identity verification before creating bookings (customers) or
-- accepting them (pilots).
--
-- Safe because government_ids.verification_status is now trustworthy after
-- 20260416_lock_verification_status_to_service_role.sql — only the
-- stripe-webhook (service role) can set it to 'verified'. Clients can't
-- self-serve past this gate by writing to the column directly.
--
-- UUID comparisons between auth.uid() (uuid) and user_id (uuid) are
-- byte-based and case-insensitive, so the 9 currently verified users will
-- continue to pass regardless of whether their JWTs arrive uppercase or
-- lowercase.
--
-- Service role calls (edge functions, stripe-webhook, job-scheduled cron)
-- bypass RLS entirely via BYPASSRLS, so the crew-join edge function and
-- webhook handlers are unaffected by this policy change.

-- ---------------------------------------------------------------------------
-- 1. is_verified(uuid) — canonical helper
-- ---------------------------------------------------------------------------
-- SECURITY INVOKER (default): the function runs with the caller's privileges,
-- so RLS on government_ids applies — an authenticated user can only read
-- their own row. That makes is_verified(auth.uid()) work for self-checks
-- (the intended use) while preventing a probe of other users' status.
--
-- STABLE: the result is stable within a single statement; marking it so lets
-- the planner cache the call when it appears in a per-row RLS check.

CREATE OR REPLACE FUNCTION public.is_verified(uid uuid)
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.government_ids
    WHERE user_id = uid
      AND verification_status = 'verified'
  );
$$;

COMMENT ON FUNCTION public.is_verified(uuid) IS
  'Returns true when the given user has a verified government_ids row. Called from RLS policies that gate sensitive actions like creating/accepting bookings.';

GRANT EXECUTE ON FUNCTION public.is_verified(uuid) TO authenticated, anon;

-- ---------------------------------------------------------------------------
-- 2. bookings: INSERT
-- ---------------------------------------------------------------------------
-- Customers must be verified to create a booking. The existing authorization
-- (auth.uid() = customer_id) is preserved; we just append the verification
-- requirement.

DROP POLICY IF EXISTS "Customers can create bookings" ON public.bookings;

CREATE POLICY "Customers can create bookings"
  ON public.bookings
  FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = customer_id
    AND public.is_verified(auth.uid())
  );

-- ---------------------------------------------------------------------------
-- 3. bookings: UPDATE (customer path)
-- ---------------------------------------------------------------------------
-- Customers updating their own bookings (cancellations, edits) must still be
-- verified. The existing policy had no WITH CHECK, which defaults to USING;
-- we now set WITH CHECK explicitly so the verification requirement is
-- enforced on the post-update row.

DROP POLICY IF EXISTS "Customers can update their own bookings" ON public.bookings;

CREATE POLICY "Customers can update their own bookings"
  ON public.bookings
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = customer_id)
  WITH CHECK (
    auth.uid() = customer_id
    AND public.is_verified(auth.uid())
  );

-- ---------------------------------------------------------------------------
-- 4. bookings: UPDATE (pilot path)
-- ---------------------------------------------------------------------------
-- Pilots can accept an available booking (pilot_id NULL -> self) or update
-- a booking they've already accepted. We require them to be verified whenever
-- the resulting row has pilot_id = auth.uid(); otherwise the original
-- authorization rule holds unchanged.
--
-- Using IS DISTINCT FROM so NULL pilot_id doesn't trip the check.

DROP POLICY IF EXISTS "Pilots can accept bookings" ON public.bookings;

CREATE POLICY "Pilots can accept bookings"
  ON public.bookings
  FOR UPDATE
  TO authenticated
  USING (
    status = 'available'
    OR auth.uid() = pilot_id
  )
  WITH CHECK (
    (status = 'available' OR auth.uid() = pilot_id)
    AND (pilot_id IS DISTINCT FROM auth.uid() OR public.is_verified(auth.uid()))
  );
