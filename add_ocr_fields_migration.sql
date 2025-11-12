-- Migration: Add OCR extracted fields to drone_registrations table
-- This migration adds columns to store information extracted from drone registration documents using OCR

-- Add OCR extracted fields to drone_registrations table
ALTER TABLE drone_registrations
ADD COLUMN IF NOT EXISTS registered_owner TEXT,
ADD COLUMN IF NOT EXISTS manufacturer TEXT,
ADD COLUMN IF NOT EXISTS model TEXT,
ADD COLUMN IF NOT EXISTS serial_number TEXT,
ADD COLUMN IF NOT EXISTS registration_number TEXT,
ADD COLUMN IF NOT EXISTS issued TEXT,
ADD COLUMN IF NOT EXISTS expires TEXT;

-- Add comments to document the fields
COMMENT ON COLUMN drone_registrations.registered_owner IS 'Registered owner name extracted from OCR';
COMMENT ON COLUMN drone_registrations.manufacturer IS 'UAS manufacturer extracted from OCR';
COMMENT ON COLUMN drone_registrations.model IS 'UAS model extracted from OCR';
COMMENT ON COLUMN drone_registrations.serial_number IS 'Serial number extracted from OCR';
COMMENT ON COLUMN drone_registrations.registration_number IS 'Registration number extracted from OCR';
COMMENT ON COLUMN drone_registrations.issued IS 'Issue date extracted from OCR';
COMMENT ON COLUMN drone_registrations.expires IS 'Expiration date extracted from OCR';

