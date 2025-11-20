-- Migration: Add veteran verification fields to profiles table
-- Run this SQL in your Supabase SQL Editor

-- ============================================================================
-- Add veteran verification fields
-- ============================================================================

DO $$ 
BEGIN
    -- Add veteran_service_name field (Full name on service/veteran card)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'profiles' AND column_name = 'veteran_service_name'
    ) THEN
        ALTER TABLE profiles ADD COLUMN veteran_service_name TEXT;
    END IF;
    
    -- Add veteran_service_country field
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'profiles' AND column_name = 'veteran_service_country'
    ) THEN
        ALTER TABLE profiles ADD COLUMN veteran_service_country TEXT;
    END IF;
    
    -- Add veteran_military_branch field
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'profiles' AND column_name = 'veteran_military_branch'
    ) THEN
        ALTER TABLE profiles ADD COLUMN veteran_military_branch TEXT;
    END IF;
    
    -- Add veteran_service_number field
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'profiles' AND column_name = 'veteran_service_number'
    ) THEN
        ALTER TABLE profiles ADD COLUMN veteran_service_number TEXT;
    END IF;
END $$;

-- Add comments for documentation
COMMENT ON COLUMN profiles.veteran_service_name IS 'Full name as it appears on service/veteran card';
COMMENT ON COLUMN profiles.veteran_service_country IS 'Country where the user served in the military';
COMMENT ON COLUMN profiles.veteran_military_branch IS 'Military branch (Army, Navy, Air Force, Marine Corps, Coast Guard, Space Force, etc.)';
COMMENT ON COLUMN profiles.veteran_service_number IS 'Service number or service member ID';

