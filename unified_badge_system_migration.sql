-- Migration: Unified Badge System - All badges managed through badges_catalog
-- Run this SQL in your Supabase SQL Editor
-- This creates a unified system where ALL badges (course + criteria) are in badges_catalog

-- ============================================================================
-- Step 1: Sync existing courses to badges_catalog
-- ============================================================================

-- Insert all existing courses as course badges in badges_catalog
INSERT INTO badges_catalog (badge_type, title, category, course_id, icon_name, color_name, provider, is_recurrent, is_active, display_order)
SELECT 
    'course'::TEXT,
    tc.title,
    tc.category,
    tc.id,
    'book.fill'::TEXT,
    'blue'::TEXT,
    COALESCE(tc.provider, 'Buzz'),
    FALSE,
    TRUE,
    999 -- Course badges appear after criteria badges
FROM training_courses tc
WHERE NOT EXISTS (
    SELECT 1 FROM badges_catalog bc 
    WHERE bc.course_id = tc.id AND bc.badge_type = 'course'
)
ON CONFLICT (badge_type, course_id) DO NOTHING;

-- ============================================================================
-- Step 2: Create trigger to auto-sync new courses to badges_catalog
-- ============================================================================

CREATE OR REPLACE FUNCTION sync_course_to_badge_catalog()
RETURNS TRIGGER AS $$
BEGIN
    -- Insert course badge into catalog when a new course is created
    INSERT INTO badges_catalog (
        badge_type, 
        title, 
        category, 
        course_id, 
        icon_name, 
        color_name, 
        provider, 
        is_recurrent, 
        is_active, 
        display_order
    )
    VALUES (
        'course',
        NEW.title,
        NEW.category,
        NEW.id,
        'book.fill',
        'blue',
        COALESCE(NEW.provider, 'Buzz'),
        FALSE,
        TRUE,
        999
    )
    ON CONFLICT (badge_type, course_id) DO UPDATE SET
        title = EXCLUDED.title,
        category = EXCLUDED.category,
        provider = EXCLUDED.provider,
        updated_at = NOW();
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop trigger if exists and recreate
DROP TRIGGER IF EXISTS trigger_sync_course_to_badge_catalog ON training_courses;

CREATE TRIGGER trigger_sync_course_to_badge_catalog
AFTER INSERT OR UPDATE OF title, category, provider
ON training_courses
FOR EACH ROW
EXECUTE FUNCTION sync_course_to_badge_catalog();

-- ============================================================================
-- Step 3: Update get_available_badges_for_pilot to ONLY use badges_catalog
-- ============================================================================

DROP FUNCTION IF EXISTS get_available_badges_for_pilot(UUID);

CREATE OR REPLACE FUNCTION get_available_badges_for_pilot(pilot_id_param UUID)
RETURNS TABLE (
    id UUID,
    badge_type TEXT,
    title TEXT,
    category TEXT,
    course_id UUID,
    icon_name TEXT,
    color_name TEXT,
    provider TEXT,
    is_recurrent BOOLEAN,
    display_order INTEGER
) AS $$
BEGIN
    RETURN QUERY
    -- All badges from catalog (both course and criteria badges)
    SELECT 
        bc.id,
        bc.badge_type,
        bc.title,
        bc.category,
        bc.course_id,
        bc.icon_name,
        bc.color_name,
        bc.provider,
        bc.is_recurrent,
        bc.display_order
    FROM badges_catalog bc
    WHERE bc.is_active = TRUE
      AND (
          -- For course badges: check if pilot hasn't earned this course badge
          (bc.badge_type = 'course' AND bc.course_id IS NOT NULL AND NOT EXISTS (
              SELECT 1 FROM badges b
              WHERE b.pilot_id = pilot_id_param
                AND b.course_id = bc.course_id
                AND (b.badge_type = 'course' OR b.badge_type IS NULL)
          ))
          OR
          -- For criteria badges: check if pilot hasn't earned this criteria badge
          (bc.badge_type != 'course' AND NOT EXISTS (
              SELECT 1 FROM badges b
              WHERE b.pilot_id = pilot_id_param
                AND b.badge_type = bc.badge_type
          ))
      )
    ORDER BY bc.display_order, bc.title;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- Step 4: Update awardBadge function to fetch from badges_catalog
