-- Remove all demo courses except UAS Pilot Course
-- Run this SQL in your Supabase SQL Editor

-- Delete all courses except UAS Pilot Course (using the fixed UUID)
DELETE FROM training_courses 
WHERE id != 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';

-- Also delete any course units that belong to deleted courses
DELETE FROM course_units
WHERE course_id NOT IN (
    SELECT id FROM training_courses WHERE id = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
);

-- Verify only UAS Pilot Course remains
-- SELECT id, title, provider, students_count FROM training_courses;

-- Verify course units
-- SELECT COUNT(*) as unit_count FROM course_units WHERE course_id = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';

