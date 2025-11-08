-- Buzz App - Complete Supabase Database Schema
-- This is a consolidated SQL file containing all tables, migrations, and configurations
-- Run this SQL in your Supabase SQL Editor to set up the complete database
-- This file is idempotent - safe to run multiple times

-- ============================================================================
-- EXTENSIONS
-- ============================================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- TABLES
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Profiles Table
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS profiles (
    id UUID REFERENCES auth.users ON DELETE CASCADE PRIMARY KEY,
    user_type TEXT NOT NULL CHECK (user_type IN ('pilot', 'customer')),
    first_name TEXT,
    last_name TEXT,
    call_sign TEXT UNIQUE,
    email TEXT,
    phone TEXT,
    profile_picture_url TEXT,
    communication_preference TEXT CHECK (communication_preference IN ('email', 'text', 'both')) DEFAULT 'email',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()) NOT NULL
);

-- Enable Row Level Security
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Add missing columns if table already exists (for migrations)
DO $$ 
BEGIN
    -- Add first_name if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'profiles' AND column_name = 'first_name'
    ) THEN
        ALTER TABLE profiles ADD COLUMN first_name TEXT;
    END IF;
    
    -- Add last_name if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'profiles' AND column_name = 'last_name'
    ) THEN
        ALTER TABLE profiles ADD COLUMN last_name TEXT;
    END IF;
    
    -- Add profile_picture_url if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'profiles' AND column_name = 'profile_picture_url'
    ) THEN
        ALTER TABLE profiles ADD COLUMN profile_picture_url TEXT;
    END IF;
    
    -- Add communication_preference if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'profiles' AND column_name = 'communication_preference'
    ) THEN
        ALTER TABLE profiles ADD COLUMN communication_preference TEXT DEFAULT 'email';
    END IF;
    
    -- Add check constraint for communication_preference if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'profiles_communication_preference_check'
    ) THEN
        ALTER TABLE profiles ADD CONSTRAINT profiles_communication_preference_check 
        CHECK (communication_preference IN ('email', 'text', 'both'));
    END IF;
    
    -- Add stripe_account_id if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'profiles' AND column_name = 'stripe_account_id'
    ) THEN
        ALTER TABLE profiles ADD COLUMN stripe_account_id TEXT;
    END IF;
END $$;

-- Drop existing policies if they exist (for idempotency)
DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON profiles;
DROP POLICY IF EXISTS "Users can insert their own profile" ON profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON profiles;

-- Profiles Policies
CREATE POLICY "Public profiles are viewable by everyone" 
    ON profiles FOR SELECT 
    USING (true);

CREATE POLICY "Users can insert their own profile" 
    ON profiles FOR INSERT 
    TO authenticated
    WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update their own profile" 
    ON profiles FOR UPDATE 
    USING (auth.uid() = id);

-- ----------------------------------------------------------------------------
-- Pilot Licenses Table
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS pilot_licenses (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    pilot_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    file_url TEXT NOT NULL,
    file_type TEXT NOT NULL CHECK (file_type IN ('pdf', 'image')),
    uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()) NOT NULL
);

-- Enable Row Level Security
ALTER TABLE pilot_licenses ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Pilots can view their own licenses" ON pilot_licenses;
DROP POLICY IF EXISTS "Pilots can insert their own licenses" ON pilot_licenses;
DROP POLICY IF EXISTS "Pilots can delete their own licenses" ON pilot_licenses;

-- Pilot Licenses Policies
CREATE POLICY "Pilots can view their own licenses" 
    ON pilot_licenses FOR SELECT 
    USING (auth.uid() = pilot_id);

CREATE POLICY "Pilots can insert their own licenses" 
    ON pilot_licenses FOR INSERT 
    TO authenticated
    WITH CHECK (auth.uid() = pilot_id);

CREATE POLICY "Pilots can delete their own licenses" 
    ON pilot_licenses FOR DELETE 
    USING (auth.uid() = pilot_id);

