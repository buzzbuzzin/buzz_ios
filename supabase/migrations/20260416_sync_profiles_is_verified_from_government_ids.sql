-- Keep profiles.is_verified as a materialized mirror of
-- government_ids.verification_status = 'verified'. The latter is the
-- authoritative source (written only by stripe-webhook via service role
-- per migration 20260416_lock_verification_status_to_service_role.sql);
-- this trigger makes the portal and any other consumer that still reads
-- profiles.is_verified see the same answer without a code change.

-- 1. Trigger function
--
-- SECURITY DEFINER so the trigger runs with the function owner's privileges
-- and can UPDATE profiles regardless of the calling role (authenticated users
-- don't have direct UPDATE privileges on profiles rows they don't own — but
-- the sync has to work for the webhook flipping someone else's row).
--
-- search_path pinned for safety against schema-injection attacks, since
-- SECURITY DEFINER functions can be abused if a mutable search_path shadows
-- expected objects.

CREATE OR REPLACE FUNCTION public.sync_profile_is_verified()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    -- Government ID record removed — user is no longer verified.
    UPDATE public.profiles
      SET is_verified = false
      WHERE id = OLD.user_id;
    RETURN OLD;
  END IF;

  UPDATE public.profiles
    SET is_verified = (NEW.verification_status = 'verified')
    WHERE id = NEW.user_id;
  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.sync_profile_is_verified() IS
  'Mirrors government_ids.verification_status onto profiles.is_verified so the legacy column stays consistent with the authoritative source. The authoritative writer of verification_status is stripe-webhook (service role).';

-- 2. Trigger
--
-- AFTER INSERT OR UPDATE OF verification_status OR DELETE: fires only when
-- the column we care about actually changes, saving trigger overhead on
-- unrelated updates like stripe_session_id refreshes.

DROP TRIGGER IF EXISTS trg_sync_profile_is_verified ON public.government_ids;

CREATE TRIGGER trg_sync_profile_is_verified
  AFTER INSERT OR UPDATE OF verification_status OR DELETE
  ON public.government_ids
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_profile_is_verified();

-- 3. One-time backfill
--
-- Bring profiles.is_verified in line with whatever government_ids currently
-- says, without disturbing rows that already agree.

UPDATE public.profiles AS p
SET is_verified = (
  SELECT verification_status = 'verified'
  FROM public.government_ids AS g
  WHERE g.user_id = p.id
)
WHERE EXISTS (
  SELECT 1 FROM public.government_ids g WHERE g.user_id = p.id
)
AND p.is_verified IS DISTINCT FROM (
  SELECT verification_status = 'verified'
  FROM public.government_ids g
  WHERE g.user_id = p.id
);

-- Profiles with no government_ids row stay as-is (legacy is_verified is
-- preserved for the 2 oldest manually-verified accounts). The authoritative
-- check in the iOS / portal code already treats missing government_ids as
-- "not verified" except for that legacy fallback, which we're intentionally
-- leaving untouched.
