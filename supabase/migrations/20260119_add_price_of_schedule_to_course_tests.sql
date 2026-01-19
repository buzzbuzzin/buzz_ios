-- Add price_of_schedule column to course_tests table
-- This column stores the exam scheduling price in cents (e.g., 9900 for $99.00)

-- Add the column if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'course_tests' 
        AND column_name = 'price_of_schedule'
    ) THEN
        ALTER TABLE course_tests 
        ADD COLUMN price_of_schedule INTEGER;
        
        -- Add comment to explain the column
        COMMENT ON COLUMN course_tests.price_of_schedule IS 'Price in cents for scheduling this exam (e.g., 9900 = $99.00). NULL or 0 means free.';
    END IF;
END $$;

-- Example: Update prices for specific tests (adjust as needed)
-- UPDATE course_tests SET price_of_schedule = 9900 WHERE test_type = 'oral' AND needs_proctor = true;
-- UPDATE course_tests SET price_of_schedule = 7900 WHERE test_type = 'practical' AND needs_proctor = true;
-- UPDATE course_tests SET price_of_schedule = 0 WHERE test_type = 'multiple_choice' AND needs_proctor = false;
