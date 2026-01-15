-- Migration: Add Specialized Drone Courses
-- Description: Rename Extension Courses to Camera/Payload Operator and add 11 new beginner courses
-- Created: 2026-01-15

-- ============================================================
-- Step 1: Rename Extension Courses to Camera/Payload Operator
-- ============================================================

UPDATE public.training_courses
SET 
    title = 'Camera/Payload Operator',
    description = 'Master the skills of operating camera and payload systems on drones. Learn advanced techniques for capturing professional aerial footage and operating specialized equipment.',
    level = 'Beginner',
    duration = '7 hours',
    updated_at = NOW()
WHERE id = 'e5f6a7b8-c9d0-1234-efab-567890123456';

-- Update the section name to match
UPDATE public.course_sections
SET 
    name = 'CAMERA/PAYLOAD OPERATOR',
    description = 'Camera and payload operation training',
    updated_at = NOW()
WHERE id = 'a0000004-0000-0000-0000-000000000004'
  AND course_id = 'e5f6a7b8-c9d0-1234-efab-567890123456';

-- Note: Unit 5 (Camera/Payload Operator) will remain in this course
-- Unit 6 (Drone Business) will be moved to the new Drone Business course below

-- ============================================================
-- Step 2: Add new categories for specialized courses
-- ============================================================

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
    'Basic Firefighter'::text,
    'Business'::text,
    'Industry Applications'::text,
    'Emergency Services'::text
]));

-- ============================================================
-- Step 3: Create the new specialized courses
-- Order matches user's requested display order
-- ============================================================

-- 1. Drone Business
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
    'Learn how to start and grow your drone business. Cover business planning, marketing, pricing strategies, legal requirements, and client management for commercial drone operations.',
    '7 hours',
    'Beginner',
    'Business',
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

-- 2. Automotive
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
    'a7b8c9d0-e1f2-3456-abcd-789012345678',
    'Automotive',
    'Specialize in automotive drone operations including vehicle photography, dealership marketing, automotive inspections, and tracking shots for automotive content creation.',
    '4 hours',
    'Beginner',
    'Industry Applications',
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

-- 3. Real Estate
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
    'b8c9d0e1-f2a3-4567-bcde-890123456789',
    'Real Estate',
    'Master real estate aerial photography and videography. Learn techniques for showcasing properties, creating listing videos, and capturing stunning aerial perspectives that sell homes.',
    '5 hours',
    'Beginner',
    'Aerial Photography',
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

-- 4. Motion Picture
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
    'c9d0e1f2-a3b4-5678-cdef-901234567890',
    'Motion Picture',
    'Learn cinematic drone techniques for film and video production. Master storytelling through aerial cinematography, shot composition, camera movements, and professional filming workflows.',
    '6 hours',
    'Beginner',
    'Cinematography',
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

-- 5. Agriculture
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
    'd0e1f2a3-b4c5-6789-defa-012345678901',
    'Agriculture',
    'Apply drone technology to precision agriculture. Learn crop monitoring, multispectral imaging, field mapping, livestock management, and data analysis for agricultural applications.',
    '6 hours',
    'Beginner',
    'Industry Applications',
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

-- 6. Inspections
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
    'e1f2a3b4-c5d6-7890-efab-123456789012',
    'Inspections',
    'Conduct professional drone inspections for infrastructure, buildings, towers, and industrial facilities. Learn safety protocols, inspection techniques, and reporting standards.',
    '5 hours',
    'Beginner',
    'Inspections',
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

-- 7. Search & Rescue
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
    'f2a3b4c5-d6e7-8901-fabc-234567890123',
    'Search & Rescue',
    'Train for search and rescue drone operations. Learn mission planning, search patterns, thermal imaging, coordination with emergency services, and life-saving techniques.',
    '6 hours',
    'Beginner',
    'Emergency Services',
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

-- 8. Logistics
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
    'a3b4c5d6-e7f8-9012-abcd-345678901234',
    'Logistics',
    'Explore drone applications in logistics and delivery. Learn about autonomous delivery systems, route planning, payload management, and the future of drone logistics.',
    '5 hours',
    'Beginner',
    'Industry Applications',
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

-- 9. Drone Arts
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
    'b4c5d6e7-f8a9-0123-bcde-456789012345',
    'Drone Arts',
    'Discover the artistic side of drone flight. Learn drone light shows, creative aerial photography, synchronized performances, and artistic expression through drone technology.',
    '4 hours',
    'Beginner',
    'Aerial Photography',
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

-- 10. Surveillance and Security
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
    'c5d6e7f8-a9b0-1234-cdef-567890123456',
    'Surveillance and Security',
    'Learn security and surveillance drone operations. Cover perimeter monitoring, event security, threat detection, privacy considerations, and legal compliance for security operations.',
    '5 hours',
    'Beginner',
    'Emergency Services',
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

-- 11. Surveying
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
    'd6e7f8a9-b0c1-2345-defa-678901234567',
    'Surveying',
    'Master drone surveying and mapping techniques. Learn photogrammetry, GIS integration, topographic surveys, volumetric calculations, and professional surveying workflows.',
    '6 hours',
    'Beginner',
    'Mapping & Surveying',
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
-- Step 4: Create course sections for each new course
-- Each course needs at least one section to display content
-- ============================================================

