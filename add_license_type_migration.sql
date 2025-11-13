-- Migration: Add license_type column to pilot_licenses table
-- This migration adds a column to store the type of pilot license

-- Add license_type column to pilot_licenses table
ALTER TABLE pilot_licenses
ADD COLUMN IF NOT EXISTS license_type TEXT;

-- Add comment to document the field
COMMENT ON COLUMN pilot_licenses.license_type IS 'Type of pilot license (e.g., Part 107, Part 107 recurrent, Part 108, Transport Canada, or custom text)';

