-- Migration: Add Beacon Emergency Response Program
-- Description: Creates tables for tracking beacon volunteer training progress and volunteer status

-- beacon_training_progress: Tracks training certificate uploads for beacon volunteers
CREATE TABLE IF NOT EXISTS public.beacon_training_progress (
    id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    pilot_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    training_type text NOT NULL CHECK (training_type IN ('cpr', 'firefighting')),
    certificate_url text NOT NULL,
    uploaded_at timestamptz DEFAULT now(),
    verified boolean DEFAULT false,
    verified_at timestamptz,
    verified_by uuid REFERENCES public.profiles(id),
    UNIQUE(pilot_id, training_type)
);

-- beacon_volunteers: Active beacon volunteers who have completed onboarding
CREATE TABLE IF NOT EXISTS public.beacon_volunteers (
    id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    pilot_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE UNIQUE,
    enrolled_at timestamptz DEFAULT now(),
    is_available boolean DEFAULT true,
    last_location_lat double precision,
    last_location_lng double precision,
    last_location_update timestamptz,
    notification_radius_miles integer DEFAULT 25,
    total_missions_completed integer DEFAULT 0,
    total_hours_volunteered double precision DEFAULT 0,
    people_helped integer DEFAULT 0
);

-- Add beacon_volunteer flag to profiles if not exists
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'profiles' 
        AND column_name = 'is_beacon_volunteer'
    ) THEN
        ALTER TABLE public.profiles ADD COLUMN is_beacon_volunteer boolean DEFAULT false;
    END IF;
END $$;

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_beacon_training_pilot_id ON public.beacon_training_progress(pilot_id);
CREATE INDEX IF NOT EXISTS idx_beacon_volunteers_pilot_id ON public.beacon_volunteers(pilot_id);
CREATE INDEX IF NOT EXISTS idx_beacon_volunteers_available ON public.beacon_volunteers(is_available) WHERE is_available = true;
CREATE INDEX IF NOT EXISTS idx_beacon_volunteers_location ON public.beacon_volunteers(last_location_lat, last_location_lng) WHERE is_available = true;

-- RLS Policies for beacon_training_progress
ALTER TABLE public.beacon_training_progress ENABLE ROW LEVEL SECURITY;

-- Users can view their own training progress
CREATE POLICY "Users can view own training progress"
    ON public.beacon_training_progress
    FOR SELECT
    USING (auth.uid() = pilot_id);

-- Users can insert their own training progress
CREATE POLICY "Users can insert own training progress"
    ON public.beacon_training_progress
    FOR INSERT
    WITH CHECK (auth.uid() = pilot_id);

-- Users can update their own training progress
CREATE POLICY "Users can update own training progress"
    ON public.beacon_training_progress
    FOR UPDATE
    USING (auth.uid() = pilot_id);

-- RLS Policies for beacon_volunteers
ALTER TABLE public.beacon_volunteers ENABLE ROW LEVEL SECURITY;

-- Users can view their own volunteer status
CREATE POLICY "Users can view own volunteer status"
    ON public.beacon_volunteers
    FOR SELECT
    USING (auth.uid() = pilot_id);

-- Users can insert their own volunteer record
CREATE POLICY "Users can insert own volunteer record"
    ON public.beacon_volunteers
    FOR INSERT
    WITH CHECK (auth.uid() = pilot_id);

-- Users can update their own volunteer record
CREATE POLICY "Users can update own volunteer record"
    ON public.beacon_volunteers
    FOR UPDATE
    USING (auth.uid() = pilot_id);

-- Authenticated users can view available volunteers (for emergency dispatch)
CREATE POLICY "Authenticated users can view available volunteers"
    ON public.beacon_volunteers
    FOR SELECT
    USING (auth.role() = 'authenticated' AND is_available = true);

-- Function to check if a user has completed all beacon training
CREATE OR REPLACE FUNCTION public.check_beacon_training_complete(p_pilot_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    training_count integer;
BEGIN
    SELECT COUNT(DISTINCT training_type)
    INTO training_count
    FROM public.beacon_training_progress
    WHERE pilot_id = p_pilot_id;
    
    -- Requires both CPR and Firefighting training
    RETURN training_count >= 2;
END;
$$;

-- Function to enroll user as beacon volunteer
CREATE OR REPLACE FUNCTION public.enroll_beacon_volunteer(p_pilot_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Check if training is complete
    IF NOT public.check_beacon_training_complete(p_pilot_id) THEN
        RAISE EXCEPTION 'Training requirements not met';
    END IF;
    
    -- Insert volunteer record
    INSERT INTO public.beacon_volunteers (pilot_id)
    VALUES (p_pilot_id)
    ON CONFLICT (pilot_id) DO NOTHING;
    
    -- Update profile
    UPDATE public.profiles
    SET is_beacon_volunteer = true
    WHERE id = p_pilot_id;
    
    RETURN true;
END;
$$;

-- Function to find nearby beacon volunteers for emergency dispatch
CREATE OR REPLACE FUNCTION public.find_nearby_beacon_volunteers(
    p_lat double precision,
    p_lng double precision,
    p_radius_miles integer DEFAULT 25
)
RETURNS TABLE (
    volunteer_id uuid,
    pilot_id uuid,
    distance_miles double precision,
    notification_radius_miles integer
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        bv.id as volunteer_id,
        bv.pilot_id,
        -- Haversine formula for distance calculation
        (3959 * acos(
            cos(radians(p_lat)) * cos(radians(bv.last_location_lat)) *
            cos(radians(bv.last_location_lng) - radians(p_lng)) +
            sin(radians(p_lat)) * sin(radians(bv.last_location_lat))
        )) as distance_miles,
        bv.notification_radius_miles
    FROM public.beacon_volunteers bv
    WHERE bv.is_available = true
        AND bv.last_location_lat IS NOT NULL
        AND bv.last_location_lng IS NOT NULL
        AND (3959 * acos(
            cos(radians(p_lat)) * cos(radians(bv.last_location_lat)) *
            cos(radians(bv.last_location_lng) - radians(p_lng)) +
            sin(radians(p_lat)) * sin(radians(bv.last_location_lat))
        )) <= LEAST(p_radius_miles, bv.notification_radius_miles)
    ORDER BY distance_miles;
END;
$$;

-- Grant execute permissions on functions
GRANT EXECUTE ON FUNCTION public.check_beacon_training_complete(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.enroll_beacon_volunteer(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.find_nearby_beacon_volunteers(double precision, double precision, integer) TO authenticated;

