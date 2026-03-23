-- Fix unique constraint to allow multiple course badges per pilot
-- Old: UNIQUE (pilot_id, badge_type) - blocks multiple course badges
-- New: UNIQUE (pilot_id, badge_type, course_id) - allows multiple courses, prevents duplicates

ALTER TABLE badges DROP CONSTRAINT badges_pilot_id_badge_type_unique;

-- Use COALESCE so non-course badges (where course_id is NULL) still enforce one-per-type
CREATE UNIQUE INDEX badges_pilot_badge_type_course_unique
  ON badges (pilot_id, badge_type, COALESCE(course_id, '00000000-0000-0000-0000-000000000000'));
