-- Migration: Add standalone courses for sections moved from UAS Pilot course
-- These courses will appear directly in the Academy course list
-- These courses require passing the UAS Pilot Ground School Test to unlock

-- ============================================================
-- Step 0: Add prerequisite column to training_courses table
-- This tracks whether a course requires the UAS Pilot Ground School Test
-- ============================================================

-- Add requires_uas_ground_school column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'training_courses' 
        AND column_name = 'requires_uas_ground_school'
    ) THEN
        ALTER TABLE public.training_courses 
        ADD COLUMN requires_uas_ground_school boolean DEFAULT false;
    END IF;
END $$;

-- ============================================================
-- Step 1: Add new categories to support the new courses
-- Note: We need to update the category constraint to include new categories
-- ============================================================

-- Update the category constraint to include CPR/First Aid and Basic Firefighter
-- (These may already exist from previous migrations)
ALTER TABLE public.training_courses 
DROP CONSTRAINT IF EXISTS training_courses_category_check;

ALTER TABLE public.training_courses 
ADD CONSTRAINT training_courses_category_check 
CHECK (category = ANY (ARRAY[
    'Safety & Regulations'::text, 
    'Flight Operations'::text, 
    'Aerial Photography'::text, 
    'Cinematography'::text, 
    'Inspections'::text, 
    'Mapping & Surveying'::text,
    'CPR/First Aid'::text,
    'Basic Firefighter'::text
]));

-- ============================================================
-- Step 2: Insert Flight Review as a standalone course
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
    'b2c3d4e5-f6a7-8901-bcde-f23456789012',
    'Flight Review',
    'In-person practical flight assessment conducted by a certified Flight Reviewer. Demonstrate your flying skills and safety knowledge to earn your Flight Review certification.',
    '2 hours',
    'Intermediate',
    'Flight Operations',
    'Buzz',
    NULL,
    5.0,
    0,
    'Buzz',
    true  -- Requires UAS Pilot Ground School Test to unlock
)
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- Step 3: Insert ROC-A Exam as a standalone course
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
    'c3d4e5f6-a7b8-9012-cdef-345678901234',
    'ROC-A Exam',
    'ROC-A radio communication competency certification. Learn proper radio communication protocols and demonstrate your competency to operate radio equipment.',
    '1 hour',
    'Beginner',
    'Safety & Regulations',
    'Buzz',
    NULL,
    5.0,
    0,
    'Buzz',
    true  -- Requires UAS Pilot Ground School Test to unlock
)
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- Step 4: Insert FAA 107 Recurrent Training as a standalone course
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
    'd4e5f6a7-b8c9-0123-defa-456789012345',
    'FAA 107 Recurrent Training',
    'Comprehensive course material to help you pass the 2-year recurrent training requirement. Stay current with FAA Part 107 regulations and maintain your remote pilot certificate.',
    '4 hours',
    'Intermediate',
    'Safety & Regulations',
    'Buzz',
    NULL,
    5.0,
    0,
    'Buzz',
    true  -- Requires UAS Pilot Ground School Test to unlock
)
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- Step 5: Insert Camera/Payload Operator course (Extension Unit 5)
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
    'Camera/Payload Operator',
    'Training for camera and payload operators, covering equipment handling, camera settings, gimbal operation, and payload management for professional drone operations.',
    '6 hours',
    'Intermediate',
    'Aerial Photography',
    'Buzz',
    NULL,
    5.0,
    0,
    'Buzz',
    true  -- Requires UAS Pilot Ground School Test to unlock
)
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- Step 6: Insert Drone Business course (Extension Unit 6)
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
    'f6a7b8c9-d0e1-2345-fabc-678901234567',
    'Drone Business',
    'Learn how to start and manage a successful drone business. Covers business planning, client acquisition, pricing strategies, insurance, and legal considerations.',
    '8 hours',
    'Beginner',
    'Flight Operations',
    'Buzz',
    NULL,
    5.0,
    0,
    'Buzz',
    true  -- Requires UAS Pilot Ground School Test to unlock
)
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- Step 7: Create course sections for the new courses
-- Each course needs at least one section to display content
-- ============================================================

-- Flight Review - Single section linking to Test Center
INSERT INTO public.course_sections (
    id,
    course_id,
    name,
    display_order,
    description,
    section_type,
    requires_subscription,
    requires_test_passed,
    is_active,
    exam_type
)
VALUES (
    'a0000001-0000-0000-0000-000000000001',
    'b2c3d4e5-f6a7-8901-bcde-f23456789012',
    'FLIGHT REVIEW EXAM',
    1,
    'Schedule your in-person practical flight assessment in the Test Center',
    'exam',
    false,
    false,
    true,
    'flight_review'
)
ON CONFLICT (id) DO NOTHING;

