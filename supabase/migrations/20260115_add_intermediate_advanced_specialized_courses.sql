-- Migration: Add Intermediate, Advanced, and Specialized Courses
-- Description: Create new courses for Intermediate, Advanced, and Specialized categories
-- Created: 2026-01-15

-- ============================================================
-- INTERMEDIATE COURSES (2 courses)
-- ============================================================

-- 1. Intermediate Drone Pilot
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
    'e7f8a9b0-c1d2-3456-efab-678901234567',
    'Intermediate Drone Pilot',
    'Advance your piloting skills with complex maneuvers, precision flying, and advanced flight planning. Master challenging scenarios and elevate your drone operation capabilities.',
    '15 hours',
    'Intermediate',
    'Intermediate',
    'Buzz',
    NULL,
    5.0,
    0,
    'Buzz',
    true
)
ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    description = EXCLUDED.description,
    duration = EXCLUDED.duration,
    level = EXCLUDED.level,
    category = EXCLUDED.category,
    requires_uas_ground_school = EXCLUDED.requires_uas_ground_school,
    updated_at = NOW();

-- 2. Intermediate Camera/Payload Operator
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
    'f8a9b0c1-d2e3-4567-fabc-789012345678',
    'Intermediate Camera/Payload Operator',
    'Enhance your camera operation skills with advanced techniques for professional aerial content creation. Learn lighting, composition, and advanced payload management.',
    '12 hours',
    'Intermediate',
    'Intermediate',
    'Buzz',
    NULL,
    5.0,
    0,
    'Buzz',
    true
)
ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    description = EXCLUDED.description,
    duration = EXCLUDED.duration,
    level = EXCLUDED.level,
    category = EXCLUDED.category,
    requires_uas_ground_school = EXCLUDED.requires_uas_ground_school,
    updated_at = NOW();

-- ============================================================
-- ADVANCED COURSES (2 courses)
-- ============================================================

-- 1. Advanced Drone Pilot
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
    'a9b0c1d2-e3f4-5678-abcd-890123456789',
    'Advanced Drone Pilot',
    'Master expert-level drone operations including autonomous flight, complex mission planning, night operations, and emergency procedures. Become a professional drone pilot.',
    '20 hours',
    'Advanced',
    'Advanced',
    'Buzz',
    NULL,
    5.0,
    0,
    'Buzz',
    true
)
ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    description = EXCLUDED.description,
    duration = EXCLUDED.duration,
    level = EXCLUDED.level,
    category = EXCLUDED.category,
    requires_uas_ground_school = EXCLUDED.requires_uas_ground_school,
    updated_at = NOW();

-- 2. Advanced Camera/Payload Operator
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
    'b0c1d2e3-f4a5-6789-bcde-901234567890',
    'Advanced Camera/Payload Operator',
    'Master professional cinematography and specialized payload operations. Learn advanced editing workflows, color grading, and integration with professional production pipelines.',
    '18 hours',
    'Advanced',
    'Advanced',
    'Buzz',
    NULL,
    5.0,
    0,
    'Buzz',
    true
)
ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    description = EXCLUDED.description,
    duration = EXCLUDED.duration,
    level = EXCLUDED.level,
    category = EXCLUDED.category,
    requires_uas_ground_school = EXCLUDED.requires_uas_ground_school,
    updated_at = NOW();

-- ============================================================
-- SPECIALIZED COURSES (4 courses)
-- ============================================================

-- 1. Specialized Search & Rescue with Thermography
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
    'c1d2e3f4-a5b6-7890-cdef-012345678901',
    'Specialized Search & Rescue with Thermography',
    'Expert-level search and rescue operations utilizing thermal imaging technology. Learn advanced thermography interpretation, night missions, and life-saving techniques with drones.',
    '16 hours',
    'Advanced',
    'Specialized',
    'Buzz',
    NULL,
    5.0,
    0,
    'Buzz',
    true
)
ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    description = EXCLUDED.description,
    duration = EXCLUDED.duration,
    level = EXCLUDED.level,
    category = EXCLUDED.category,
    requires_uas_ground_school = EXCLUDED.requires_uas_ground_school,
    updated_at = NOW();

