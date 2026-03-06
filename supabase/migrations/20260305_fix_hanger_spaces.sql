-- ============================================================================
-- Hanger Spaces - Comprehensive fixes
-- Migration: 20260305_fix_hanger_spaces.sql
-- Description: Fixes trigger security, RLS role escalation, count defaults,
--              status transitions, speaker request re-requesting, indexes,
--              and adds space_id to notifications.
-- ============================================================================

-- ============================================================================
-- 1. Fix trigger: add SECURITY DEFINER so counts update regardless of caller
-- ============================================================================
CREATE OR REPLACE FUNCTION update_hanger_space_counts()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        IF NEW.role = 'listener' THEN
            UPDATE hanger_spaces SET listener_count = listener_count + 1, updated_at = NOW() WHERE id = NEW.space_id;
        ELSIF NEW.role IN ('host', 'speaker') THEN
            UPDATE hanger_spaces SET speaker_count = speaker_count + 1, updated_at = NOW() WHERE id = NEW.space_id;
        END IF;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        IF OLD.role = 'listener' THEN
            UPDATE hanger_spaces SET listener_count = GREATEST(listener_count - 1, 0), updated_at = NOW() WHERE id = OLD.space_id;
        ELSIF OLD.role IN ('host', 'speaker') THEN
            UPDATE hanger_spaces SET speaker_count = GREATEST(speaker_count - 1, 0), updated_at = NOW() WHERE id = OLD.space_id;
        END IF;
        RETURN OLD;
    ELSIF TG_OP = 'UPDATE' THEN
        -- Handle soft-delete: when left_at changes from NULL to non-NULL, decrement
        IF OLD.left_at IS NULL AND NEW.left_at IS NOT NULL THEN
            IF NEW.role = 'listener' THEN
                UPDATE hanger_spaces SET listener_count = GREATEST(listener_count - 1, 0), updated_at = NOW() WHERE id = NEW.space_id;
            ELSIF NEW.role IN ('host', 'speaker') THEN
                UPDATE hanger_spaces SET speaker_count = GREATEST(speaker_count - 1, 0), updated_at = NOW() WHERE id = NEW.space_id;
            END IF;
        -- Handle role changes (only for active participants)
        ELSIF OLD.role != NEW.role AND NEW.left_at IS NULL THEN
            -- Decrement old role count
            IF OLD.role = 'listener' THEN
                UPDATE hanger_spaces SET listener_count = GREATEST(listener_count - 1, 0), updated_at = NOW() WHERE id = NEW.space_id;
            ELSIF OLD.role IN ('host', 'speaker') THEN
                UPDATE hanger_spaces SET speaker_count = GREATEST(speaker_count - 1, 0), updated_at = NOW() WHERE id = NEW.space_id;
            END IF;
            -- Increment new role count
            IF NEW.role = 'listener' THEN
                UPDATE hanger_spaces SET listener_count = listener_count + 1, updated_at = NOW() WHERE id = NEW.space_id;
            ELSIF NEW.role IN ('host', 'speaker') THEN
                UPDATE hanger_spaces SET speaker_count = speaker_count + 1, updated_at = NOW() WHERE id = NEW.space_id;
            END IF;
        END IF;
        RETURN NEW;
    END IF;
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- 2. Fix speaker_count default: 0 instead of 1 (trigger handles host insert)
-- ============================================================================
ALTER TABLE hanger_spaces ALTER COLUMN speaker_count SET DEFAULT 0;

-- ============================================================================
-- 3. Fix RLS: prevent users from self-assigning host/speaker role on INSERT
-- ============================================================================
DROP POLICY IF EXISTS "Users can join spaces" ON hanger_space_participants;
CREATE POLICY "Users can join spaces as listener" ON hanger_space_participants FOR INSERT
    WITH CHECK (user_id = auth.uid() AND role = 'listener');

-- Allow the host to insert themselves with role 'host'
CREATE POLICY "Host can insert self as host" ON hanger_space_participants FOR INSERT
    WITH CHECK (
        role = 'host' AND user_id = auth.uid()
        AND EXISTS (
            SELECT 1 FROM hanger_spaces
            WHERE hanger_spaces.id = hanger_space_participants.space_id
            AND hanger_spaces.host_id = auth.uid()
        )
    );

-- ============================================================================
-- 4. Fix RLS: prevent users from escalating their own role
-- ============================================================================
DROP POLICY IF EXISTS "Users can update own participation" ON hanger_space_participants;
CREATE POLICY "Users can update own participation (leave only)" ON hanger_space_participants FOR UPDATE
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid() AND role = (
        SELECT role FROM hanger_space_participants AS p
        WHERE p.space_id = hanger_space_participants.space_id
        AND p.user_id = hanger_space_participants.user_id
        LIMIT 1
    ));

-- ============================================================================
-- 5. Add status transition enforcement
-- ============================================================================
CREATE OR REPLACE FUNCTION enforce_space_status_transition()
RETURNS TRIGGER AS $$
BEGIN
    -- Only allow valid transitions: scheduled -> live -> ended
    IF OLD.status = 'ended' AND NEW.status != 'ended' THEN
        RAISE EXCEPTION 'Cannot transition from ended to %', NEW.status;
    END IF;
    IF OLD.status = 'live' AND NEW.status = 'scheduled' THEN
        RAISE EXCEPTION 'Cannot transition from live to scheduled';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER enforce_space_status_transition_trigger
    BEFORE UPDATE ON hanger_spaces
    FOR EACH ROW
    WHEN (OLD.status IS DISTINCT FROM NEW.status)
    EXECUTE FUNCTION enforce_space_status_transition();

-- ============================================================================
-- 6. Fix speaker request unique constraint to allow re-requesting after decline
-- ============================================================================
ALTER TABLE hanger_space_speaker_requests DROP CONSTRAINT IF EXISTS hanger_space_speaker_requests_unique;
CREATE UNIQUE INDEX idx_hanger_space_speaker_requests_active
    ON hanger_space_speaker_requests(space_id, user_id)
    WHERE status = 'pending';

-- ============================================================================
-- 7. Add missing index on speaker requests
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_hanger_space_speaker_requests_space_pending
    ON hanger_space_speaker_requests(space_id) WHERE status = 'pending';

-- ============================================================================
-- 8. Add space_id column to hanger_talk_notifications for space notifications
-- ============================================================================
ALTER TABLE hanger_talk_notifications ADD COLUMN IF NOT EXISTS space_id UUID REFERENCES hanger_spaces(id) ON DELETE SET NULL;

-- Update type CHECK to include space_live
ALTER TABLE hanger_talk_notifications DROP CONSTRAINT IF EXISTS hanger_talk_notifications_type_check;
ALTER TABLE hanger_talk_notifications ADD CONSTRAINT hanger_talk_notifications_type_check
    CHECK (type IN ('like', 'reply', 'mention', 'follow', 'new_post', 'space_live'));

-- ============================================================================
-- 9. Add WITH CHECK to host update policy on hanger_spaces
-- ============================================================================
DROP POLICY IF EXISTS "Host can update own space" ON hanger_spaces;
CREATE POLICY "Host can update own space" ON hanger_spaces FOR UPDATE
    USING (host_id = auth.uid())
    WITH CHECK (host_id = auth.uid());