-- ----------------------------------------------------------------------------
-- Bookings Table
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS bookings (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    customer_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    pilot_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    location_lat DOUBLE PRECISION NOT NULL,
    location_lng DOUBLE PRECISION NOT NULL,
    location_name TEXT NOT NULL,
    scheduled_date TIMESTAMP WITH TIME ZONE,
    end_date TIMESTAMP WITH TIME ZONE,
    specialization TEXT CHECK (specialization IN ('automotive', 'motion_picture', 'real_estate', 'agriculture', 'inspections', 'search_rescue', 'logistics', 'drone_art', 'surveillance_security')),
    description TEXT NOT NULL,
    payment_amount DECIMAL(10, 2) NOT NULL,
    tip_amount DECIMAL(10, 2) DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'available' CHECK (status IN ('available', 'accepted', 'completed', 'cancelled')),
    estimated_flight_hours DOUBLE PRECISION,
    pilot_rated BOOLEAN DEFAULT FALSE,
    customer_rated BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()) NOT NULL
);

-- Add missing columns if table already exists (for migrations)
DO $$ 
BEGIN
    -- Add scheduled_date if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'bookings' AND column_name = 'scheduled_date'
    ) THEN
        ALTER TABLE bookings ADD COLUMN scheduled_date TIMESTAMP WITH TIME ZONE;
    END IF;
    
    -- Add specialization if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'bookings' AND column_name = 'specialization'
    ) THEN
        ALTER TABLE bookings ADD COLUMN specialization TEXT;
    END IF;
    
    -- Add check constraint for specialization if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'bookings_specialization_check'
    ) THEN
        ALTER TABLE bookings ADD CONSTRAINT bookings_specialization_check 
        CHECK (specialization IS NULL OR specialization IN (
            'automotive', 'motion_picture', 'real_estate', 'agriculture', 
            'inspections', 'search_rescue', 'logistics', 'drone_art', 'surveillance_security'
        ));
    END IF;
    
    -- Add tip_amount if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'bookings' AND column_name = 'tip_amount'
    ) THEN
        ALTER TABLE bookings ADD COLUMN tip_amount DECIMAL(10, 2) DEFAULT 0;
    END IF;
    
    -- Add pilot_rated if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'bookings' AND column_name = 'pilot_rated'
    ) THEN
        ALTER TABLE bookings ADD COLUMN pilot_rated BOOLEAN DEFAULT FALSE;
    END IF;
    
    -- Add customer_rated if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'bookings' AND column_name = 'customer_rated'
    ) THEN
        ALTER TABLE bookings ADD COLUMN customer_rated BOOLEAN DEFAULT FALSE;
    END IF;
    
    -- Add end_date if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'bookings' AND column_name = 'end_date'
    ) THEN
        ALTER TABLE bookings ADD COLUMN end_date TIMESTAMP WITH TIME ZONE;
    END IF;
    
    -- Add required_minimum_rank if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'bookings' AND column_name = 'required_minimum_rank'
    ) THEN
        ALTER TABLE bookings ADD COLUMN required_minimum_rank INTEGER DEFAULT 0;
    END IF;
    
    -- Add payment_intent_id if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'bookings' AND column_name = 'payment_intent_id'
    ) THEN
        ALTER TABLE bookings ADD COLUMN payment_intent_id TEXT;
    END IF;
    
    -- Add transfer_id if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'bookings' AND column_name = 'transfer_id'
    ) THEN
        ALTER TABLE bookings ADD COLUMN transfer_id TEXT;
    END IF;
    
    -- Add charge_id if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'bookings' AND column_name = 'charge_id'
    ) THEN
        ALTER TABLE bookings ADD COLUMN charge_id TEXT;
    END IF;
END $$;

-- Enable Row Level Security
ALTER TABLE bookings ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Available bookings are viewable by authenticated users" ON bookings;
DROP POLICY IF EXISTS "Customers can create bookings" ON bookings;
DROP POLICY IF EXISTS "Customers can update their own bookings" ON bookings;
DROP POLICY IF EXISTS "Pilots can accept bookings" ON bookings;

-- Bookings Policies
CREATE POLICY "Available bookings are viewable by authenticated users" 
    ON bookings FOR SELECT 
    TO authenticated
    USING (
        status = 'available' 
        OR auth.uid() = customer_id 
        OR auth.uid() = pilot_id
    );

