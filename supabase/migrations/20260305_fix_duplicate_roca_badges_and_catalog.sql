-- Migration: Fix duplicate ROC-A Examiner badges in catalog and re-award missing badges
-- Created: 2026-03-05
-- Description:
--   1. Remove duplicate roc_a_examiner entries from badges_catalog (keep one)
--   2. Add partial unique index on badges_catalog(badge_type) for non-course badges
--   3. Remove duplicate roc_a_examiner badges per pilot (keep earliest)
--   4. Re-award roc_a_examiner badge to pilots who uploaded ROC-A Examiner docs
--   5. Drop stale retroactive function with buggy license type mapping

-- Step 1: Remove duplicate roc_a_examiner entries from badges_catalog, keeping the first one
DELETE FROM public.badges_catalog
WHERE badge_type = 'roc_a_examiner'
  AND id NOT IN (
    SELECT id FROM public.badges_catalog
    WHERE badge_type = 'roc_a_examiner'
    ORDER BY id
    LIMIT 1
  );

-- Step 2: Remove duplicate flight_reviewer entries from badges_catalog if any exist
DELETE FROM public.badges_catalog
WHERE badge_type = 'flight_reviewer'
  AND id NOT IN (
    SELECT id FROM public.badges_catalog
    WHERE badge_type = 'flight_reviewer'
    ORDER BY id
    LIMIT 1
  );

-- Step 3: Add partial unique index on badges_catalog for non-course badge types
CREATE UNIQUE INDEX IF NOT EXISTS idx_badges_catalog_unique_non_course_badge_type
ON public.badges_catalog (badge_type)
WHERE badge_type != 'course';

-- Step 4: Remove duplicate badges per pilot (keep earliest earned)
DELETE FROM public.badges b1
WHERE b1.badge_type = 'roc_a_examiner'
  AND b1.id NOT IN (
    SELECT DISTINCT ON (pilot_id) id
    FROM public.badges
    WHERE badge_type = 'roc_a_examiner'
    ORDER BY pilot_id, earned_at ASC
  );

-- Step 5: Re-award roc_a_examiner badge to pilots who have uploaded an ROC-A Examiner doc
-- This covers pilots whose badges were accidentally deleted by the previous cleanup migration
INSERT INTO public.badges (
  pilot_id, course_id, course_title, course_category,
  provider, badge_type, earned_at, expires_at, is_recurrent
)
SELECT DISTINCT
  pl.pilot_id,
  NULL::uuid,
  'ROC-A Examiner',
  'Permits',
  'Buzz',
  'roc_a_examiner',
  NOW(),
  NULL::timestamptz,
  false
FROM public.pilot_licenses pl
WHERE pl.license_type = 'ROC-A Examiner (CAN)'
  AND NOT EXISTS (
    SELECT 1 FROM public.badges b
    WHERE b.pilot_id = pl.pilot_id
    AND b.badge_type = 'roc_a_examiner'
  );

-- Step 6: Drop the old retroactive function with the buggy license type mapping
-- ('ROC-A (CAN)' was incorrectly mapped to roc_a_examiner instead of 'ROC-A Examiner (CAN)')
DROP FUNCTION IF EXISTS public.award_permit_badges_for_existing_licenses();
