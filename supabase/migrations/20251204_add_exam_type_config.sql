-- Migration: Add exam_type_config table for dynamic exam configuration
-- This table stores all exam type properties that were previously hardcoded

-- Create exam_type_config table
CREATE TABLE IF NOT EXISTS public.exam_type_config (
  exam_type text NOT NULL PRIMARY KEY CHECK (exam_type IN ('flight_review', 'roc_a')),
  display_name text NOT NULL,
  short_description text NOT NULL,
  full_description text NOT NULL,
  icon text NOT NULL,
  duration_minutes integer NOT NULL DEFAULT 30,
  allows_online boolean NOT NULL DEFAULT false,
  stripe_product_id text NOT NULL,
  prerequisites jsonb NOT NULL DEFAULT '[]'::jsonb,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Insert exam configurations with 30 minute duration
INSERT INTO public.exam_type_config (exam_type, display_name, short_description, full_description, icon, duration_minutes, allows_online, stripe_product_id, prerequisites)
VALUES
  (
    'flight_review',
    'Flight Review',
    'In-person hands-on flight assessment',
    'The Flight Review is an in-person, hands-on assessment that evaluates your ability to plan and execute a drone flight safely. An examiner will observe your pre-flight procedures, flight execution, and post-flight protocols.',
    'person.text.rectangle.fill',
    30,
    false,
    'prod_TW3nHwTNX9Xtec',
    '["Passed Ground School Test", "Completed Unit 4 of UAS Pilot Course"]'::jsonb
  ),
  (
    'roc_a',
    'ROC-A Exam',
    'Radio communication competency exam',
    'A Restricted Operator Certificate with Aeronautical Qualification (ROC-A) exam demonstrates your competence in operating aeronautical radio equipment. It ensures you understand and can use proper radiotelephone communication procedures with air traffic control.',
    'antenna.radiowaves.left.and.right',
    30,
    true,
    'prod_TW3nnJ9zKy3tC3',
    '["Passed Ground School Test", "Completed Unit 4 of UAS Pilot Course"]'::jsonb
  )
ON CONFLICT (exam_type) DO UPDATE SET
  display_name = EXCLUDED.display_name,
  short_description = EXCLUDED.short_description,
  full_description = EXCLUDED.full_description,
  icon = EXCLUDED.icon,
  duration_minutes = EXCLUDED.duration_minutes,
  allows_online = EXCLUDED.allows_online,
  stripe_product_id = EXCLUDED.stripe_product_id,
  prerequisites = EXCLUDED.prerequisites,
  updated_at = timezone('utc'::text, now());

-- Enable Row Level Security
ALTER TABLE public.exam_type_config ENABLE ROW LEVEL SECURITY;

-- Allow public read access (everyone can read exam configurations)
CREATE POLICY "exam_type_config_select_policy"
  ON public.exam_type_config
  FOR SELECT
  TO authenticated, anon
  USING (true);

-- Create index on exam_type for faster lookups
CREATE INDEX IF NOT EXISTS idx_exam_type_config_exam_type ON public.exam_type_config(exam_type);

-- Add comment for documentation
COMMENT ON TABLE public.exam_type_config IS 'Stores configuration for exam types (Flight Review, ROC-A) including duration, pricing, and prerequisites';

