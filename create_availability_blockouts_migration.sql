-- Migration: Create availability_blockouts table
-- This table stores pilot availability blockouts with recurrence support

CREATE TABLE IF NOT EXISTS availability_blockouts (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    pilot_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    label TEXT,
    start_date TIMESTAMP WITH TIME ZONE NOT NULL,
    end_date TIMESTAMP WITH TIME ZONE NOT NULL,
    recurrence_type TEXT NOT NULL DEFAULT 'none' CHECK (recurrence_type IN ('none', 'daily', 'weekly', 'weekdays', 'weekends', 'monthly')),
    recurrence_end_date TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()) NOT NULL
);

-- Add label column if table already exists (for migrations)
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'availability_blockouts' AND column_name = 'label'
    ) THEN
        ALTER TABLE availability_blockouts ADD COLUMN label TEXT;
    END IF;
END $$;

-- Enable Row Level Security
ALTER TABLE availability_blockouts ENABLE ROW LEVEL SECURITY;

-- Create RLS Policies
DROP POLICY IF EXISTS "Pilots can view their own blockouts" ON availability_blockouts;
DROP POLICY IF EXISTS "Pilots can create their own blockouts" ON availability_blockouts;
DROP POLICY IF EXISTS "Pilots can delete their own blockouts" ON availability_blockouts;

CREATE POLICY "Pilots can view their own blockouts" 
    ON availability_blockouts FOR SELECT 
    TO authenticated
    USING (auth.uid() = pilot_id);

CREATE POLICY "Pilots can create their own blockouts" 
    ON availability_blockouts FOR INSERT 
    TO authenticated
    WITH CHECK (auth.uid() = pilot_id);

CREATE POLICY "Pilots can delete their own blockouts" 
    ON availability_blockouts FOR DELETE 
    TO authenticated
    USING (auth.uid() = pilot_id);

-- Create index for efficient queries
CREATE INDEX IF NOT EXISTS idx_availability_blockouts_pilot_id ON availability_blockouts(pilot_id);
CREATE INDEX IF NOT EXISTS idx_availability_blockouts_start_date ON availability_blockouts(start_date);
CREATE INDEX IF NOT EXISTS idx_availability_blockouts_end_date ON availability_blockouts(end_date);