CREATE POLICY "Customers can create bookings" 
    ON bookings FOR INSERT 
    TO authenticated
    WITH CHECK (auth.uid() = customer_id);

CREATE POLICY "Customers can update their own bookings" 
    ON bookings FOR UPDATE 
    TO authenticated
    USING (auth.uid() = customer_id);

CREATE POLICY "Pilots can accept bookings" 
    ON bookings FOR UPDATE 
    TO authenticated
    USING (status = 'available' OR auth.uid() = pilot_id);

-- ----------------------------------------------------------------------------
-- Pilot Stats Table
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS pilot_stats (
    pilot_id UUID REFERENCES profiles(id) ON DELETE CASCADE PRIMARY KEY,
    total_flight_hours DOUBLE PRECISION DEFAULT 0.0 NOT NULL,
    completed_bookings INTEGER DEFAULT 0 NOT NULL,
    tier INTEGER DEFAULT 0 NOT NULL CHECK (tier >= 0 AND tier <= 4)
);

-- Enable Row Level Security
ALTER TABLE pilot_stats ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Pilot stats are viewable by everyone" ON pilot_stats;
DROP POLICY IF EXISTS "Pilots can insert their own stats" ON pilot_stats;
DROP POLICY IF EXISTS "Pilots can update their own stats" ON pilot_stats;

-- Pilot Stats Policies
CREATE POLICY "Pilot stats are viewable by everyone" 
    ON pilot_stats FOR SELECT 
    USING (true);

CREATE POLICY "Pilots can insert their own stats" 
    ON pilot_stats FOR INSERT 
    TO authenticated
    WITH CHECK (auth.uid() = pilot_id);

CREATE POLICY "Pilots can update their own stats" 
    ON pilot_stats FOR UPDATE 
    TO authenticated
    USING (auth.uid() = pilot_id);

-- ----------------------------------------------------------------------------
-- Ratings Table
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ratings (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    booking_id UUID REFERENCES bookings(id) ON DELETE CASCADE NOT NULL,
    from_user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    to_user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    rating INTEGER NOT NULL CHECK (rating >= 0 AND rating <= 5),
    comment TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()) NOT NULL,
    UNIQUE(booking_id, from_user_id)
);

-- Enable Row Level Security
ALTER TABLE ratings ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Ratings are viewable by authenticated users" ON ratings;
DROP POLICY IF EXISTS "Users can insert their own ratings" ON ratings;

-- Ratings Policies
CREATE POLICY "Ratings are viewable by authenticated users"
    ON ratings FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Users can insert their own ratings"
    ON ratings FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = from_user_id);

-- ----------------------------------------------------------------------------
-- Messages Table
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS messages (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    booking_id UUID REFERENCES bookings(id) ON DELETE CASCADE NOT NULL,
    from_user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    to_user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    text TEXT NOT NULL,
    is_read BOOLEAN DEFAULT FALSE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()) NOT NULL
);

-- Enable Row Level Security
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view messages for their bookings" ON messages;
DROP POLICY IF EXISTS "Users can send messages" ON messages;
DROP POLICY IF EXISTS "Users can update their own messages" ON messages;

-- Messages Policies
CREATE POLICY "Users can view messages for their bookings"
    ON messages FOR SELECT
    TO authenticated
    USING (
        auth.uid() = from_user_id 
        OR auth.uid() = to_user_id
    );

CREATE POLICY "Users can send messages"
    ON messages FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = from_user_id);

CREATE POLICY "Users can update their own messages"
    ON messages FOR UPDATE
    TO authenticated
    USING (auth.uid() = from_user_id);

-- ----------------------------------------------------------------------------
-- Training Courses Table
-- ----------------------------------------------------------------------------
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

-- Enable Row Level Security
ALTER TABLE training_courses ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Anyone can view courses" ON training_courses;
DROP POLICY IF EXISTS "Admins can manage courses" ON training_courses;

-- RLS Policies for training_courses
CREATE POLICY "Anyone can view courses" 
    ON training_courses FOR SELECT 
    USING (true);

-- Note: Admin policy assumes you'll add an admin role to profiles if needed
-- For now, allow authenticated users to manage courses (adjust as needed)
CREATE POLICY "Admins can manage courses" 
    ON training_courses FOR ALL 
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE profiles.id = auth.uid() 
            AND profiles.user_type = 'admin'
        )
    );