-- 2. Specialized Post Production
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
    'd2e3f4a5-b6c7-8901-defa-123456789012',
    'Specialized Post Production',
    'Master professional post-production workflows for aerial footage. Learn advanced editing, color grading, VFX integration, and delivery for broadcast and cinema standards.',
    '14 hours',
    'Advanced',
    'Specialized',
    'Buzz',
    NULL,
    5.0,
    0,
    'Buzz',
    true
)
ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    description = EXCLUDED.description,
    duration = EXCLUDED.duration,
    level = EXCLUDED.level,
    category = EXCLUDED.category,
    requires_uas_ground_school = EXCLUDED.requires_uas_ground_school,
    updated_at = NOW();

-- 3. Drone Repair Technician/Engineer
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
    'e3f4a5b6-c7d8-9012-efab-234567890123',
    'Drone Repair Technician/Engineer',
    'Comprehensive training in drone maintenance, repair, and troubleshooting. Learn electronics, propulsion systems, flight controllers, and become a certified drone technician.',
    '25 hours',
    'Advanced',
    'Specialized',
    'Buzz',
    NULL,
    5.0,
    0,
    'Buzz',
    true
)
ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    description = EXCLUDED.description,
    duration = EXCLUDED.duration,
    level = EXCLUDED.level,
    category = EXCLUDED.category,
    requires_uas_ground_school = EXCLUDED.requires_uas_ground_school,
    updated_at = NOW();

-- 4. Public Safety Pilot
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
    'f4a5b6c7-d8e9-0123-fabc-345678901234',
    'Public Safety Pilot',
    'Specialized training for law enforcement, fire, and emergency services drone operations. Learn incident command integration, legal considerations, and public safety protocols.',
    '20 hours',
    'Advanced',
    'Specialized',
    'Buzz',
    NULL,
    5.0,
    0,
    'Buzz',
    true
)
ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    description = EXCLUDED.description,
    duration = EXCLUDED.duration,
    level = EXCLUDED.level,
    category = EXCLUDED.category,
    requires_uas_ground_school = EXCLUDED.requires_uas_ground_school,
    updated_at = NOW();

-- ============================================================
-- Create course sections for each new course
-- ============================================================

-- Intermediate Drone Pilot section
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
    'a0000016-0000-0000-0000-000000000016',
    'e7f8a9b0-c1d2-3456-efab-678901234567',
    'INTERMEDIATE DRONE PILOT',
    1,
    'Advanced piloting techniques and maneuvers',
    'units',
    true,
    false,
    true
)
ON CONFLICT (id) DO UPDATE SET
    course_id = EXCLUDED.course_id,
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    is_active = EXCLUDED.is_active,
    updated_at = NOW();

-- Intermediate Camera/Payload Operator section
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
    'a0000017-0000-0000-0000-000000000017',
    'f8a9b0c1-d2e3-4567-fabc-789012345678',
    'INTERMEDIATE CAMERA/PAYLOAD OPERATOR',
    1,
    'Advanced camera operation and content creation',
    'units',
    true,
    false,
    true
)
ON CONFLICT (id) DO UPDATE SET
    course_id = EXCLUDED.course_id,
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    is_active = EXCLUDED.is_active,
    updated_at = NOW();

-- Advanced Drone Pilot section
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
    'a0000018-0000-0000-0000-000000000018',
    'a9b0c1d2-e3f4-5678-abcd-890123456789',
    'ADVANCED DRONE PILOT',
    1,
    'Expert-level drone operations and mission planning',
    'units',
    true,
    false,
    true
)
ON CONFLICT (id) DO UPDATE SET
    course_id = EXCLUDED.course_id,
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    is_active = EXCLUDED.is_active,
    updated_at = NOW();

-- Advanced Camera/Payload Operator section
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
    'a0000019-0000-0000-0000-000000000019',
    'b0c1d2e3-f4a5-6789-bcde-901234567890',
    'ADVANCED CAMERA/PAYLOAD OPERATOR',
    1,
    'Professional cinematography and production workflows',
    'units',
    true,
    false,
    true
)
ON CONFLICT (id) DO UPDATE SET
    course_id = EXCLUDED.course_id,
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    is_active = EXCLUDED.is_active,
    updated_at = NOW();

