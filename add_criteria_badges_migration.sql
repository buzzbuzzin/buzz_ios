-- Migration: Add criteria-based badges (Ex-military, Buzz, Government employee, FAA)
-- Run this SQL in your Supabase SQL Editor

-- ============================================================================
-- Step 1: Add profile fields for badge criteria
-- ============================================================================

DO $$ 
BEGIN
    -- Add is_ex_military field
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'profiles' AND column_name = 'is_ex_military'
    ) THEN
        ALTER TABLE profiles ADD COLUMN is_ex_military BOOLEAN DEFAULT FALSE;
    END IF;
    
    -- Add is_government_employee field
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'profiles' AND column_name = 'is_government_employee'
    ) THEN
        ALTER TABLE profiles ADD COLUMN is_government_employee BOOLEAN DEFAULT FALSE;
    END IF;
    
    -- Add has_faa_certification field
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'profiles' AND column_name = 'has_faa_certification'
    ) THEN
        ALTER TABLE profiles ADD COLUMN has_faa_certification BOOLEAN DEFAULT FALSE;
    END IF;
    
    -- Add is_buzz_affiliate field
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'profiles' AND column_name = 'is_buzz_affiliate'
    ) THEN
        ALTER TABLE profiles ADD COLUMN is_buzz_affiliate BOOLEAN DEFAULT FALSE;
    END IF;
END $$;

-- ============================================================================
-- Step 2: Update badges table to support non-course badges
-- ============================================================================

-- Make course_id nullable (badges can now exist without a course)
DO $$ 
BEGIN
    -- Check if course_id is already nullable
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'badges' 
        AND column_name = 'course_id' 
        AND is_nullable = 'NO'
    ) THEN
        ALTER TABLE badges ALTER COLUMN course_id DROP NOT NULL;
    END IF;
END $$;

-- Add badge_type column to distinguish between course badges and criteria badges
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'badges' AND column_name = 'badge_type'
    ) THEN
        ALTER TABLE badges ADD COLUMN badge_type TEXT DEFAULT 'course' 
        CHECK (badge_type IN ('course', 'ex_military', 'buzz', 'government_employee', 'faa'));
    END IF;
END $$;

-- Make course_title and course_category nullable for non-course badges
DO $$ 
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'badges' 
        AND column_name = 'course_title' 
        AND is_nullable = 'NO'
    ) THEN
        ALTER TABLE badges ALTER COLUMN course_title DROP NOT NULL;
    END IF;
    
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'badges' 
        AND column_name = 'course_category' 
        AND is_nullable = 'NO'
    ) THEN
        ALTER TABLE badges ALTER COLUMN course_category DROP NOT NULL;
    END IF;
END $$;

-- ============================================================================
-- Step 3: Ensure badges_catalog table exists (create if not exists)
-- ============================================================================

-- Create badges_catalog table if it doesn't exist (from create_badges_catalog_migration.sql)
CREATE TABLE IF NOT EXISTS badges_catalog (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    badge_type TEXT NOT NULL CHECK (badge_type IN ('course', 'ex_military', 'buzz', 'government_employee', 'faa')),
    title TEXT NOT NULL,
    category TEXT,
    course_id UUID REFERENCES training_courses(id) ON DELETE SET NULL,
    icon_name TEXT NOT NULL,
    color_name TEXT NOT NULL DEFAULT 'blue',
    provider TEXT NOT NULL DEFAULT 'Buzz' CHECK (provider IN ('Buzz', 'Amazon', 'T-Mobile', 'Other')),
    is_recurrent BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    display_order INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()) NOT NULL,
    UNIQUE(badge_type, course_id)
);

-- Enable RLS if not already enabled
ALTER TABLE badges_catalog ENABLE ROW LEVEL SECURITY;

-- Drop policy if exists and recreate
DROP POLICY IF EXISTS "Anyone can view active badges catalog" ON badges_catalog;

CREATE POLICY "Anyone can view active badges catalog" 
    ON badges_catalog FOR SELECT 
    TO authenticated
    USING (is_active = TRUE);

-- Insert default badges if they don't exist
INSERT INTO badges_catalog (badge_type, title, category, course_id, icon_name, color_name, provider, is_recurrent, is_active, display_order)
VALUES 
    ('ex_military', 'Ex-Military', 'Service Recognition', NULL, 'shield.fill', 'purple', 'Buzz', FALSE, TRUE, 1),
    ('buzz', 'Buzz', 'Partnership', NULL, 'airplane.circle.fill', 'blue', 'Buzz', FALSE, TRUE, 2),
    ('government_employee', 'Government', 'Service Recognition', NULL, 'building.columns.fill', 'green', 'Buzz', FALSE, TRUE, 3),
    ('faa', 'FAA', 'Certification', NULL, 'checkmark.seal.fill', 'red', 'Buzz', FALSE, TRUE, 4)
ON CONFLICT (badge_type, course_id) DO NOTHING;

-- ============================================================================
-- Step 4: Create function to automatically award criteria-based badges
-- ============================================================================

CREATE OR REPLACE FUNCTION award_criteria_badges()
RETURNS TRIGGER AS $$
DECLARE
    badge_exists BOOLEAN;
