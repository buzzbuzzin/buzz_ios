-- Add 'pre_approved' status to license_approval_requests
-- New flow: pending → pre_approved (TC email sent) → approved (badge + role + tests granted)

-- Drop existing CHECK constraint on status
ALTER TABLE license_approval_requests
  DROP CONSTRAINT IF EXISTS license_approval_requests_status_check;

-- Re-create with pre_approved included
ALTER TABLE license_approval_requests
  ADD CONSTRAINT license_approval_requests_status_check
  CHECK (status IN ('pending', 'pre_approved', 'approved', 'rejected', 'document_deleted'));
