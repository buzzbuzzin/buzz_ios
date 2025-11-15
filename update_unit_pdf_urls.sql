-- Update course units with PDF URLs for Unit 1, 2, and 3
-- Run this SQL in your Supabase SQL Editor

-- Note: Storing multiple PDF URLs as JSON array since units have multiple modules
-- The pdf_url field will contain a JSON array of PDF URLs

-- Unit 1 - GROUND SCHOOL (3 modules: Module 1, Module 2, Module 4)
UPDATE course_units 
SET pdf_url = '["https://mzapuczjijqjzdcujetx.supabase.co/storage/v1/object/public/course-materials/unit-1/Unit%201,%20Module%201.pdf", "https://mzapuczjijqjzdcujetx.supabase.co/storage/v1/object/public/course-materials/unit-1/Unit%201,%20Module%202.pdf", "https://mzapuczjijqjzdcujetx.supabase.co/storage/v1/object/public/course-materials/unit-1/Unit%201,%20Module%204.pdf"]'::jsonb,
    updated_at = NOW()
WHERE course_id = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890' 
  AND unit_number = 1;

-- Unit 2 - HEALTH & SAFETY (2 modules: Module 1, Module 2)
UPDATE course_units 
SET pdf_url = '["https://mzapuczjijqjzdcujetx.supabase.co/storage/v1/object/public/course-materials/unit-2/Unit%202,%20Module%201.pdf", "https://mzapuczjijqjzdcujetx.supabase.co/storage/v1/object/public/course-materials/unit-2/Unit%202,%20Module%202.pdf"]'::jsonb,
    updated_at = NOW()
WHERE course_id = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890' 
  AND unit_number = 2;

-- Unit 3 - OPERATIONS (2 modules: Module 1, Module 2)
UPDATE course_units 
SET pdf_url = '["https://mzapuczjijqjzdcujetx.supabase.co/storage/v1/object/public/course-materials/unit-3/Unit%203,%20Module%201.pdf", "https://mzapuczjijqjzdcujetx.supabase.co/storage/v1/object/public/course-materials/unit-3/Unit%203,%20Module%202.pdf"]'::jsonb,
    updated_at = NOW()
WHERE course_id = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890' 
  AND unit_number = 3;

-- Verify updates
-- SELECT unit_number, title, pdf_url FROM course_units 
-- WHERE course_id = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890' 
--   AND unit_number IN (1, 2, 3)
-- ORDER BY unit_number;

