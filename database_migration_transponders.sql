-- Migration Script: Add Transponders Table
-- Run this SQL in your Supabase SQL Editor to add transponder functionality

-- Create transponders table
CREATE TABLE IF NOT EXISTS transponders (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    pilot_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    device_name TEXT NOT NULL,
    remote_id TEXT NOT NULL,
    is_location_tracking_enabled BOOLEAN DEFAULT false NOT NULL,
    last_location_lat DOUBLE PRECISION,
    last_location_lng DOUBLE PRECISION,
    last_location_update TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()) NOT NULL
);

-- Create index on pilot_id for faster queries
CREATE INDEX IF NOT EXISTS idx_transponders_pilot_id ON transponders(pilot_id);

-- Create index on remote_id for lookups
CREATE INDEX IF NOT EXISTS idx_transponders_remote_id ON transponders(remote_id);

-- Enable Row Level Security
ALTER TABLE transponders ENABLE ROW LEVEL SECURITY;

-- Transponders Policies
-- Users can view their own transponders
CREATE POLICY "Pilots can view their own transponders" 
    ON transponders FOR SELECT 
    TO authenticated
    USING (auth.uid() = pilot_id);

-- Users can insert their own transponders
CREATE POLICY "Pilots can insert their own transponders" 
    ON transponders FOR INSERT 
    TO authenticated
    WITH CHECK (auth.uid() = pilot_id);

-- Users can update their own transponders
CREATE POLICY "Pilots can update their own transponders" 
    ON transponders FOR UPDATE 
    TO authenticated
    USING (auth.uid() = pilot_id);

-- Users can delete their own transponders
CREATE POLICY "Pilots can delete their own transponders" 
    ON transponders FOR DELETE 
    TO authenticated
    USING (auth.uid() = pilot_id);

-- Verify the table was created
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'transponders'
ORDER BY ordinal_position;

