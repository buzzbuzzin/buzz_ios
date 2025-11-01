-- Migration Script: Add Communication Preference to Profiles
-- Run this SQL in your Supabase SQL Editor if you already have the database set up

-- Add communication_preference column
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS communication_preference TEXT CHECK (communication_preference IN ('email', 'text', 'both')) DEFAULT 'email';

-- Verify the changes
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'profiles' 
AND column_name = 'communication_preference';