-- ROC-A Exam - Single section linking to Test Center
INSERT INTO public.course_sections (
    id,
    course_id,
    name,
    display_order,
    description,
    section_type,
    requires_subscription,
    requires_test_passed,
    is_active,
    exam_type
)
VALUES (
    'a0000002-0000-0000-0000-000000000002',
    'c3d4e5f6-a7b8-9012-cdef-345678901234',
    'ROC-A EXAM',
    1,
    'Schedule your ROC-A radio communication competency exam in the Test Center',
    'exam',
    false,
    false,
    true,
    'roc_a'
)
ON CONFLICT (id) DO NOTHING;

-- FAA 107 Recurrent Training - Main content section
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
    'a0000003-0000-0000-0000-000000000003',
    'd4e5f6a7-b8c9-0123-defa-456789012345',
    'RECURRENT TRAINING CONTENT',
    1,
    'FAA Part 107 recurrent training materials',
    'units',
    true,  -- Requires subscription
    false,
    true
)
ON CONFLICT (id) DO NOTHING;

-- Camera/Payload Operator - Main content section
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
    'CAMERA/PAYLOAD TRAINING',
    1,
    'Camera and payload operator training materials',
    'units',
    true,  -- Requires subscription
    false,
    true
)
ON CONFLICT (id) DO NOTHING;

-- Drone Business - Main content section
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
    'a0000005-0000-0000-0000-000000000005',
    'f6a7b8c9-d0e1-2345-fabc-678901234567',
    'DRONE BUSINESS TRAINING',
    1,
    'Drone business training materials',
    'units',
    true,  -- Requires subscription
    false,
    true
)
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- Step 8: Deactivate the moved sections from UAS Pilot course
-- These sections are now standalone courses, so hide them from UAS Pilot
-- ============================================================

-- Deactivate Flight Review section in UAS Pilot course
UPDATE public.course_sections
SET is_active = false,
    updated_at = timezone('utc'::text, now())
WHERE id = '00000007-0000-0000-0000-000000000007'
  AND course_id = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';

-- Deactivate Radio Operator section in UAS Pilot course
UPDATE public.course_sections
SET is_active = false,
    updated_at = timezone('utc'::text, now())
WHERE id = '00000008-0000-0000-0000-000000000008'
  AND course_id = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';

-- Deactivate Recurrent Training section in UAS Pilot course
UPDATE public.course_sections
SET is_active = false,
    updated_at = timezone('utc'::text, now())
WHERE id = '00000004-0000-0000-0000-000000000004'
  AND course_id = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';

-- Deactivate Extension Courses section in UAS Pilot course
UPDATE public.course_sections
SET is_active = false,
    updated_at = timezone('utc'::text, now())
WHERE id = '00000005-0000-0000-0000-000000000005'
  AND course_id = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';

-- ============================================================
-- Summary of new courses:
-- ============================================================
-- All new courses require passing UAS Pilot Ground School Test (requires_uas_ground_school = true)
--
-- 1. Flight Review (b2c3d4e5-f6a7-8901-bcde-f23456789012) - Links to Test Center
-- 2. ROC-A Exam (c3d4e5f6-a7b8-9012-cdef-345678901234) - Links to Test Center
-- 3. FAA 107 Recurrent Training (d4e5f6a7-b8c9-0123-defa-456789012345) - Subscription required
-- 4. Camera/Payload Operator (e5f6a7b8-c9d0-1234-efab-567890123456) - Subscription required
-- 5. Drone Business (f6a7b8c9-d0e1-2345-fabc-678901234567) - Subscription required
--
-- Deactivated sections in UAS Pilot course:
-- - Flight Review (00000007-0000-0000-0000-000000000007)
-- - Radio Operator (00000008-0000-0000-0000-000000000008)
-- - Recurrent Training (00000004-0000-0000-0000-000000000004)
-- - Extension Courses (00000005-0000-0000-0000-000000000005)

-- ============================================================
-- Verification query (can be run manually):
-- ============================================================
-- SELECT id, title, category, provider, requires_uas_ground_school FROM public.training_courses ORDER BY created_at DESC LIMIT 10;
-- SELECT id, name, is_active FROM public.course_sections WHERE course_id = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';
