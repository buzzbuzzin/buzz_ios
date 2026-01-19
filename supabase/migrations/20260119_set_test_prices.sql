-- Set prices for proctored exams

-- Update ROC-A Radio Competency Exam price
UPDATE course_tests 
SET price_of_schedule = 4900  -- $49.00
WHERE test_name LIKE '%ROC-A%' OR test_name LIKE '%Radio Competency%';

-- Update Flight Review exam price (if exists)
UPDATE course_tests 
SET price_of_schedule = 9900  -- $99.00
WHERE test_name LIKE '%Flight Review%' AND needs_proctor = true;

-- Set free for non-proctored tests
UPDATE course_tests 
SET price_of_schedule = 0
WHERE needs_proctor = false AND price_of_schedule IS NULL;

-- Verify updates
SELECT 
    test_name, 
    test_type,
    needs_proctor,
    price_of_schedule,
    CASE 
        WHEN price_of_schedule IS NULL THEN 'Free'
        WHEN price_of_schedule = 0 THEN 'Free'
        ELSE '$' || (price_of_schedule::float / 100)::text
    END as formatted_price
FROM course_tests 
WHERE needs_proctor = true
ORDER BY test_name;
