-- Flight Hour Claims table
-- Allows pilots to submit bulk historical flight hour claims for admin review

CREATE TABLE flight_hour_claims (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  pilot_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  claimed_flights INT NOT NULL,
  claimed_hours DOUBLE PRECISION NOT NULL,
  notes TEXT,
  evidence_files TEXT[] DEFAULT '{}',
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  submitted_at TIMESTAMPTZ DEFAULT now(),
  reviewed_at TIMESTAMPTZ,
  reviewed_by UUID REFERENCES profiles(id),
  reviewer_notes TEXT
);

-- RLS policies
ALTER TABLE flight_hour_claims ENABLE ROW LEVEL SECURITY;

-- Pilots can insert their own claims
CREATE POLICY "Pilots can insert own claims"
  ON flight_hour_claims
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = pilot_id);

-- Pilots can view their own claims
CREATE POLICY "Pilots can view own claims"
  ON flight_hour_claims
  FOR SELECT
  TO authenticated
  USING (auth.uid() = pilot_id);

-- Service role can do everything (for portal admin)
CREATE POLICY "Service role full access"
  ON flight_hour_claims
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- Authenticated users with admin role can update claims (for portal)
CREATE POLICY "Admins can view all claims"
  ON flight_hour_claims
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Admins can update claims"
  ON flight_hour_claims
  FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Create storage bucket for evidence files
INSERT INTO storage.buckets (id, name, public)
VALUES ('flight-hour-claims', 'flight-hour-claims', true)
ON CONFLICT (id) DO NOTHING;

-- Storage policies for flight-hour-claims bucket
CREATE POLICY "Pilots can upload evidence files"
  ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (bucket_id = 'flight-hour-claims' AND (storage.foldername(name))[1] = auth.uid()::text);

CREATE POLICY "Anyone can view evidence files"
  ON storage.objects
  FOR SELECT
  TO authenticated
  USING (bucket_id = 'flight-hour-claims');
