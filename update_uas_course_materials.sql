-- Update UAS Pilot Course Materials
-- Run this SQL in your Supabase SQL Editor
-- Updates Unit 1 and Unit 4 with new PDF materials

-- Unit 1 - GROUND SCHOOL
-- Now includes: Syllabus, Introduction, Module 1, Module 2, Module 3, Module 4
-- Order: Syllabus -> Introduction -> Module 1 -> Module 2 -> Module 3 -> Module 4
UPDATE course_units 
SET pdf_url = '[
    "https://mzapuczjijqjzdcujetx.supabase.co/storage/v1/object/public/course-materials/unit-1/Drone%20Pilot%20Flowchart.pdf",
    "https://mzapuczjijqjzdcujetx.supabase.co/storage/v1/object/public/course-materials/unit-1/Buzz_Introduction.pdf",
    "https://mzapuczjijqjzdcujetx.supabase.co/storage/v1/object/public/course-materials/unit-1/Unit%201,%20Module%201.pdf",
    "https://mzapuczjijqjzdcujetx.supabase.co/storage/v1/object/public/course-materials/unit-1/Unit%201,%20Module%202.pdf",
    "https://mzapuczjijqjzdcujetx.supabase.co/storage/v1/object/public/course-materials/unit-1/Unit%201,%20Module%203.pdf",
    "https://mzapuczjijqjzdcujetx.supabase.co/storage/v1/object/public/course-materials/unit-1/Unit%201,%20Module%204.pdf"
]'::jsonb,
    updated_at = NOW()
WHERE course_id = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890' 
  AND unit_number = 1;

-- Unit 4 - DRONE PILOT
-- Add Module 1 PDF
UPDATE course_units 
SET pdf_url = '[
    "https://mzapuczjijqjzdcujetx.supabase.co/storage/v1/object/public/course-materials/unit-4/Unit%204,%20Module%201.pdf"
]'::jsonb,
    updated_at = NOW()
WHERE course_id = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890' 
  AND unit_number = 4;

-- Verify updates
SELECT 
    unit_number, 
    title, 
    pdf_url,
    jsonb_array_length(pdf_url) as num_files
FROM course_units 
WHERE course_id = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890' 
  AND unit_number IN (1, 4)
ORDER BY unit_number;

