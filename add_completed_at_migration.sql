-- Migration: Add completed_at column to bookings table
-- This migration adds a timestamp field to track when bookings are officially completed
-- Run this SQL in your Supabase SQL Editor

-- Add completed_at column if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'bookings' AND column_name = 'completed_at'
    ) THEN
        ALTER TABLE bookings ADD COLUMN completed_at TIMESTAMP WITH TIME ZONE;
    END IF;
END $$;

