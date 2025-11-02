-- Academy/Training Courses Database Schema
-- Run this SQL script in your Supabase SQL Editor to create the tables

-- Training Courses Table
CREATE TABLE IF NOT EXISTS training_courses (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    duration TEXT NOT NULL,
    level TEXT NOT NULL CHECK (level IN ('Beginner', 'Intermediate', 'Advanced')),
    category TEXT NOT NULL CHECK (category IN ('Safety & Regulations', 'Flight Operations', 'Aerial Photography', 'Cinematography', 'Inspections', 'Mapping & Surveying')),
    instructor TEXT NOT NULL,
    rating DOUBLE PRECISION DEFAULT 0.0,
    students_count INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()) NOT NULL
);

-- Course Enrollments Table (tracks which pilots are enrolled in which courses)
CREATE TABLE IF NOT EXISTS course_enrollments (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    pilot_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    course_id UUID REFERENCES training_courses(id) ON DELETE CASCADE NOT NULL,
    enrolled_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()) NOT NULL,
    completed_at TIMESTAMP WITH TIME ZONE,
    progress_percentage INTEGER DEFAULT 0 CHECK (progress_percentage >= 0 AND progress_percentage <= 100),
    UNIQUE(pilot_id, course_id)
);

-- Enable Row Level Security
ALTER TABLE training_courses ENABLE ROW LEVEL SECURITY;
ALTER TABLE course_enrollments ENABLE ROW LEVEL SECURITY;

-- RLS Policies for training_courses
-- Everyone can view courses
CREATE POLICY "Anyone can view courses" 
    ON training_courses FOR SELECT 
    USING (true);

-- Only authenticated admins can insert/update/delete courses (adjust based on your needs)
CREATE POLICY "Admins can manage courses" 
    ON training_courses FOR ALL 
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE profiles.id = auth.uid() 
            AND profiles.user_type = 'admin' -- Add admin role if needed
        )
    );

-- RLS Policies for course_enrollments
-- Pilots can view their own enrollments
CREATE POLICY "Pilots can view their own enrollments" 
    ON course_enrollments FOR SELECT 
    TO authenticated
    USING (auth.uid() = pilot_id);

-- Pilots can enroll themselves
CREATE POLICY "Pilots can enroll in courses" 
    ON course_enrollments FOR INSERT 
    TO authenticated
    WITH CHECK (auth.uid() = pilot_id);

-- Pilots can update their own enrollment progress
CREATE POLICY "Pilots can update their own enrollment" 
    ON course_enrollments FOR UPDATE 
    TO authenticated
    USING (auth.uid() = pilot_id);

-- Pilots can unenroll themselves
CREATE POLICY "Pilots can unenroll from courses" 
    ON course_enrollments FOR DELETE 
    TO authenticated
    USING (auth.uid() = pilot_id);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_course_enrollments_pilot_id ON course_enrollments(pilot_id);
CREATE INDEX IF NOT EXISTS idx_course_enrollments_course_id ON course_enrollments(course_id);
CREATE INDEX IF NOT EXISTS idx_training_courses_category ON training_courses(category);
CREATE INDEX IF NOT EXISTS idx_training_courses_level ON training_courses(level);

-- Insert sample courses (optional - for initial data)
INSERT INTO training_courses (title, description, duration, level, category, instructor, rating, students_count) VALUES
('FAA Part 107 Certification Prep', 'Comprehensive course covering all aspects of FAA Part 107 regulations, airspace, weather, and operational safety.', '40 hours', 'Beginner', 'Safety & Regulations', 'John Smith', 4.8, 1250),
('Advanced Flight Maneuvers', 'Master complex flight patterns, precision flying, and emergency procedures for professional drone operations.', '20 hours', 'Advanced', 'Flight Operations', 'Sarah Johnson', 4.9, 890),
('Aerial Photography Mastery', 'Learn composition, lighting, camera settings, and post-processing techniques for stunning aerial photographs.', '30 hours', 'Intermediate', 'Aerial Photography', 'Mike Chen', 4.7, 2100),
('Cinematic Drone Videography', 'Create cinematic drone videos with smooth movements, color grading, and professional editing workflows.', '35 hours', 'Intermediate', 'Cinematography', 'Emily Davis', 4.9, 1560),
('Infrastructure Inspection Techniques', 'Professional inspection methods for bridges, buildings, power lines, and industrial facilities using drones.', '25 hours', 'Advanced', 'Inspections', 'Robert Taylor', 4.6, 750),
('3D Mapping & Surveying', 'Learn photogrammetry, LiDAR integration, and create accurate 3D models and maps for surveying applications.', '28 hours', 'Advanced', 'Mapping & Surveying', 'Lisa Anderson', 4.8, 920),
('Weather & Risk Assessment', 'Understand weather patterns, wind conditions, and risk management for safe drone operations.', '15 hours', 'Beginner', 'Safety & Regulations', 'David Wilson', 4.5, 1340),
('Night Operations & Lighting', 'Safe operations after sunset, required lighting, and special considerations for night flights.', '12 hours', 'Intermediate', 'Flight Operations', 'Jessica Martinez', 4.7, 680)
ON CONFLICT DO NOTHING;

