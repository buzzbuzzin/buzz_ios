-- Fix overly permissive RLS policies on flight_hour_claims
-- Replace "any authenticated user" with admin-only checks

-- Drop the insecure policies
DROP POLICY IF EXISTS "Admins can view all claims" ON flight_hour_claims;
DROP POLICY IF EXISTS "Admins can update claims" ON flight_hour_claims;

-- Admins can view all claims (restricted to employee_profiles with admin/owner role)
CREATE POLICY "Admins can view all claims"
  ON flight_hour_claims
  FOR SELECT
  TO authenticated
  USING (
    auth.email() IN (
      SELECT email FROM employee_profiles WHERE role IN ('admin', 'owner')
    )
  );

-- Admins can update claims (restricted to employee_profiles with admin/owner role)
CREATE POLICY "Admins can update claims"
  ON flight_hour_claims
  FOR UPDATE
  TO authenticated
  USING (
    auth.email() IN (
      SELECT email FROM employee_profiles WHERE role IN ('admin', 'owner')
    )
  )
  WITH CHECK (
    auth.email() IN (
      SELECT email FROM employee_profiles WHERE role IN ('admin', 'owner')
    )
  );

-- Add CHECK constraints for positive values
ALTER TABLE flight_hour_claims
  ADD CONSTRAINT flight_hour_claims_flights_positive CHECK (claimed_flights > 0),
  ADD CONSTRAINT flight_hour_claims_hours_positive CHECK (claimed_hours > 0);

-- Add indexes for query performance
CREATE INDEX idx_flight_hour_claims_pilot_id ON flight_hour_claims(pilot_id);
CREATE INDEX idx_flight_hour_claims_status ON flight_hour_claims(status);
