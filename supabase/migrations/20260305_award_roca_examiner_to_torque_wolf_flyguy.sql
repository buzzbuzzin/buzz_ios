-- Migration: Award ROC-A Examiner badge to TORQUE, WOLF, and FLYGUY
-- Created: 2026-03-05

INSERT INTO public.badges (
  pilot_id, course_id, course_title, course_category,
  provider, badge_type, earned_at, expires_at, is_recurrent
)
SELECT
  p.id,
  NULL::uuid,
  'ROC-A Examiner',
  'Permits',
  'Buzz',
  'roc_a_examiner',
  NOW(),
  NULL::timestamptz,
  false
FROM public.profiles p
WHERE p.call_sign IN ('TORQUE', 'WOLF', 'FLYGUY')
  AND NOT EXISTS (
    SELECT 1 FROM public.badges b
    WHERE b.pilot_id = p.id
    AND b.badge_type = 'roc_a_examiner'
  );