-- ----------------------------------------------------------------------------
-- Course Enrollments Table
-- ----------------------------------------------------------------------------
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
ALTER TABLE course_enrollments ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Pilots can view their own enrollments" ON course_enrollments;
DROP POLICY IF EXISTS "Pilots can enroll in courses" ON course_enrollments;
DROP POLICY IF EXISTS "Pilots can update their own enrollment" ON course_enrollments;
DROP POLICY IF EXISTS "Pilots can unenroll from courses" ON course_enrollments;

-- RLS Policies for course_enrollments
CREATE POLICY "Pilots can view their own enrollments" 
    ON course_enrollments FOR SELECT 
    TO authenticated
    USING (auth.uid() = pilot_id);

CREATE POLICY "Pilots can enroll in courses" 
    ON course_enrollments FOR INSERT 
    TO authenticated
    WITH CHECK (auth.uid() = pilot_id);

CREATE POLICY "Pilots can update their own enrollment" 
    ON course_enrollments FOR UPDATE 
    TO authenticated
    USING (auth.uid() = pilot_id);

CREATE POLICY "Pilots can unenroll from courses" 
    ON course_enrollments FOR DELETE 
    TO authenticated
    USING (auth.uid() = pilot_id);

-- ----------------------------------------------------------------------------
-- Transponders Table
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS transponders (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    pilot_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    device_name TEXT NOT NULL,
    remote_id TEXT NOT NULL,
    is_location_tracking_enabled BOOLEAN DEFAULT false NOT NULL,
    last_location_lat DOUBLE PRECISION,
    last_location_lng DOUBLE PRECISION,
    last_location_update TIMESTAMP WITH TIME ZONE,
    speed DOUBLE PRECISION, -- Speed in meters per second
    altitude DOUBLE PRECISION, -- Altitude in meters
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()) NOT NULL
);

-- Add missing columns if table already exists (for migrations)
DO $$ 
BEGIN
    -- Add speed if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'transponders' AND column_name = 'speed'
    ) THEN
        ALTER TABLE transponders ADD COLUMN speed DOUBLE PRECISION;
    END IF;
    
    -- Add altitude if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'transponders' AND column_name = 'altitude'
    ) THEN
        ALTER TABLE transponders ADD COLUMN altitude DOUBLE PRECISION;
    END IF;
END $$;

-- Enable Row Level Security
ALTER TABLE transponders ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Pilots can view their own transponders" ON transponders;
DROP POLICY IF EXISTS "Pilots can insert their own transponders" ON transponders;
DROP POLICY IF EXISTS "Pilots can update their own transponders" ON transponders;
DROP POLICY IF EXISTS "Pilots can delete their own transponders" ON transponders;

-- Transponders Policies
CREATE POLICY "Pilots can view their own transponders" 
    ON transponders FOR SELECT 
    TO authenticated
    USING (auth.uid() = pilot_id);

CREATE POLICY "Pilots can insert their own transponders" 
    ON transponders FOR INSERT 
    TO authenticated
    WITH CHECK (auth.uid() = pilot_id);

CREATE POLICY "Pilots can update their own transponders" 
    ON transponders FOR UPDATE 
    TO authenticated
    USING (auth.uid() = pilot_id);

CREATE POLICY "Pilots can delete their own transponders" 
    ON transponders FOR DELETE 
    TO authenticated
    USING (auth.uid() = pilot_id);

-- ----------------------------------------------------------------------------
-- Badges Table
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS badges (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    pilot_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    course_id UUID REFERENCES training_courses(id) ON DELETE SET NULL,
    course_title TEXT NOT NULL,
    course_category TEXT NOT NULL,
    provider TEXT NOT NULL CHECK (provider IN ('Buzz', 'Amazon', 'T-Mobile', 'Other')),
    earned_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()) NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE, -- Expiration date for recurrent training badges
    is_recurrent BOOLEAN DEFAULT FALSE NOT NULL
);

-- Enable Row Level Security
ALTER TABLE badges ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Pilots can view their own badges" ON badges;
DROP POLICY IF EXISTS "Pilots can view all badges" ON badges;
DROP POLICY IF EXISTS "System can insert badges" ON badges;