-- Specialized Search & Rescue with Thermography section
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
    'a0000020-0000-0000-0000-000000000020',
    'c1d2e3f4-a5b6-7890-cdef-012345678901',
    'SPECIALIZED SEARCH & RESCUE WITH THERMOGRAPHY',
    1,
    'Advanced SAR operations with thermal imaging',
    'units',
    true,
    false,
    true
)
ON CONFLICT (id) DO UPDATE SET
    course_id = EXCLUDED.course_id,
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    is_active = EXCLUDED.is_active,
    updated_at = NOW();

-- Specialized Post Production section
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
    'a0000021-0000-0000-0000-000000000021',
    'd2e3f4a5-b6c7-8901-defa-123456789012',
    'SPECIALIZED POST PRODUCTION',
    1,
    'Professional post-production workflows',
    'units',
    true,
    false,
    true
)
ON CONFLICT (id) DO UPDATE SET
    course_id = EXCLUDED.course_id,
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    is_active = EXCLUDED.is_active,
    updated_at = NOW();

-- Drone Repair Technician/Engineer section
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
    'a0000022-0000-0000-0000-000000000022',
    'e3f4a5b6-c7d8-9012-efab-234567890123',
    'DRONE REPAIR TECHNICIAN/ENGINEER',
    1,
    'Comprehensive drone maintenance and repair',
    'units',
    true,
    false,
    true
)
ON CONFLICT (id) DO UPDATE SET
    course_id = EXCLUDED.course_id,
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    is_active = EXCLUDED.is_active,
    updated_at = NOW();

-- Public Safety Pilot section
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
    'a0000023-0000-0000-0000-000000000023',
    'f4a5b6c7-d8e9-0123-fabc-345678901234',
    'PUBLIC SAFETY PILOT',
    1,
    'Public safety drone operations training',
    'units',
    true,
    false,
    true
)
ON CONFLICT (id) DO UPDATE SET
    course_id = EXCLUDED.course_id,
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    is_active = EXCLUDED.is_active,
    updated_at = NOW();

-- ============================================================
-- Summary:
-- ============================================================
-- 
-- INTERMEDIATE (2 courses):
-- 1. Intermediate Drone Pilot (e7f8a9b0-c1d2-3456-efab-678901234567)
-- 2. Intermediate Camera/Payload Operator (f8a9b0c1-d2e3-4567-fabc-789012345678)
--
-- ADVANCED (2 courses):
-- 1. Advanced Drone Pilot (a9b0c1d2-e3f4-5678-abcd-890123456789)
-- 2. Advanced Camera/Payload Operator (b0c1d2e3-f4a5-6789-bcde-901234567890)
--
-- SPECIALIZED (4 courses):
-- 1. Specialized Search & Rescue with Thermography (c1d2e3f4-a5b6-7890-cdef-012345678901)
-- 2. Specialized Post Production (d2e3f4a5-b6c7-8901-defa-123456789012)
-- 3. Drone Repair Technician/Engineer (e3f4a5b6-c7d8-9012-efab-234567890123)
-- 4. Public Safety Pilot (f4a5b6c7-d8e9-0123-fabc-345678901234)
--
-- All courses:
-- - Provider: Buzz
-- - Require UAS Pilot Ground School Test
-- - Require subscription
-- - Level: Intermediate courses = "Intermediate", Advanced/Specialized courses = "Advanced"
--
-- ============================================================
-- Verification query:
-- ============================================================
-- SELECT id, title, category, level, duration FROM public.training_courses 
-- WHERE category IN ('Intermediate', 'Advanced', 'Specialized')
-- ORDER BY 
--   CASE category 
--     WHEN 'Intermediate' THEN 1 
--     WHEN 'Advanced' THEN 2 
--     WHEN 'Specialized' THEN 3 
--   END, 
--   title;
