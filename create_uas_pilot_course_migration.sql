-- Migration: Add provider field to training_courses and create course units structure
-- Run this SQL in your Supabase SQL Editor

-- Add provider column to training_courses if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'training_courses' 
        AND column_name = 'provider'
    ) THEN
        ALTER TABLE training_courses 
        ADD COLUMN provider TEXT DEFAULT 'Buzz' 
        CHECK (provider IN ('Buzz', 'Amazon', 'T-Mobile', 'Other'));
    END IF;
END $$;

-- Add instructor_picture_url column if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'training_courses' 
        AND column_name = 'instructor_picture_url'
    ) THEN
        ALTER TABLE training_courses 
        ADD COLUMN instructor_picture_url TEXT;
    END IF;
END $$;

-- Create course_units table
CREATE TABLE IF NOT EXISTS course_units (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    course_id UUID REFERENCES training_courses(id) ON DELETE CASCADE NOT NULL,
    unit_number INTEGER NOT NULL,
    title TEXT NOT NULL,
    description TEXT,
    content TEXT, -- Course material content (can be markdown or HTML)
    pdf_url JSONB, -- URLs to PDF course materials stored in storage bucket (array of URLs for multiple modules)
    step_number INTEGER, -- Which step this unit belongs to (1, 2, or 3)
    is_mandatory BOOLEAN DEFAULT FALSE,
    order_index INTEGER NOT NULL, -- Order within the course
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()) NOT NULL,
    UNIQUE(course_id, unit_number)
);

-- Add pdf_url column if table already exists (stored as JSONB to support multiple PDFs per unit)
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'course_units' 
        AND column_name = 'pdf_url'
    ) THEN
        ALTER TABLE course_units 
        ADD COLUMN pdf_url JSONB;
    ELSE
        -- If column exists as TEXT, convert to JSONB
        IF EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'course_units' 
            AND column_name = 'pdf_url'
            AND data_type = 'text'
        ) THEN
            -- Convert existing TEXT to JSONB (assuming single URL stored as string)
            ALTER TABLE course_units 
            ALTER COLUMN pdf_url TYPE JSONB USING 
                CASE 
                    WHEN pdf_url IS NULL OR pdf_url = '' THEN NULL::jsonb
                    ELSE to_jsonb(pdf_url)
                END;
        END IF;
    END IF;
END $$;

-- Enable Row Level Security
ALTER TABLE course_units ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Anyone can view course units" ON course_units;
DROP POLICY IF EXISTS "Admins can manage course units" ON course_units;

-- RLS Policies for course_units
CREATE POLICY "Anyone can view course units" 
    ON course_units FOR SELECT 
    USING (true);

CREATE POLICY "Admins can manage course units" 
    ON course_units FOR ALL 
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE profiles.id = auth.uid() 
            AND profiles.user_type = 'admin'
        )
    );

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_course_units_course_id ON course_units(course_id);
CREATE INDEX IF NOT EXISTS idx_course_units_order_index ON course_units(course_id, order_index);

-- Function to update students_count dynamically
CREATE OR REPLACE FUNCTION update_course_students_count()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE training_courses
    SET students_count = (
        SELECT COUNT(DISTINCT pilot_id)
        FROM course_enrollments
        WHERE course_id = NEW.course_id
    )
    WHERE id = NEW.course_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update students_count when enrollments change
DROP TRIGGER IF EXISTS trigger_update_students_count ON course_enrollments;
CREATE TRIGGER trigger_update_students_count
    AFTER INSERT OR DELETE ON course_enrollments
    FOR EACH ROW
    EXECUTE FUNCTION update_course_students_count();

-- Insert UAS Pilot Course
INSERT INTO training_courses (
    title,
    description,
    duration,
    level,
    category,
    instructor,
    rating,
    students_count,
    provider,
    instructor_picture_url
) VALUES (
    'UAS Pilot Course',
    'Comprehensive UAS (Unmanned Aircraft Systems) pilot training program covering mandatory ground school, base programs, extension courses, and advanced training.',
    '120 hours',
    'Beginner',
    'Flight Operations',
    'Buzz',
    4.95,
    0,
    'Buzz',
    NULL
) ON CONFLICT DO NOTHING;