BEGIN
    -- Award Ex-military badge
    IF NEW.is_ex_military = TRUE THEN
        SELECT EXISTS (
            SELECT 1 FROM badges 
            WHERE pilot_id = NEW.id 
            AND badge_type = 'ex_military'
        ) INTO badge_exists;
        
        IF NOT badge_exists THEN
            INSERT INTO badges (
                id, pilot_id, course_id, course_title, course_category, 
                provider, badge_type, earned_at, expires_at, is_recurrent
            )
            SELECT 
                uuid_generate_v4(),
                NEW.id,
                NULL,
                bc.title,
                bc.category,
                bc.provider,
                bc.badge_type,
                NOW(),
                NULL,
                bc.is_recurrent
            FROM badges_catalog bc
            WHERE bc.badge_type = 'ex_military' AND bc.is_active = TRUE
            LIMIT 1;
        END IF;
    END IF;
    
    -- Award Buzz badge
    IF NEW.is_buzz_affiliate = TRUE THEN
        SELECT EXISTS (
            SELECT 1 FROM badges 
            WHERE pilot_id = NEW.id 
            AND badge_type = 'buzz'
        ) INTO badge_exists;
        
        IF NOT badge_exists THEN
            INSERT INTO badges (
                id, pilot_id, course_id, course_title, course_category, 
                provider, badge_type, earned_at, expires_at, is_recurrent
            )
            SELECT 
                uuid_generate_v4(),
                NEW.id,
                NULL,
                bc.title,
                bc.category,
                bc.provider,
                bc.badge_type,
                NOW(),
                NULL,
                bc.is_recurrent
            FROM badges_catalog bc
            WHERE bc.badge_type = 'buzz' AND bc.is_active = TRUE
            LIMIT 1;
        END IF;
    END IF;
    
    -- Award Government employee badge
    IF NEW.is_government_employee = TRUE THEN
        SELECT EXISTS (
            SELECT 1 FROM badges 
            WHERE pilot_id = NEW.id 
            AND badge_type = 'government_employee'
        ) INTO badge_exists;
        
        IF NOT badge_exists THEN
            INSERT INTO badges (
                id, pilot_id, course_id, course_title, course_category, 
                provider, badge_type, earned_at, expires_at, is_recurrent
            )
            SELECT 
                uuid_generate_v4(),
                NEW.id,
                NULL,
                bc.title,
                bc.category,
                bc.provider,
                bc.badge_type,
                NOW(),
                NULL,
                bc.is_recurrent
            FROM badges_catalog bc
            WHERE bc.badge_type = 'government_employee' AND bc.is_active = TRUE
            LIMIT 1;
        END IF;
    END IF;
    
    -- Award FAA badge
    IF NEW.has_faa_certification = TRUE THEN
        SELECT EXISTS (
            SELECT 1 FROM badges 
            WHERE pilot_id = NEW.id 
            AND badge_type = 'faa'
        ) INTO badge_exists;
        
        IF NOT badge_exists THEN
            INSERT INTO badges (
                id, pilot_id, course_id, course_title, course_category, 
                provider, badge_type, earned_at, expires_at, is_recurrent
            )
            SELECT 
                uuid_generate_v4(),
                NEW.id,
                NULL,
                bc.title,
                bc.category,
                bc.provider,
                bc.badge_type,
                NOW(),
                NULL,
                bc.is_recurrent
            FROM badges_catalog bc
            WHERE bc.badge_type = 'faa' AND bc.is_active = TRUE
            LIMIT 1;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- Step 4: Create trigger to automatically award badges on profile update
-- ============================================================================

DROP TRIGGER IF EXISTS trigger_award_criteria_badges ON profiles;

CREATE TRIGGER trigger_award_criteria_badges
AFTER INSERT OR UPDATE OF is_ex_military, is_government_employee, has_faa_certification, is_buzz_affiliate
ON profiles
FOR EACH ROW
WHEN (
    NEW.is_ex_military = TRUE OR 
    NEW.is_government_employee = TRUE OR 
    NEW.has_faa_certification = TRUE OR 
    NEW.is_buzz_affiliate = TRUE
)
EXECUTE FUNCTION award_criteria_badges();

-- ============================================================================
-- Step 5: Award badges to existing users who meet criteria
-- ============================================================================

-- Note: This will only award badges if the criteria fields are already set to TRUE
-- You may need to manually update profiles first, or create a separate script
-- to set these fields based on other profile data

-- Example: Award badges to existing profiles (uncomment and modify as needed)
/*
DO $$
DECLARE
    profile_record RECORD;
BEGIN
    FOR profile_record IN 
        SELECT id FROM profiles 
        WHERE is_ex_military = TRUE 
           OR is_government_employee = TRUE 
           OR has_faa_certification = TRUE 
           OR is_buzz_affiliate = TRUE
    LOOP
        PERFORM award_criteria_badges() FROM profiles WHERE id = profile_record.id;
    END LOOP;
END $$;
*/

-- ============================================================================
-- Step 6: Add comments for documentation
-- ============================================================================

COMMENT ON COLUMN profiles.is_ex_military IS 'Indicates if the user is ex-military (awards Ex-Military badge)';
COMMENT ON COLUMN profiles.is_government_employee IS 'Indicates if the user is a government employee (awards Government Employee badge)';
COMMENT ON COLUMN profiles.has_faa_certification IS 'Indicates if the user has FAA certification (awards FAA badge)';
COMMENT ON COLUMN profiles.is_buzz_affiliate IS 'Indicates if the user is a Buzz affiliate (awards Buzz badge)';
COMMENT ON COLUMN badges.badge_type IS 'Type of badge: course (from course completion) or criteria-based (ex_military, buzz, government_employee, faa)';

