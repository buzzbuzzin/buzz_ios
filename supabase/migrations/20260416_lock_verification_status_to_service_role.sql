-- Lock government_ids.verification_status behind the service role.
--
-- Motivation: the existing permissive UPDATE policy (USING auth.uid()=user_id,
-- no WITH CHECK and no column-level restriction) lets any authenticated user
-- write their own verification_status to 'verified' with a single PostgREST
-- call. The same hole turns the referral-credit trigger
-- (trigger_credit_referrer_on_verification) into a self-serve payout vector.
--
-- After this migration:
--   * The iOS client can still INSERT / UPDATE / SELECT / DELETE its own row.
--   * Any INSERT or UPDATE that sets verification_status to anything other
--     than 'pending' (insert) or changes it (update) is rejected, UNLESS the
--     caller is the service role (stripe-webhook) or a direct DB session
--     (auth.role() IS NULL — migrations, psql, triggers).
--   * The stripe-webhook edge function is now the sole authoritative writer
--     of 'verified' / 'rejected'. See supabase/functions/stripe-webhook.

-- Replace the UPDATE policy so it at least has a WITH CHECK clause. The trigger
-- below does the heavy lifting; the policy tweak is cosmetic tightening.
DROP POLICY IF EXISTS "Users can update their own government IDs"
  ON public.government_ids;

CREATE POLICY "Users can update their own government IDs"
  ON public.government_ids
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Trigger function: enforce that authenticated clients cannot set or change
-- verification_status. Service role and direct-DB callers pass through.
CREATE OR REPLACE FUNCTION public.enforce_verification_status_server_only()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  caller_role text;
BEGIN
  -- auth.role() returns the JWT role claim under PostgREST
  -- ('authenticated' / 'anon' / 'service_role'). It returns NULL when invoked
  -- outside PostgREST (direct DB access, migrations) — we trust those paths.
  caller_role := auth.role();

  IF caller_role IS NULL OR caller_role = 'service_role' THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'INSERT' THEN
    IF NEW.verification_status IS DISTINCT FROM 'pending' THEN
      RAISE EXCEPTION
        'verification_status must be ''pending'' on client-initiated insert (got: %)',
        NEW.verification_status
        USING ERRCODE = '42501';
    END IF;
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' THEN
    IF NEW.verification_status IS DISTINCT FROM OLD.verification_status THEN
      RAISE EXCEPTION
        'verification_status can only be changed by the service role'
        USING ERRCODE = '42501';
    END IF;
    RETURN NEW;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_verification_status_server_only
  ON public.government_ids;

CREATE TRIGGER trg_enforce_verification_status_server_only
  BEFORE INSERT OR UPDATE ON public.government_ids
  FOR EACH ROW
  EXECUTE FUNCTION public.enforce_verification_status_server_only();

COMMENT ON FUNCTION public.enforce_verification_status_server_only() IS
  'Rejects non-service-role writes that would set or change government_ids.verification_status. The stripe-webhook edge function (service role) is the only code path allowed to transition status to verified or rejected.';