-- ============================================================================

-- Create a function to award badges that fetches details from catalog
CREATE OR REPLACE FUNCTION award_badge_from_catalog(
    pilot_id_param UUID,
    course_id_param UUID DEFAULT NULL,
    badge_type_param TEXT DEFAULT 'course'
)
RETURNS UUID AS $$
DECLARE
    badge_catalog_record badges_catalog%ROWTYPE;
    new_badge_id UUID;
BEGIN
    -- Find the badge in catalog
    IF badge_type_param = 'course' AND course_id_param IS NOT NULL THEN
        SELECT * INTO badge_catalog_record
        FROM badges_catalog
        WHERE badge_type = 'course' 
          AND course_id = course_id_param
          AND is_active = TRUE
        LIMIT 1;
    ELSE
        SELECT * INTO badge_catalog_record
        FROM badges_catalog
        WHERE badge_type = badge_type_param
          AND is_active = TRUE
        LIMIT 1;
    END IF;
    
    -- If badge not found in catalog, return NULL
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Badge not found in catalog for course_id: %, badge_type: %', course_id_param, badge_type_param;
    END IF;
    
    -- Check if badge already exists
    IF EXISTS (
        SELECT 1 FROM badges
        WHERE pilot_id = pilot_id_param
          AND (
              (badge_type_param = 'course' AND course_id = course_id_param)
              OR (badge_type_param != 'course' AND badge_type = badge_type_param)
          )
    ) THEN
        -- Badge already exists, return existing badge id
        SELECT id INTO new_badge_id
        FROM badges
        WHERE pilot_id = pilot_id_param
          AND (
              (badge_type_param = 'course' AND course_id = course_id_param)
              OR (badge_type_param != 'course' AND badge_type = badge_type_param)
          )
        LIMIT 1;
        RETURN new_badge_id;
    END IF;
    
    -- Create new badge
    new_badge_id := uuid_generate_v4();
    
    INSERT INTO badges (
        id,
        pilot_id,
        course_id,
        course_title,
        course_category,
        provider,
        badge_type,
        earned_at,
        expires_at,
        is_recurrent
    )
    VALUES (
        new_badge_id,
        pilot_id_param,
        badge_catalog_record.course_id,
        badge_catalog_record.title,
        badge_catalog_record.category,
        badge_catalog_record.provider,
        badge_catalog_record.badge_type,
        NOW(),
        NULL,
        badge_catalog_record.is_recurrent
    );
    
    RETURN new_badge_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- Step 5: Update award_criteria_badges to use catalog
-- ============================================================================

-- Update the award_criteria_badges function to use award_badge_from_catalog
CREATE OR REPLACE FUNCTION award_criteria_badges()
RETURNS TRIGGER AS $$
BEGIN
    -- Award Ex-military badge
    IF NEW.is_ex_military = TRUE THEN
        PERFORM award_badge_from_catalog(NEW.id, NULL, 'ex_military');
    END IF;
    
    -- Award Buzz badge
    IF NEW.is_buzz_affiliate = TRUE THEN
        PERFORM award_badge_from_catalog(NEW.id, NULL, 'buzz');
    END IF;
    
    -- Award Government employee badge
    IF NEW.is_government_employee = TRUE THEN
        PERFORM award_badge_from_catalog(NEW.id, NULL, 'government_employee');
    END IF;
    
    -- Award FAA badge
    IF NEW.has_faa_certification = TRUE THEN
        PERFORM award_badge_from_catalog(NEW.id, NULL, 'faa');
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- Step 6: Add comments
-- ============================================================================

COMMENT ON FUNCTION sync_course_to_badge_catalog() IS 'Automatically syncs new courses to badges_catalog when courses are created or updated';
COMMENT ON FUNCTION award_badge_from_catalog(UUID, UUID, TEXT) IS 'Awards a badge to a pilot by fetching badge details from badges_catalog. Returns the badge ID.';
COMMENT ON FUNCTION get_available_badges_for_pilot(UUID) IS 'Returns all available badges (from badges_catalog) that a pilot can earn but hasn''t earned yet';
COMMENT ON FUNCTION award_criteria_badges() IS 'Awards criteria-based badges when profile criteria are met. Uses award_badge_from_catalog for consistency.';

