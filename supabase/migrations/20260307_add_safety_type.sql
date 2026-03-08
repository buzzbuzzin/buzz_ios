-- ============================================================================
-- Add Safety Type to Ticket Reports
-- Migration: 20260307_add_safety_type.sql
-- Description: Adds 'safety' as a valid type for ticket_reports, enabling
--              safety issue reporting through the same ticket system.
-- ============================================================================

-- Drop existing CHECK constraint on type column (name may be auto-generated)
DO $$
DECLARE
    cname text;
BEGIN
    SELECT conname INTO cname
    FROM pg_constraint
    WHERE conrelid = 'ticket_reports'::regclass
      AND contype = 'c'
      AND pg_get_constraintdef(oid) LIKE '%type%';
    IF cname IS NOT NULL THEN
        EXECUTE format('ALTER TABLE ticket_reports DROP CONSTRAINT %I', cname);
    END IF;
END $$;

-- Add new CHECK constraint allowing both 'bug' and 'safety'
ALTER TABLE ticket_reports ADD CONSTRAINT ticket_reports_type_check CHECK (type IN ('bug', 'safety'));
