-- Migration Script: Add First Name, Last Name, and Profile Picture to Profiles
-- Run this SQL in your Supabase SQL Editor if you already have the database set up

-- Add first_name column
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS first_name TEXT;

-- Add last_name column  
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS last_name TEXT;

-- Add profile_picture_url column
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS profile_picture_url TEXT;

-- Verify the changes
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'profiles'
ORDER BY ordinal_position;

