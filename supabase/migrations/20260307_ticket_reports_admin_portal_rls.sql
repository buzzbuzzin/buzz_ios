-- ============================================================================
-- Ticket Reports — Admin Portal RLS Policies
-- Migration: 20260307_ticket_reports_admin_portal_rls.sql
-- Description: Adds RLS policies so portal admins (employee_profiles with
--              role admin/owner) can read and update all ticket reports.
-- ============================================================================

-- Portal admins can read all ticket reports
CREATE POLICY "Portal admins can read all ticket reports"
ON ticket_reports FOR SELECT
USING (
  auth.email() IN (
    SELECT email FROM employee_profiles WHERE role IN ('admin', 'owner')
  )
);

-- Portal admins can update ticket reports
CREATE POLICY "Portal admins can update ticket reports"
ON ticket_reports FOR UPDATE
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
