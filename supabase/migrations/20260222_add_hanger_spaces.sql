-- ============================================================================
-- Hanger Spaces - Live Audio Rooms (X Spaces style)
-- Migration: 20260222_add_hanger_spaces.sql
-- Description: Creates tables for live audio room functionality in HangerTalk.
-- ============================================================================

-- 1. hanger_spaces - Room metadata
CREATE TABLE IF NOT EXISTS hanger_spaces (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    host_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    status TEXT NOT NULL DEFAULT 'live' CHECK (status IN ('scheduled', 'live', 'ended')),
    livekit_room_name TEXT NOT NULL UNIQUE,
    started_at TIMESTAMPTZ,
    ended_at TIMESTAMPTZ,
    scheduled_at TIMESTAMPTZ,
    listener_count INTEGER NOT NULL DEFAULT 0,
    speaker_count INTEGER NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_hanger_spaces_host_id ON hanger_spaces(host_id);
CREATE INDEX idx_hanger_spaces_status ON hanger_spaces(status);
CREATE INDEX idx_hanger_spaces_started_at ON hanger_spaces(started_at DESC);
-- Composite index for fast "is this user currently live?" lookups (LIVE indicator)
CREATE INDEX idx_hanger_spaces_host_live ON hanger_spaces(host_id, status) WHERE status = 'live';

ALTER TABLE hanger_spaces ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can view spaces" ON hanger_spaces FOR SELECT USING (TRUE);
CREATE POLICY "Users can create spaces" ON hanger_spaces FOR INSERT
    WITH CHECK (host_id = auth.uid());
CREATE POLICY "Host can update own space" ON hanger_spaces FOR UPDATE
    USING (host_id = auth.uid());
CREATE POLICY "Host can delete own space" ON hanger_spaces FOR DELETE
    USING (host_id = auth.uid());

-- 2. hanger_space_participants - Who's in the room
CREATE TABLE IF NOT EXISTS hanger_space_participants (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    space_id UUID NOT NULL REFERENCES hanger_spaces(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    role TEXT NOT NULL DEFAULT 'listener' CHECK (role IN ('host', 'speaker', 'listener')),
    joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    left_at TIMESTAMPTZ,
    CONSTRAINT hanger_space_participants_unique UNIQUE (space_id, user_id)
);

CREATE INDEX idx_hanger_space_participants_space_id ON hanger_space_participants(space_id);
CREATE INDEX idx_hanger_space_participants_user_id ON hanger_space_participants(user_id);

ALTER TABLE hanger_space_participants ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can view participants" ON hanger_space_participants FOR SELECT USING (TRUE);
CREATE POLICY "Users can join spaces" ON hanger_space_participants FOR INSERT
    WITH CHECK (user_id = auth.uid());
CREATE POLICY "Users can update own participation" ON hanger_space_participants FOR UPDATE
    USING (user_id = auth.uid());
CREATE POLICY "Users can leave spaces" ON hanger_space_participants FOR DELETE
    USING (user_id = auth.uid());
CREATE POLICY "Host can update participants" ON hanger_space_participants FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM hanger_spaces
            WHERE hanger_spaces.id = hanger_space_participants.space_id
            AND hanger_spaces.host_id = auth.uid()
        )
    );
CREATE POLICY "Host can remove participants" ON hanger_space_participants FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM hanger_spaces
            WHERE hanger_spaces.id = hanger_space_participants.space_id
            AND hanger_spaces.host_id = auth.uid()
        )
    );

-- 3. hanger_space_speaker_requests - Listeners requesting to speak
CREATE TABLE IF NOT EXISTS hanger_space_speaker_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    space_id UUID NOT NULL REFERENCES hanger_spaces(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'declined')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT hanger_space_speaker_requests_unique UNIQUE (space_id, user_id)
);

ALTER TABLE hanger_space_speaker_requests ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can view speaker requests" ON hanger_space_speaker_requests FOR SELECT USING (TRUE);
CREATE POLICY "Users can request to speak" ON hanger_space_speaker_requests FOR INSERT
    WITH CHECK (user_id = auth.uid());
CREATE POLICY "Host can update speaker requests" ON hanger_space_speaker_requests FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM hanger_spaces
            WHERE hanger_spaces.id = hanger_space_speaker_requests.space_id
            AND hanger_spaces.host_id = auth.uid()
        )
    );

-- 4. Trigger for auto-updating participant counts
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
        IF OLD.role != NEW.role THEN
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

CREATE TRIGGER hanger_space_participant_count_trigger
    AFTER INSERT OR DELETE OR UPDATE ON hanger_space_participants
    FOR EACH ROW EXECUTE FUNCTION update_hanger_space_counts();

-- 5. Enable Supabase Realtime for space tables
ALTER PUBLICATION supabase_realtime ADD TABLE hanger_spaces;
ALTER PUBLICATION supabase_realtime ADD TABLE hanger_space_participants;
ALTER PUBLICATION supabase_realtime ADD TABLE hanger_space_speaker_requests;
