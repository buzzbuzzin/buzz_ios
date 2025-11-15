-- Fix students_count trigger to handle both INSERT and DELETE properly
-- This replaces the existing trigger with a correct implementation

-- Drop existing trigger and function
DROP TRIGGER IF EXISTS trigger_update_students_count ON course_enrollments;
DROP FUNCTION IF EXISTS update_course_students_count();

-- Create improved function that handles both INSERT and DELETE
CREATE OR REPLACE FUNCTION update_course_students_count()
RETURNS TRIGGER AS $$
DECLARE
    affected_course_id UUID;
BEGIN
    -- Determine which course_id to update
    IF TG_OP = 'DELETE' THEN
        affected_course_id := OLD.course_id;
    ELSE
        affected_course_id := NEW.course_id;
    END IF;
    
    -- Update the students_count for the affected course
    UPDATE training_courses
    SET students_count = (
        SELECT COUNT(DISTINCT pilot_id)
        FROM course_enrollments
        WHERE course_id = affected_course_id
    )
    WHERE id = affected_course_id;
    
    -- Return appropriate value based on operation
    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for both INSERT and DELETE operations
CREATE TRIGGER trigger_update_students_count
    AFTER INSERT OR DELETE ON course_enrollments
    FOR EACH ROW
    EXECUTE FUNCTION update_course_students_count();

-- Manually fix existing counts (in case they're wrong)
UPDATE training_courses
SET students_count = (
    SELECT COUNT(DISTINCT pilot_id)
    FROM course_enrollments
    WHERE course_id = training_courses.id
);

-- Verify the fix
SELECT 
    tc.title,
    tc.students_count,
    COUNT(DISTINCT ce.pilot_id) as actual_count
FROM training_courses tc
LEFT JOIN course_enrollments ce ON tc.id = ce.course_id
GROUP BY tc.id, tc.title, tc.students_count
ORDER BY tc.title;

