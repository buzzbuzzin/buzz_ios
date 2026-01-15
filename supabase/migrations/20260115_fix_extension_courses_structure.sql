-- Migration: Fix Extension Courses Structure
-- Consolidate Camera/Payload Operator and Drone Business into one Extension Courses course
-- with two units instead of two separate courses

-- ============================================================
-- Step 1: Delete the incorrectly created separate courses
-- (Only if they were created by the previous migration)
-- ============================================================

-- Delete Camera/Payload Operator course sections
DELETE FROM public.course_sections
WHERE course_id = 'e5f6a7b8-c9d0-1234-efab-567890123456'
  AND id = 'a0000004-0000-0000-0000-000000000004';

-- Delete Drone Business course sections
DELETE FROM public.course_sections
WHERE course_id = 'f6a7b8c9-d0e1-2345-fabc-678901234567'
  AND id = 'a0000005-0000-0000-0000-000000000005';

-- Delete the separate courses (if they exist)
DELETE FROM public.training_courses
WHERE id IN (
    'e5f6a7b8-c9d0-1234-efab-567890123456',
    'f6a7b8c9-d0e1-2345-fabc-678901234567'
);

-- ============================================================
-- Step 2: Create the correct Extension Courses course
-- ============================================================

INSERT INTO public.training_courses (
    id,
    title,
    description,
    duration,
    level,
    category,
    instructor,
    instructor_picture_url,
    rating,
    students_count,
    provider,
    requires_uas_ground_school
)
VALUES (
    'e5f6a7b8-c9d0-1234-efab-567890123456',
    'Extension Courses',
    'Advanced training courses including Camera/Payload Operator and Drone Business. Expand your skills beyond basic pilot training with specialized knowledge.',
    '14 hours',
    'Intermediate',
    'Flight Operations',
    'Buzz',
    NULL,
    5.0,
    0,
    'Buzz',
    true  -- Requires UAS Pilot Ground School Test to unlock
)
ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    description = EXCLUDED.description,
    duration = EXCLUDED.duration,
    category = EXCLUDED.category,
    requires_uas_ground_school = EXCLUDED.requires_uas_ground_school,
    updated_at = timezone('utc'::text, now());

-- ============================================================
-- Step 3: Create the Extension Courses section
-- ============================================================

INSERT INTO public.course_sections (
    id,
    course_id,
    name,
    display_order,
    description,
    section_type,
    requires_subscription,
    requires_test_passed,
    is_active
)
VALUES (
    'a0000004-0000-0000-0000-000000000004',
    'e5f6a7b8-c9d0-1234-efab-567890123456',
    'EXTENSION COURSES',
    1,
    'Advanced training units including Camera/Payload Operator and Drone Business',
    'units',
    true,  -- Requires subscription
    false,
    true
)
ON CONFLICT (id) DO UPDATE SET
    course_id = EXCLUDED.course_id,
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    section_type = EXCLUDED.section_type,
    requires_subscription = EXCLUDED.requires_subscription,
    is_active = EXCLUDED.is_active,
    updated_at = timezone('utc'::text, now());

-- ============================================================
-- Step 4: Move Unit 5 and Unit 6 to the Extension Courses
-- ============================================================

-- Update Unit 5 (Camera/Payload Operator) to point to new Extension Courses
UPDATE public.course_units
SET course_id = 'e5f6a7b8-c9d0-1234-efab-567890123456',
    section_id = 'a0000004-0000-0000-0000-000000000004',
    updated_at = timezone('utc'::text, now())
WHERE id = '00000000-0000-0000-0000-000000000005'
  AND (
    course_id = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890' OR
    course_id = 'e5f6a7b8-c9d0-1234-efab-567890123456'
  );

-- Update Unit 6 (Drone Business) to point to new Extension Courses
UPDATE public.course_units
SET course_id = 'e5f6a7b8-c9d0-1234-efab-567890123456',
    section_id = 'a0000004-0000-0000-0000-000000000004',
    updated_at = timezone('utc'::text, now())
WHERE id = '00000000-0000-0000-0000-000000000006'
  AND (
    course_id = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890' OR
    course_id = 'f6a7b8c9-d0e1-2345-fabc-678901234567'
  );

-- ============================================================
-- Summary:
-- ============================================================
-- Fixed Extension Courses structure:
-- - Deleted separate Camera/Payload Operator and Drone Business courses
-- - Created single Extension Courses course (e5f6a7b8-c9d0-1234-efab-567890123456)
-- - Created Extension Courses section (a0000004-0000-0000-0000-000000000004)
-- - Moved Unit 5 and Unit 6 to the new Extension Courses course
--
-- Result: Extension Courses now shows as ONE course with 2 units inside

-- ============================================================
-- Verification query (can be run manually):
-- ============================================================
-- SELECT id, title, requires_uas_ground_school FROM public.training_courses WHERE id = 'e5f6a7b8-c9d0-1234-efab-567890123456';
-- SELECT id, title, course_id, section_id FROM public.course_units WHERE id IN ('00000000-0000-0000-0000-000000000005', '00000000-0000-0000-0000-000000000006');