-- Get the course ID for UAS Pilot Course (we'll use a fixed UUID for consistency)
DO $$
DECLARE
    uas_course_id UUID;
BEGIN
    -- Use a fixed UUID for the UAS Pilot Course
    uas_course_id := 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';
    
    -- Insert the course with the fixed UUID if it doesn't exist
    INSERT INTO training_courses (
        id,
        title,
        description,
        duration,
        level,
        category,
        instructor,
        rating,
        students_count,
        provider,
        instructor_picture_url
    ) VALUES (
        uas_course_id,
        'UAS Pilot Course',
        'Comprehensive UAS (Unmanned Aircraft Systems) pilot training program covering mandatory ground school, base programs, extension courses, and advanced training.',
        '120 hours',
        'Beginner',
        'Flight Operations',
        'Buzz',
        4.95,
        0,
        'Buzz',
        NULL
    ) ON CONFLICT (id) DO UPDATE SET
        title = EXCLUDED.title,
        description = EXCLUDED.description,
        duration = EXCLUDED.duration,
        level = EXCLUDED.level,
        category = EXCLUDED.category,
        instructor = EXCLUDED.instructor,
        rating = EXCLUDED.rating,
        provider = EXCLUDED.provider,
        updated_at = TIMEZONE('utc', NOW());
    
    -- Insert Mandatory Units (Step 0)
    INSERT INTO course_units (course_id, unit_number, title, description, step_number, is_mandatory, order_index) VALUES
    (uas_course_id, 1, 'UNIT 1 - GROUND SCHOOL', 'Fundamental ground school training covering regulations, airspace, and basic operations.', NULL, TRUE, 1),
    (uas_course_id, 2, 'UNIT 2 - HEALTH & SAFETY', 'Comprehensive health and safety protocols for UAS operations.', NULL, TRUE, 2),
    (uas_course_id, 3, 'UNIT 3 - OPERATIONS', 'Core operational procedures and best practices for UAS pilots.', NULL, TRUE, 3)
    ON CONFLICT (course_id, unit_number) DO NOTHING;
    
    -- Insert Step 1: Base Program Units
    INSERT INTO course_units (course_id, unit_number, title, description, step_number, is_mandatory, order_index) VALUES
    (uas_course_id, 4, 'UNIT 4 - DRONE PILOT', 'Comprehensive drone pilot training covering flight operations, maneuvers, and safety.', 1, FALSE, 4),
    (uas_course_id, 5, 'UNIT 5 - CAMERA/PAYLOAD OPERATOR', 'Training for camera and payload operators, covering equipment handling and operational procedures.', 1, FALSE, 5)
    ON CONFLICT (course_id, unit_number) DO NOTHING;
    
    -- Insert Step 2: Extension Courses
    INSERT INTO course_units (course_id, unit_number, title, description, step_number, is_mandatory, order_index) VALUES
    (uas_course_id, 6, 'UNIT 6 - DRONE BUSINESS', 'Learn how to start and manage a successful drone business.', 2, FALSE, 6),
    (uas_course_id, 7, 'UNIT 7 - FILM & AERIAL CINEMATOGRAPHY', 'Master aerial cinematography techniques for film production.', 2, FALSE, 7),
    (uas_course_id, 8, 'UNIT 8 - POST PRODUCTION', 'Post-production workflows and editing techniques for aerial footage.', 2, FALSE, 8),
    (uas_course_id, 9, 'UNIT 9 - REAL ESTATE', 'Specialized training for real estate photography and videography.', 2, FALSE, 9),
    (uas_course_id, 10, 'UNIT 10 - MAPPING & SURVEYING', 'Advanced mapping and surveying techniques using UAS technology.', 2, FALSE, 10),
    (uas_course_id, 11, 'UNIT 11 - INSPECTIONS', 'Professional inspection techniques for infrastructure and facilities.', 2, FALSE, 11),
    (uas_course_id, 12, 'UNIT 12 - SEARCH & RESCUE', 'Search and rescue operations using UAS technology.', 2, FALSE, 12)
    ON CONFLICT (course_id, unit_number) DO NOTHING;
    
    -- Insert Step 3: Further Base Training
    INSERT INTO course_units (course_id, unit_number, title, description, step_number, is_mandatory, order_index) VALUES
    (uas_course_id, 13, 'UNIT 13 - INTERMEDIATE DRONE PILOT', 'Intermediate level drone pilot training with advanced maneuvers.', 3, FALSE, 13),
    (uas_course_id, 14, 'UNIT 14 - INTERMEDIATE CAMERA/PAYLOAD OPERATOR', 'Intermediate camera and payload operations training.', 3, FALSE, 14),
    (uas_course_id, 15, 'UNIT 15 - ADVANCED DRONE PILOT', 'Advanced drone pilot certification with complex flight operations.', 3, FALSE, 15),
    (uas_course_id, 16, 'UNIT 16 - ADVANCED CAMERA/PAYLOAD OPERATOR', 'Advanced camera and payload operations certification.', 3, FALSE, 16),
    (uas_course_id, 17, 'UNIT 17 - SPECIALIZED SEARCH & RESCUE W/ THERMOGRAPHY', 'Specialized search and rescue training with thermal imaging technology.', 3, FALSE, 17),
    (uas_course_id, 18, 'UNIT 18 - SPECIALIZED POST PRODUCTION', 'Advanced post-production techniques and workflows.', 3, FALSE, 18),
    (uas_course_id, 19, 'UNIT 19 - DRONE REPAIR TECHNICIAN/ENGR', 'Technical training for drone repair and engineering.', 3, FALSE, 19),
    (uas_course_id, 20, 'UNIT 20 - PUBLIC SAFETY PILOT', 'Public safety pilot certification for emergency response operations.', 3, FALSE, 20)
    ON CONFLICT (course_id, unit_number) DO NOTHING;
END $$;