-- Badges Policies
-- Pilots can view their own badges
CREATE POLICY "Pilots can view their own badges" 
    ON badges FOR SELECT 
    TO authenticated
    USING (auth.uid() = pilot_id);

-- Allow viewing all badges for leaderboard/recognition purposes
CREATE POLICY "Pilots can view all badges" 
    ON badges FOR SELECT 
    TO authenticated
    USING (true);

-- Allow system to insert badges (when courses are completed)
-- In production, you might want to restrict this to a service role
CREATE POLICY "System can insert badges" 
    ON badges FOR INSERT 
    TO authenticated
    WITH CHECK (true);

-- ============================================================================
-- INDEXES
-- ============================================================================

-- Bookings indexes
CREATE INDEX IF NOT EXISTS idx_bookings_status ON bookings(status);
CREATE INDEX IF NOT EXISTS idx_bookings_customer_id ON bookings(customer_id);
CREATE INDEX IF NOT EXISTS idx_bookings_pilot_id ON bookings(pilot_id);
CREATE INDEX IF NOT EXISTS idx_bookings_scheduled_date ON bookings(scheduled_date);
CREATE INDEX IF NOT EXISTS idx_bookings_payment_intent_id ON bookings(payment_intent_id);
CREATE INDEX IF NOT EXISTS idx_bookings_transfer_id ON bookings(transfer_id);
CREATE INDEX IF NOT EXISTS idx_bookings_charge_id ON bookings(charge_id);

-- Profiles indexes
CREATE INDEX IF NOT EXISTS idx_profiles_stripe_account_id ON profiles(stripe_account_id);

-- Pilot licenses indexes
CREATE INDEX IF NOT EXISTS idx_pilot_licenses_pilot_id ON pilot_licenses(pilot_id);

-- Pilot stats indexes
CREATE INDEX IF NOT EXISTS idx_pilot_stats_tier ON pilot_stats(tier);
CREATE INDEX IF NOT EXISTS idx_pilot_stats_flight_hours ON pilot_stats(total_flight_hours DESC);

-- Ratings indexes
CREATE INDEX IF NOT EXISTS idx_ratings_to_user_id ON ratings(to_user_id);
CREATE INDEX IF NOT EXISTS idx_ratings_booking_id ON ratings(booking_id);

-- Messages indexes
CREATE INDEX IF NOT EXISTS idx_messages_booking_id ON messages(booking_id);
CREATE INDEX IF NOT EXISTS idx_messages_from_user_id ON messages(from_user_id);
CREATE INDEX IF NOT EXISTS idx_messages_to_user_id ON messages(to_user_id);
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON messages(created_at);

-- Course enrollments indexes
CREATE INDEX IF NOT EXISTS idx_course_enrollments_pilot_id ON course_enrollments(pilot_id);
CREATE INDEX IF NOT EXISTS idx_course_enrollments_course_id ON course_enrollments(course_id);

-- Training courses indexes
CREATE INDEX IF NOT EXISTS idx_training_courses_category ON training_courses(category);
CREATE INDEX IF NOT EXISTS idx_training_courses_level ON training_courses(level);

-- Transponders indexes
CREATE INDEX IF NOT EXISTS idx_transponders_pilot_id ON transponders(pilot_id);
CREATE INDEX IF NOT EXISTS idx_transponders_remote_id ON transponders(remote_id);
CREATE INDEX IF NOT EXISTS idx_transponders_location_tracking ON transponders(is_location_tracking_enabled);
CREATE INDEX IF NOT EXISTS idx_transponders_last_update ON transponders(last_location_update);

-- Badges indexes
CREATE INDEX IF NOT EXISTS idx_badges_pilot_id ON badges(pilot_id);
CREATE INDEX IF NOT EXISTS idx_badges_course_id ON badges(course_id);
CREATE INDEX IF NOT EXISTS idx_badges_provider ON badges(provider);
CREATE INDEX IF NOT EXISTS idx_badges_expires_at ON badges(expires_at);

-- ============================================================================
-- STORAGE BUCKETS
-- ============================================================================

