-- Buzz App - Supabase Database Schema
-- Run this SQL in your Supabase SQL Editor to set up the database

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Profiles Table
CREATE TABLE profiles (
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

-- Pilot Licenses Table
CREATE TABLE pilot_licenses (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    pilot_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    file_url TEXT NOT NULL,
    file_type TEXT NOT NULL CHECK (file_type IN ('pdf', 'image')),
    uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()) NOT NULL
);

-- Enable Row Level Security
ALTER TABLE pilot_licenses ENABLE ROW LEVEL SECURITY;

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

-- Bookings Table
CREATE TABLE bookings (
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

-- Enable Row Level Security
ALTER TABLE bookings ENABLE ROW LEVEL SECURITY;

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

-- Pilot Stats Table
CREATE TABLE pilot_stats (
    pilot_id UUID REFERENCES profiles(id) ON DELETE CASCADE PRIMARY KEY,
    total_flight_hours DOUBLE PRECISION DEFAULT 0.0 NOT NULL,
    completed_bookings INTEGER DEFAULT 0 NOT NULL,
    tier INTEGER DEFAULT 0 NOT NULL CHECK (tier >= 0 AND tier <= 4)
);

-- Enable Row Level Security
ALTER TABLE pilot_stats ENABLE ROW LEVEL SECURITY;

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

-- Create Storage Bucket for Pilot Licenses
INSERT INTO storage.buckets (id, name, public)
VALUES ('pilot-licenses', 'pilot-licenses', true);

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

-- Storage Buckets for Profile Pictures
-- Create the profile-pictures bucket
INSERT INTO storage.buckets (id, name, public)
VALUES ('profile-pictures', 'profile-pictures', true)
ON CONFLICT (id) DO NOTHING;

-- Profile Pictures Storage Policies
CREATE POLICY "Users can view all profile pictures"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'profile-pictures');

CREATE POLICY "Users can upload their own profile picture"
    ON storage.objects FOR INSERT
    WITH CHECK (
        bucket_id = 'profile-pictures' 
        AND auth.uid()::text = (storage.foldername(name))[1]
    );

CREATE POLICY "Users can update their own profile picture"
    ON storage.objects FOR UPDATE
    USING (
        bucket_id = 'profile-pictures' 
        AND auth.uid()::text = (storage.foldername(name))[1]
    );

CREATE POLICY "Users can delete their own profile picture"
    ON storage.objects FOR DELETE
    USING (
        bucket_id = 'profile-pictures' 
        AND auth.uid()::text = (storage.foldername(name))[1]
    );

-- Ratings Table
CREATE TABLE ratings (
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

-- Ratings Policies
CREATE POLICY "Ratings are viewable by authenticated users"
    ON ratings FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Users can insert their own ratings"
    ON ratings FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = from_user_id);

-- Create indexes for better performance
CREATE INDEX idx_bookings_status ON bookings(status);
CREATE INDEX idx_bookings_customer_id ON bookings(customer_id);
CREATE INDEX idx_bookings_pilot_id ON bookings(pilot_id);
CREATE INDEX idx_pilot_licenses_pilot_id ON pilot_licenses(pilot_id);
CREATE INDEX idx_pilot_stats_tier ON pilot_stats(tier);
CREATE INDEX idx_pilot_stats_flight_hours ON pilot_stats(total_flight_hours DESC);
CREATE INDEX idx_ratings_to_user_id ON ratings(to_user_id);
CREATE INDEX idx_ratings_booking_id ON ratings(booking_id);

