-- Migration: Add paywall, unit completion tracking, and test system for UAS Pilot Course
-- Run this SQL in your Supabase SQL Editor

-- UAS Pilot Course UUID (fixed)
DO $$
DECLARE
    uas_course_id UUID := 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';
BEGIN

-- ----------------------------------------------------------------------------
-- Course Subscriptions Table
-- Tracks which pilots have purchased access to premium units (4+)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS course_subscriptions (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    pilot_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    course_id UUID REFERENCES training_courses(id) ON DELETE CASCADE NOT NULL,
    stripe_subscription_id TEXT, -- Stripe subscription ID
    stripe_price_id TEXT, -- Stripe price ID for the subscription
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'canceled', 'past_due', 'incomplete', 'trialing')),
    current_period_start TIMESTAMP WITH TIME ZONE,
    current_period_end TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()) NOT NULL,
    UNIQUE(pilot_id, course_id)
);

-- Enable Row Level Security
ALTER TABLE course_subscriptions ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Pilots can view their own subscriptions" ON course_subscriptions;
DROP POLICY IF EXISTS "Pilots can insert their own subscriptions" ON course_subscriptions;
DROP POLICY IF EXISTS "Pilots can update their own subscriptions" ON course_subscriptions;

-- RLS Policies for course_subscriptions
CREATE POLICY "Pilots can view their own subscriptions" 
    ON course_subscriptions FOR SELECT 
    TO authenticated
    USING (auth.uid() = pilot_id);

CREATE POLICY "Pilots can insert their own subscriptions" 
    ON course_subscriptions FOR INSERT 
    TO authenticated
    WITH CHECK (auth.uid() = pilot_id);

CREATE POLICY "Pilots can update their own subscriptions" 
    ON course_subscriptions FOR UPDATE 
    TO authenticated
    USING (auth.uid() = pilot_id);

-- ----------------------------------------------------------------------------
-- Unit Completions Table
-- Tracks which units each pilot has completed
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS unit_completions (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    pilot_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    unit_id UUID REFERENCES course_units(id) ON DELETE CASCADE NOT NULL,
    course_id UUID REFERENCES training_courses(id) ON DELETE CASCADE NOT NULL,
    completed_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()) NOT NULL,
    UNIQUE(pilot_id, unit_id)
);

-- Enable Row Level Security
ALTER TABLE unit_completions ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Pilots can view their own unit completions" ON unit_completions;
DROP POLICY IF EXISTS "Pilots can insert their own unit completions" ON unit_completions;

-- RLS Policies for unit_completions
CREATE POLICY "Pilots can view their own unit completions" 
    ON unit_completions FOR SELECT 
    TO authenticated
    USING (auth.uid() = pilot_id);

CREATE POLICY "Pilots can insert their own unit completions" 
    ON unit_completions FOR INSERT 
    TO authenticated
    WITH CHECK (auth.uid() = pilot_id);

-- ----------------------------------------------------------------------------
-- Ground School Test Results Table
-- Tracks test results for the ground school test (after units 1-3)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ground_school_test_results (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    pilot_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    course_id UUID REFERENCES training_courses(id) ON DELETE CASCADE NOT NULL,
    score INTEGER NOT NULL CHECK (score >= 0 AND score <= 100),
    passed BOOLEAN NOT NULL DEFAULT FALSE,
    answers JSONB, -- Store the answers provided
    completed_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()) NOT NULL,
    UNIQUE(pilot_id, course_id)
);

-- Enable Row Level Security
ALTER TABLE ground_school_test_results ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Pilots can view their own test results" ON ground_school_test_results;
DROP POLICY IF EXISTS "Pilots can insert their own test results" ON ground_school_test_results;
DROP POLICY IF EXISTS "Pilots can update their own test results" ON ground_school_test_results;

-- RLS Policies for ground_school_test_results
CREATE POLICY "Pilots can view their own test results" 
    ON ground_school_test_results FOR SELECT 
    TO authenticated
    USING (auth.uid() = pilot_id);

CREATE POLICY "Pilots can insert their own test results" 
    ON ground_school_test_results FOR INSERT 
    TO authenticated
    WITH CHECK (auth.uid() = pilot_id);

CREATE POLICY "Pilots can update their own test results" 
    ON ground_school_test_results FOR UPDATE 
    TO authenticated
    USING (auth.uid() = pilot_id);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_course_subscriptions_pilot_course ON course_subscriptions(pilot_id, course_id);
CREATE INDEX IF NOT EXISTS idx_course_subscriptions_status ON course_subscriptions(status);
CREATE INDEX IF NOT EXISTS idx_unit_completions_pilot_unit ON unit_completions(pilot_id, unit_id);
CREATE INDEX IF NOT EXISTS idx_unit_completions_pilot_course ON unit_completions(pilot_id, course_id);
CREATE INDEX IF NOT EXISTS idx_ground_school_test_results_pilot_course ON ground_school_test_results(pilot_id, course_id);

END $$;