-- Drone Business section
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
    'DRONE BUSINESS',
    1,
    'Business training for commercial drone operations',
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

-- Automotive section
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
    'a0000006-0000-0000-0000-000000000006',
    'a7b8c9d0-e1f2-3456-abcd-789012345678',
    'AUTOMOTIVE',
    1,
    'Automotive drone operations training',
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

-- Real Estate section
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
    'a0000007-0000-0000-0000-000000000007',
    'b8c9d0e1-f2a3-4567-bcde-890123456789',
    'REAL ESTATE',
    1,
    'Real estate aerial photography and videography',
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

-- Motion Picture section
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
    'a0000008-0000-0000-0000-000000000008',
    'c9d0e1f2-a3b4-5678-cdef-901234567890',
    'MOTION PICTURE',
    1,
    'Cinematic drone techniques for film production',
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

-- Agriculture section
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
    'a0000009-0000-0000-0000-000000000009',
    'd0e1f2a3-b4c5-6789-defa-012345678901',
    'AGRICULTURE',
    1,
    'Precision agriculture and crop monitoring',
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

-- Inspections section
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
    'a0000010-0000-0000-0000-000000000010',
    'e1f2a3b4-c5d6-7890-efab-123456789012',
    'INSPECTIONS',
    1,
    'Professional drone inspection techniques',
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

-- Search & Rescue section
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
    'a0000011-0000-0000-0000-000000000011',
    'f2a3b4c5-d6e7-8901-fabc-234567890123',
    'SEARCH & RESCUE',
    1,
    'Search and rescue drone operations',
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

-- Logistics section
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
    'a0000012-0000-0000-0000-000000000012',
    'a3b4c5d6-e7f8-9012-abcd-345678901234',
    'LOGISTICS',
    1,
    'Drone logistics and delivery operations',
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

-- Drone Arts section
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
    'a0000013-0000-0000-0000-000000000013',
    'b4c5d6e7-f8a9-0123-bcde-456789012345',
    'DRONE ARTS',
    1,
    'Artistic drone flight and performances',
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

-- Surveillance and Security section
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
    'a0000014-0000-0000-0000-000000000014',
    'c5d6e7f8-a9b0-1234-cdef-567890123456',
    'SURVEILLANCE AND SECURITY',
    1,
    'Security and surveillance operations',
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

-- Surveying section
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
    'a0000015-0000-0000-0000-000000000015',
    'd6e7f8a9-b0c1-2345-defa-678901234567',
    'SURVEYING',
    1,
    'Professional surveying and mapping',
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
-- Step 5: Move Unit 6 (Drone Business) to the new Drone Business course
-- ============================================================

-- Update Unit 6 to point to new Drone Business course
UPDATE public.course_units
SET course_id = 'f6a7b8c9-d0e1-2345-fabc-678901234567',
    section_id = 'a0000005-0000-0000-0000-000000000005',
    updated_at = NOW()
WHERE id = '00000000-0000-0000-0000-000000000006'
  AND (
    course_id = 'e5f6a7b8-c9d0-1234-efab-567890123456' OR
    course_id = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
  );

-- ============================================================
-- Summary:
-- ============================================================
-- Renamed Extension Courses to Camera/Payload Operator
-- 
-- Added 11 new beginner courses (all require Ground School Test):
-- 1. Drone Business (f6a7b8c9-d0e1-2345-fabc-678901234567)
-- 2. Automotive (a7b8c9d0-e1f2-3456-abcd-789012345678)
-- 3. Real Estate (b8c9d0e1-f2a3-4567-bcde-890123456789)
-- 4. Motion Picture (c9d0e1f2-a3b4-5678-cdef-901234567890)
-- 5. Agriculture (d0e1f2a3-b4c5-6789-defa-012345678901)
-- 6. Inspections (e1f2a3b4-c5d6-7890-efab-123456789012)
-- 7. Search & Rescue (f2a3b4c5-d6e7-8901-fabc-234567890123)
-- 8. Logistics (a3b4c5d6-e7f8-9012-abcd-345678901234)
-- 9. Drone Arts (b4c5d6e7-f8a9-0123-bcde-456789012345)
-- 10. Surveillance and Security (c5d6e7f8-a9b0-1234-cdef-567890123456)
-- 11. Surveying (d6e7f8a9-b0c1-2345-defa-678901234567)
--
-- Course structure:
-- - Camera/Payload Operator: Contains Unit 5
-- - Drone Business: Contains Unit 6
-- - Other 10 courses: Empty sections ready for content
--
-- All courses require passing the Ground School Test (requires_uas_ground_school = true)
-- All courses are Beginner level
-- All sections require subscription

-- ============================================================
-- Verification queries:
-- ============================================================
-- SELECT id, title, level, requires_uas_ground_school FROM public.training_courses 
-- WHERE requires_uas_ground_school = true 
-- ORDER BY created_at DESC LIMIT 12;
-- 
-- SELECT id, title, course_id FROM public.course_units 
-- WHERE id IN ('00000000-0000-0000-0000-000000000005', '00000000-0000-0000-0000-000000000006');
