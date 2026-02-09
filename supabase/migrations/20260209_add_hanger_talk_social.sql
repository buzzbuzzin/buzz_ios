-- ============================================================================
-- Hanger Talk - Social Feed (Twitter/Threads style)
-- Migration: 20260209_add_hanger_talk_social.sql
-- Description: Creates tables for the new social media feed feature.
-- ============================================================================

-- 1. hanger_talk_posts - Main social posts ("tweets")
CREATE TABLE IF NOT EXISTS hanger_talk_posts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    author_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    body TEXT NOT NULL,
    image_urls TEXT[] DEFAULT '{}',
    like_count INTEGER NOT NULL DEFAULT 0,
    reply_count INTEGER NOT NULL DEFAULT 0,
    repost_count INTEGER NOT NULL DEFAULT 0,
    is_reply BOOLEAN NOT NULL DEFAULT FALSE,
    parent_post_id UUID REFERENCES hanger_talk_posts(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_hanger_talk_posts_author_id ON hanger_talk_posts(author_id);
CREATE INDEX idx_hanger_talk_posts_created_at ON hanger_talk_posts(created_at DESC);
CREATE INDEX idx_hanger_talk_posts_parent_id ON hanger_talk_posts(parent_post_id);

ALTER TABLE hanger_talk_posts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can view posts" ON hanger_talk_posts FOR SELECT USING (TRUE);
CREATE POLICY "Users can create posts" ON hanger_talk_posts FOR INSERT
    WITH CHECK (author_id = auth.uid());
CREATE POLICY "Users can update own posts" ON hanger_talk_posts FOR UPDATE
    USING (author_id = auth.uid());
CREATE POLICY "Users can delete own posts" ON hanger_talk_posts FOR DELETE
    USING (author_id = auth.uid());

-- 2. hanger_talk_likes - Likes on posts
CREATE TABLE IF NOT EXISTS hanger_talk_likes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    post_id UUID NOT NULL REFERENCES hanger_talk_posts(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT hanger_talk_likes_unique UNIQUE (user_id, post_id)
);

CREATE INDEX idx_hanger_talk_likes_user_id ON hanger_talk_likes(user_id);
CREATE INDEX idx_hanger_talk_likes_post_id ON hanger_talk_likes(post_id);

ALTER TABLE hanger_talk_likes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can view likes" ON hanger_talk_likes FOR SELECT USING (TRUE);
CREATE POLICY "Users can like" ON hanger_talk_likes FOR INSERT
    WITH CHECK (user_id = auth.uid());
CREATE POLICY "Users can unlike" ON hanger_talk_likes FOR DELETE
    USING (user_id = auth.uid());

-- 3. hanger_talk_reposts - Reposts/retweets
CREATE TABLE IF NOT EXISTS hanger_talk_reposts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    post_id UUID NOT NULL REFERENCES hanger_talk_posts(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT hanger_talk_reposts_unique UNIQUE (user_id, post_id)
);

CREATE INDEX idx_hanger_talk_reposts_user_id ON hanger_talk_reposts(user_id);
CREATE INDEX idx_hanger_talk_reposts_post_id ON hanger_talk_reposts(post_id);

ALTER TABLE hanger_talk_reposts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can view reposts" ON hanger_talk_reposts FOR SELECT USING (TRUE);
CREATE POLICY "Users can repost" ON hanger_talk_reposts FOR INSERT
    WITH CHECK (user_id = auth.uid());
CREATE POLICY "Users can un-repost" ON hanger_talk_reposts FOR DELETE
    USING (user_id = auth.uid());

-- 4. hanger_talk_bookmarks - Saved/bookmarked posts
CREATE TABLE IF NOT EXISTS hanger_talk_bookmarks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    post_id UUID NOT NULL REFERENCES hanger_talk_posts(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT hanger_talk_bookmarks_unique UNIQUE (user_id, post_id)
);

CREATE INDEX idx_hanger_talk_bookmarks_user_id ON hanger_talk_bookmarks(user_id);
CREATE INDEX idx_hanger_talk_bookmarks_post_id ON hanger_talk_bookmarks(post_id);

ALTER TABLE hanger_talk_bookmarks ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own bookmarks" ON hanger_talk_bookmarks FOR SELECT
    USING (user_id = auth.uid());
CREATE POLICY "Users can bookmark" ON hanger_talk_bookmarks FOR INSERT
    WITH CHECK (user_id = auth.uid());
CREATE POLICY "Users can un-bookmark" ON hanger_talk_bookmarks FOR DELETE
    USING (user_id = auth.uid());

-- 5. Triggers for auto-updating counts

-- Like count trigger
CREATE OR REPLACE FUNCTION update_hanger_talk_post_like_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE hanger_talk_posts SET like_count = like_count + 1 WHERE id = NEW.post_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE hanger_talk_posts SET like_count = GREATEST(like_count - 1, 0) WHERE id = OLD.post_id;
    END IF;
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER hanger_talk_like_count_trigger
    AFTER INSERT OR DELETE ON hanger_talk_likes
    FOR EACH ROW EXECUTE FUNCTION update_hanger_talk_post_like_count();

-- Reply count trigger
CREATE OR REPLACE FUNCTION update_hanger_talk_post_reply_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' AND NEW.parent_post_id IS NOT NULL THEN
        UPDATE hanger_talk_posts SET reply_count = reply_count + 1 WHERE id = NEW.parent_post_id;
    ELSIF TG_OP = 'DELETE' AND OLD.parent_post_id IS NOT NULL THEN
        UPDATE hanger_talk_posts SET reply_count = GREATEST(reply_count - 1, 0) WHERE id = OLD.parent_post_id;
    END IF;
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER hanger_talk_reply_count_trigger
    AFTER INSERT OR DELETE ON hanger_talk_posts
    FOR EACH ROW EXECUTE FUNCTION update_hanger_talk_post_reply_count();

-- Repost count trigger
CREATE OR REPLACE FUNCTION update_hanger_talk_post_repost_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE hanger_talk_posts SET repost_count = repost_count + 1 WHERE id = NEW.post_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE hanger_talk_posts SET repost_count = GREATEST(repost_count - 1, 0) WHERE id = OLD.post_id;
    END IF;
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER hanger_talk_repost_count_trigger
    AFTER INSERT OR DELETE ON hanger_talk_reposts
    FOR EACH ROW EXECUTE FUNCTION update_hanger_talk_post_repost_count();

-- 6. Create Supabase storage bucket for hanger_talk_images
INSERT INTO storage.buckets (id, name, public) VALUES ('hanger_talk_images', 'hanger_talk_images', true)
ON CONFLICT DO NOTHING;
