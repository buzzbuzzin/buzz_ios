-- Migration: Add OCR extracted fields to pilot_licenses table
-- This migration adds columns to store information extracted from pilot license documents using OCR

-- Add OCR extracted fields to pilot_licenses table
ALTER TABLE pilot_licenses
ADD COLUMN IF NOT EXISTS name TEXT,
ADD COLUMN IF NOT EXISTS course_completed TEXT,
ADD COLUMN IF NOT EXISTS completion_date TEXT,
ADD COLUMN IF NOT EXISTS certificate_number TEXT;

-- Add comments to document the fields
COMMENT ON COLUMN pilot_licenses.name IS 'Pilot name extracted from OCR';
COMMENT ON COLUMN pilot_licenses.course_completed IS 'Course completed name extracted from OCR';
COMMENT ON COLUMN pilot_licenses.completion_date IS 'Course completion date extracted from OCR';
COMMENT ON COLUMN pilot_licenses.certificate_number IS 'Course completion certificate number extracted from OCR';

