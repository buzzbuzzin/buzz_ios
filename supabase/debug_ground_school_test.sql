-- Debug script to check Ground School Test results
-- Run this to verify test results are stored correctly

-- 1. Check if test_results table has the correct structure
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'test_results' 
ORDER BY ordinal_position;

-- 2. Check all test results for the UAS Pilot course
SELECT 
    pilot_id,
    course_id,
    test_id,
    score,
    passed,
    created_at
FROM public.test_results
WHERE course_id = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
ORDER BY created_at DESC;

-- 3. Test the has_passed_ground_school_test function
-- Replace <YOUR_PILOT_ID> with your actual pilot ID
-- SELECT public.has_passed_ground_school_test('<YOUR_PILOT_ID>');

-- 4. Check which courses require ground school test
SELECT 
    id,
    title,
    requires_uas_ground_school
FROM public.training_courses
WHERE requires_uas_ground_school = true;

-- 5. Check if there's a unique constraint on test_results
SELECT
    con.conname AS constraint_name,
    con.contype AS constraint_type,
    ARRAY_AGG(att.attname ORDER BY u.attposition) AS constraint_columns
FROM pg_constraint con
JOIN pg_class rel ON rel.oid = con.conrelid
JOIN LATERAL unnest(con.conkey) WITH ORDINALITY AS u(attnum, attposition) ON TRUE
JOIN pg_attribute att ON att.attnum = u.attnum AND att.attrelid = con.conrelid
WHERE rel.relname = 'test_results'
AND con.contype IN ('p', 'u')  -- primary key and unique constraints
GROUP BY con.conname, con.contype;