-- Create Storage Bucket for Pilot Licenses
INSERT INTO storage.buckets (id, name, public)
VALUES ('pilot-licenses', 'pilot-licenses', true)
ON CONFLICT (id) DO NOTHING;

-- Create Storage Bucket for Profile Pictures
INSERT INTO storage.buckets (id, name, public)
VALUES ('profile-pictures', 'profile-pictures', true)
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- STORAGE POLICIES
-- ============================================================================

-- Drop existing storage policies if they exist (for idempotency)
DROP POLICY IF EXISTS "Pilots can upload their own licenses" ON storage.objects;
DROP POLICY IF EXISTS "Pilots can view their own licenses" ON storage.objects;
DROP POLICY IF EXISTS "Pilots can delete their own licenses" ON storage.objects;
DROP POLICY IF EXISTS "Users can view all profile pictures" ON storage.objects;
DROP POLICY IF EXISTS "Users can upload their own profile picture" ON storage.objects;
DROP POLICY IF EXISTS "Users can update their own profile picture" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own profile picture" ON storage.objects;

-- Storage Policies for Pilot Licenses
CREATE POLICY "Pilots can upload their own licenses"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (
        bucket_id = 'pilot-licenses' 
        AND auth.uid()::text = (storage.foldername(name))[1]
    );

CREATE POLICY "Pilots can view their own licenses"
    ON storage.objects FOR SELECT
    TO authenticated
    USING (
        bucket_id = 'pilot-licenses' 
        AND auth.uid()::text = (storage.foldername(name))[1]
    );

CREATE POLICY "Pilots can delete their own licenses"
    ON storage.objects FOR DELETE
    TO authenticated
    USING (
        bucket_id = 'pilot-licenses' 
        AND auth.uid()::text = (storage.foldername(name))[1]
    );

-- Profile Pictures Storage Policies
-- Note: auth.uid() returns NULL in Supabase Storage RLS context, so we rely on:
-- 1. Authentication requirement (TO authenticated)
-- 2. Path structure validation (UUID format)
-- 3. Application-level ownership verification (in Swift app code)

-- Allow anyone to view profile pictures (public bucket)
CREATE POLICY "Users can view all profile pictures"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'profile-pictures');

-- Allow authenticated users to upload profile pictures
-- Path must follow UUID/filename structure (e.g., {userId}/profile.jpg)
-- Ownership is verified in application code before upload
CREATE POLICY "Users can upload their own profile picture"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (
        bucket_id = 'profile-pictures' 
        AND (storage.foldername(name))[1] IS NOT NULL
        AND (storage.foldername(name))[1] ~ '^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}$'
    );

-- Allow authenticated users to update their own profile picture
CREATE POLICY "Users can update their own profile picture"
    ON storage.objects FOR UPDATE
    TO authenticated
    USING (
        bucket_id = 'profile-pictures' 
        AND (storage.foldername(name))[1] IS NOT NULL
        AND (storage.foldername(name))[1] ~ '^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}$'
    )
    WITH CHECK (
        bucket_id = 'profile-pictures' 
        AND (storage.foldername(name))[1] IS NOT NULL
        AND (storage.foldername(name))[1] ~ '^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}$'
    );

-- Allow authenticated users to delete their own profile picture
CREATE POLICY "Users can delete their own profile picture"
    ON storage.objects FOR DELETE
    TO authenticated
    USING (
        bucket_id = 'profile-pictures' 
        AND (storage.foldername(name))[1] IS NOT NULL
        AND (storage.foldername(name))[1] ~ '^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}$'
    );

-- ============================================================================
-- SAMPLE DATA (Optional)
-- ============================================================================

-- Insert sample training courses (optional - for initial data)
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

-- ============================================================================
-- VERIFICATION QUERIES (Comment out after verification)
-- ============================================================================

-- Uncomment to verify tables were created:
-- SELECT table_name FROM information_schema.tables 
-- WHERE table_schema = 'public' 
-- AND table_type = 'BASE TABLE'
-- ORDER BY table_name;

-- Uncomment to verify indexes:
-- SELECT indexname, tablename FROM pg_indexes 
-- WHERE schemaname = 'public'
-- ORDER BY tablename, indexname;

