-- ============================================================================
-- Hangar Help - Save, Follow, Hide Actions
-- Migration: 20260208_add_hangar_actions.sql
-- Description: Creates tables for saving, following posts/comments, and hiding posts.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. hangar_saved_posts - Users can save/bookmark posts
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS hangar_saved_posts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    post_id UUID NOT NULL REFERENCES hangar_posts(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT hangar_saved_posts_unique UNIQUE (user_id, post_id)
);

CREATE INDEX IF NOT EXISTS idx_hangar_saved_posts_user_id ON hangar_saved_posts(user_id);
CREATE INDEX IF NOT EXISTS idx_hangar_saved_posts_post_id ON hangar_saved_posts(post_id);

ALTER TABLE hangar_saved_posts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view their own saved posts" ON hangar_saved_posts FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "Users can save posts" ON hangar_saved_posts FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY "Users can unsave posts" ON hangar_saved_posts FOR DELETE USING (user_id = auth.uid());

-- ----------------------------------------------------------------------------
-- 2. hangar_followed_posts - Users can follow posts for notifications
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS hangar_followed_posts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    post_id UUID NOT NULL REFERENCES hangar_posts(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT hangar_followed_posts_unique UNIQUE (user_id, post_id)
);

CREATE INDEX IF NOT EXISTS idx_hangar_followed_posts_user_id ON hangar_followed_posts(user_id);
CREATE INDEX IF NOT EXISTS idx_hangar_followed_posts_post_id ON hangar_followed_posts(post_id);

ALTER TABLE hangar_followed_posts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view their own followed posts" ON hangar_followed_posts FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "Users can follow posts" ON hangar_followed_posts FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY "Users can unfollow posts" ON hangar_followed_posts FOR DELETE USING (user_id = auth.uid());

-- ----------------------------------------------------------------------------
-- 3. hangar_hidden_posts - Users can hide posts from their feed
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS hangar_hidden_posts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    post_id UUID NOT NULL REFERENCES hangar_posts(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT hangar_hidden_posts_unique UNIQUE (user_id, post_id)
);

CREATE INDEX IF NOT EXISTS idx_hangar_hidden_posts_user_id ON hangar_hidden_posts(user_id);
CREATE INDEX IF NOT EXISTS idx_hangar_hidden_posts_post_id ON hangar_hidden_posts(post_id);

ALTER TABLE hangar_hidden_posts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view their own hidden posts" ON hangar_hidden_posts FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "Users can hide posts" ON hangar_hidden_posts FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY "Users can unhide posts" ON hangar_hidden_posts FOR DELETE USING (user_id = auth.uid());

-- ----------------------------------------------------------------------------
-- 4. hangar_saved_comments - Users can save/bookmark comments
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS hangar_saved_comments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    comment_id UUID NOT NULL REFERENCES hangar_comments(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT hangar_saved_comments_unique UNIQUE (user_id, comment_id)
);

CREATE INDEX IF NOT EXISTS idx_hangar_saved_comments_user_id ON hangar_saved_comments(user_id);
CREATE INDEX IF NOT EXISTS idx_hangar_saved_comments_comment_id ON hangar_saved_comments(comment_id);

ALTER TABLE hangar_saved_comments ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view their own saved comments" ON hangar_saved_comments FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "Users can save comments" ON hangar_saved_comments FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY "Users can unsave comments" ON hangar_saved_comments FOR DELETE USING (user_id = auth.uid());

-- ----------------------------------------------------------------------------
-- 5. hangar_followed_comments - Users can follow comments for notifications
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS hangar_followed_comments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    comment_id UUID NOT NULL REFERENCES hangar_comments(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT hangar_followed_comments_unique UNIQUE (user_id, comment_id)
);

CREATE INDEX IF NOT EXISTS idx_hangar_followed_comments_user_id ON hangar_followed_comments(user_id);
CREATE INDEX IF NOT EXISTS idx_hangar_followed_comments_comment_id ON hangar_followed_comments(comment_id);

ALTER TABLE hangar_followed_comments ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view their own followed comments" ON hangar_followed_comments FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "Users can follow comments" ON hangar_followed_comments FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY "Users can unfollow comments" ON hangar_followed_comments FOR DELETE USING (user_id = auth.uid());
