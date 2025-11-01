-- Migration Script: Add Scheduled Date and Specialization to Bookings
-- Run this SQL in your Supabase SQL Editor if you already have the database set up

-- Add scheduled_date column
ALTER TABLE bookings 
ADD COLUMN IF NOT EXISTS scheduled_date TIMESTAMP WITH TIME ZONE;

-- Add specialization column
ALTER TABLE bookings 
ADD COLUMN IF NOT EXISTS specialization TEXT;

-- Add check constraint for specialization values
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'bookings_specialization_check'
    ) THEN
        ALTER TABLE bookings 
        ADD CONSTRAINT bookings_specialization_check 
        CHECK (specialization IS NULL OR specialization IN (
            'automotive', 
            'motion_picture', 
            'real_estate', 
            'agriculture', 
            'inspections', 
            'search_rescue', 
            'logistics', 
            'drone_art', 
            'surveillance_security'
        ));
    END IF;
END $$;

-- Verify the changes
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'bookings' 
AND column_name IN ('scheduled_date', 'specialization')
ORDER BY column_name;

