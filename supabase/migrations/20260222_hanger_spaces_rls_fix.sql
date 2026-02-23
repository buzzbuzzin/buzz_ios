-- ============================================================================
-- Hanger Spaces - RLS policy fix for speaker requests
-- Migration: 20260222_hanger_spaces_rls_fix.sql
-- Description: Allows users to delete their own pending speaker requests.
-- ============================================================================

-- Users can cancel (delete) their own speaker requests
CREATE POLICY "Users can cancel own speaker request" ON hanger_space_speaker_requests FOR DELETE
    USING (user_id = auth.uid());
