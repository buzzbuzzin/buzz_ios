-- Stripe Identity Migration Script
-- Run this SQL in your Supabase SQL Editor to add support for Stripe Identity verification
-- This script is idempotent - safe to run multiple times

-- ============================================================================
-- GOVERNMENT IDS TABLE
-- ============================================================================

-- Create the government_ids table if it doesn't exist
CREATE TABLE IF NOT EXISTS government_ids (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    file_url TEXT, -- Made nullable since Stripe handles document storage
    file_type TEXT CHECK (file_type IN ('pdf', 'image')), -- Made nullable
    verification_status TEXT NOT NULL DEFAULT 'pending' CHECK (verification_status IN ('pending', 'verified', 'rejected')),
    stripe_session_id TEXT, -- Stripe Identity verification session ID
    uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()) NOT NULL,
    UNIQUE(user_id) -- One verification per user
);

-- Add missing columns if table already exists (for migrations)
DO $$ 
BEGIN
    -- Add stripe_session_id if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'government_ids' AND column_name = 'stripe_session_id'
    ) THEN
        ALTER TABLE government_ids ADD COLUMN stripe_session_id TEXT;
    END IF;
    
    -- Make file_url nullable if it's not already
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'government_ids' 
        AND column_name = 'file_url' 
        AND is_nullable = 'NO'
    ) THEN
        ALTER TABLE government_ids ALTER COLUMN file_url DROP NOT NULL;
    END IF;
    
    -- Make file_type nullable if it's not already
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'government_ids' 
        AND column_name = 'file_type' 
        AND is_nullable = 'NO'
    ) THEN
        ALTER TABLE government_ids ALTER COLUMN file_type DROP NOT NULL;
    END IF;
    
    -- Add verification_status if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'government_ids' AND column_name = 'verification_status'
    ) THEN
        ALTER TABLE government_ids ADD COLUMN verification_status TEXT DEFAULT 'pending';
        
        -- Add check constraint for verification_status
        ALTER TABLE government_ids ADD CONSTRAINT government_ids_verification_status_check 
        CHECK (verification_status IN ('pending', 'verified', 'rejected'));
    END IF;
    
    -- Add unique constraint on user_id if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'government_ids_user_id_key'
    ) THEN
        ALTER TABLE government_ids ADD CONSTRAINT government_ids_user_id_key UNIQUE (user_id);
    END IF;
END $$;

-- Enable Row Level Security
ALTER TABLE government_ids ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist (for idempotency)
DROP POLICY IF EXISTS "Users can view their own government IDs" ON government_ids;
DROP POLICY IF EXISTS "Users can insert their own government IDs" ON government_ids;
DROP POLICY IF EXISTS "Users can update their own government IDs" ON government_ids;
DROP POLICY IF EXISTS "Users can delete their own government IDs" ON government_ids;

-- Government IDs Policies
CREATE POLICY "Users can view their own government IDs" 
    ON government_ids FOR SELECT 
    TO authenticated
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own government IDs" 
    ON government_ids FOR INSERT 
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own government IDs" 
    ON government_ids FOR UPDATE 
    TO authenticated
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own government IDs" 
    ON government_ids FOR DELETE 
    TO authenticated
    USING (auth.uid() = user_id);

-- ============================================================================
-- INDEXES
-- ============================================================================

-- Create index on user_id for faster lookups
CREATE INDEX IF NOT EXISTS idx_government_ids_user_id ON government_ids(user_id);

-- Create index on verification_status for filtering
CREATE INDEX IF NOT EXISTS idx_government_ids_verification_status ON government_ids(verification_status);

-- Create index on stripe_session_id for lookups
CREATE INDEX IF NOT EXISTS idx_government_ids_stripe_session_id ON government_ids(stripe_session_id);

-- ============================================================================
-- VERIFICATION QUERIES (Optional - uncomment to verify)
-- ============================================================================

-- Uncomment to verify the table was created:
-- SELECT column_name, data_type, is_nullable 
-- FROM information_schema.columns 
-- WHERE table_name = 'government_ids'
-- ORDER BY ordinal_position;

-- Uncomment to verify policies:
-- SELECT policyname, cmd, qual 
-- FROM pg_policies 
-- WHERE tablename = 'government_ids';

