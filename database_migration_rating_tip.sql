-- Migration Script: Add Rating System and Tips
-- Run this SQL in your Supabase SQL Editor if you already have the database set up

-- Add tip_amount column to bookings
ALTER TABLE bookings 
ADD COLUMN IF NOT EXISTS tip_amount DECIMAL(10, 2) DEFAULT 0;

-- Add rating status columns
ALTER TABLE bookings 
ADD COLUMN IF NOT EXISTS pilot_rated BOOLEAN DEFAULT FALSE;

ALTER TABLE bookings 
ADD COLUMN IF NOT EXISTS customer_rated BOOLEAN DEFAULT FALSE;

-- Create Ratings Table
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

-- Ratings Policies
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'ratings' 
        AND policyname = 'Ratings are viewable by authenticated users'
    ) THEN
        CREATE POLICY "Ratings are viewable by authenticated users"
            ON ratings FOR SELECT
            TO authenticated
            USING (true);
    END IF;
END $$;

DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'ratings' 
        AND policyname = 'Users can insert their own ratings'
    ) THEN
        CREATE POLICY "Users can insert their own ratings"
            ON ratings FOR INSERT
            TO authenticated
            WITH CHECK (auth.uid() = from_user_id);
    END IF;
END $$;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_ratings_to_user_id ON ratings(to_user_id);
CREATE INDEX IF NOT EXISTS idx_ratings_booking_id ON ratings(booking_id);

-- Verify the changes
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'bookings' 
AND column_name IN ('tip_amount', 'pilot_rated', 'customer_rated')
ORDER BY column_name;

SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'ratings'
ORDER BY ordinal_position;

