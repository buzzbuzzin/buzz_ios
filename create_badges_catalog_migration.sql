-- Migration: Create badges catalog table for dynamic badge management
-- Run this SQL in your Supabase SQL Editor

-- ============================================================================
-- Step 1: Create badges_catalog table
-- ============================================================================

CREATE TABLE IF NOT EXISTS badges_catalog (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    badge_type TEXT NOT NULL CHECK (badge_type IN ('course', 'ex_military', 'buzz', 'government_employee', 'faa')),
    title TEXT NOT NULL,
    category TEXT, -- For course badges: course category. For criteria badges: null or category like "Service Recognition"
    course_id UUID REFERENCES training_courses(id) ON DELETE SET NULL, -- For course badges only
    icon_name TEXT NOT NULL, -- SF Symbol name
    color_name TEXT NOT NULL DEFAULT 'blue', -- Color name: blue, purple, green, red, orange, pink, gray
    provider TEXT NOT NULL DEFAULT 'Buzz' CHECK (provider IN ('Buzz', 'Amazon', 'T-Mobile', 'Other')),
    is_recurrent BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE, -- Whether this badge is currently available
    display_order INTEGER DEFAULT 0, -- Order for display
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()) NOT NULL,
    UNIQUE(badge_type, course_id) -- Ensure unique badge_type per course (for course badges)
);

-- Enable Row Level Security
ALTER TABLE badges_catalog ENABLE ROW LEVEL SECURITY;

-- Drop policy if exists and recreate
DROP POLICY IF EXISTS "Anyone can view active badges catalog" ON badges_catalog;

-- Allow anyone authenticated to view active badges
CREATE POLICY "Anyone can view active badges catalog" 
    ON badges_catalog FOR SELECT 
    TO authenticated
    USING (is_active = TRUE);

-- ============================================================================
-- Step 2: Insert default badges catalog entries
-- ============================================================================

-- Criteria-based badges
INSERT INTO badges_catalog (badge_type, title, category, course_id, icon_name, color_name, provider, is_recurrent, is_active, display_order)
VALUES 
    ('ex_military', 'Ex-Military', 'Service Recognition', NULL, 'shield.fill', 'purple', 'Buzz', FALSE, TRUE, 1),
    ('buzz', 'Buzz', 'Partnership', NULL, 'airplane.circle.fill', 'blue', 'Buzz', FALSE, TRUE, 2),
    ('government_employee', 'Government', 'Service Recognition', NULL, 'building.columns.fill', 'green', 'Buzz', FALSE, TRUE, 3),
    ('faa', 'FAA', 'Certification', NULL, 'checkmark.seal.fill', 'red', 'Buzz', FALSE, TRUE, 4)
ON CONFLICT (badge_type, course_id) DO NOTHING;

-- Note: Course badges will be added dynamically when courses are created
-- For now, we'll fetch course badges from training_courses table

-- ============================================================================
-- Step 3: Create function to get available badges for a pilot
-- ============================================================================

-- Drop function if it exists (needed when changing return type)
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
    -- Criteria-based badges from catalog
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
      AND bc.badge_type != 'course'
      AND NOT EXISTS (
          SELECT 1 FROM badges b
          WHERE b.pilot_id = pilot_id_param
            AND b.badge_type = bc.badge_type
      )
    
    UNION ALL
    
    -- Course-based badges from training_courses
    SELECT 
        tc.id::UUID,
        'course'::TEXT as badge_type,
        tc.title,
        tc.category,
        tc.id as course_id,
        'book.fill'::TEXT as icon_name,
        'blue'::TEXT as color_name,
        COALESCE(tc.provider, 'Buzz') as provider,
        FALSE as is_recurrent,
        999 as display_order
    FROM training_courses tc
    WHERE NOT EXISTS (
        SELECT 1 FROM badges b
        WHERE b.pilot_id = pilot_id_param
          AND b.course_id = tc.id
    )
    ORDER BY display_order, title;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- Step 4: Add comments for documentation
-- ============================================================================

COMMENT ON TABLE badges_catalog IS 'Catalog of all available badges that can be earned';
COMMENT ON COLUMN badges_catalog.badge_type IS 'Type of badge: course (from course completion) or criteria-based (ex_military, buzz, government_employee, faa)';
COMMENT ON COLUMN badges_catalog.course_id IS 'For course badges: reference to training_courses. For criteria badges: NULL';
COMMENT ON COLUMN badges_catalog.icon_name IS 'SF Symbol name for the badge icon';
COMMENT ON COLUMN badges_catalog.color_name IS 'Color name for the badge (blue, purple, green, red, orange, pink, gray)';
COMMENT ON COLUMN badges_catalog.is_active IS 'Whether this badge is currently available to earn';

