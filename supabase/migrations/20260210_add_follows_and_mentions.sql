-- ============================================================================
-- Follows & Mentions for Hanger Talk
-- Migration: 20260210_add_follows_and_mentions.sql
-- Description: Adds pilot-to-pilot follow relationships and @mention tracking.
-- ============================================================================

-- 1. user_follows - Pilot-to-pilot follow relationships
CREATE TABLE IF NOT EXISTS user_follows (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    follower_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    following_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT user_follows_unique UNIQUE (follower_id, following_id),
    CONSTRAINT user_follows_no_self CHECK (follower_id != following_id)
);

CREATE INDEX idx_user_follows_follower_id ON user_follows(follower_id);
CREATE INDEX idx_user_follows_following_id ON user_follows(following_id);

ALTER TABLE user_follows ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can view follows" ON user_follows FOR SELECT USING (TRUE);
CREATE POLICY "Users can follow" ON user_follows FOR INSERT
    WITH CHECK (follower_id = auth.uid());
CREATE POLICY "Users can unfollow" ON user_follows FOR DELETE
    USING (follower_id = auth.uid());

-- 2. hanger_talk_mentions - @mentions in posts/replies
CREATE TABLE IF NOT EXISTS hanger_talk_mentions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    post_id UUID NOT NULL REFERENCES hanger_talk_posts(id) ON DELETE CASCADE,
    mentioned_user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT hanger_talk_mentions_unique UNIQUE (post_id, mentioned_user_id)
);

CREATE INDEX idx_hanger_talk_mentions_post_id ON hanger_talk_mentions(post_id);
CREATE INDEX idx_hanger_talk_mentions_user_id ON hanger_talk_mentions(mentioned_user_id);

ALTER TABLE hanger_talk_mentions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can view mentions" ON hanger_talk_mentions FOR SELECT USING (TRUE);
CREATE POLICY "Post authors can create mentions" ON hanger_talk_mentions FOR INSERT
    WITH CHECK (EXISTS (
        SELECT 1 FROM hanger_talk_posts
        WHERE id = post_id AND author_id = auth.uid()
    ));
CREATE POLICY "Post authors can delete mentions" ON hanger_talk_mentions FOR DELETE
    USING (EXISTS (
        SELECT 1 FROM hanger_talk_posts
        WHERE id = post_id AND author_id = auth.uid()
    ));
