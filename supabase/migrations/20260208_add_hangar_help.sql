-- ============================================================================
-- Hangar Help - Community Discussion Platform
-- Migration: 20260208_add_hangar_help.sql
-- Description: Creates tables for community discussion forum (topics, posts,
--              comments, likes) with RLS policies and auto-count triggers.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. hangar_topics - Predefined discussion categories
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS hangar_topics (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    description TEXT,
    icon_name TEXT NOT NULL,
    color_name TEXT NOT NULL,
    display_order INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE hangar_topics ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can view topics" ON hangar_topics FOR SELECT USING (TRUE);

-- Seed data: 6 default topic categories
INSERT INTO hangar_topics (name, description, icon_name, color_name, display_order) VALUES
    ('Regulations', 'FAA rules, Part 107, airspace questions', 'book.closed.fill', 'blue', 1),
    ('Equipment', 'Drones, cameras, accessories, repairs', 'wrench.and.screwdriver.fill', 'orange', 2),
    ('Best Practices', 'Tips, techniques, and flight procedures', 'star.fill', 'yellow', 3),
    ('Weather', 'Forecasts, METAR reading, wind advisories', 'cloud.sun.bolt.fill', 'cyan', 4),
    ('Emergencies', 'Incident reporting, emergency procedures', 'exclamationmark.triangle.fill', 'red', 5),
    ('General', 'Anything else drone-related', 'bubble.left.and.bubble.right.fill', 'green', 6);

-- ----------------------------------------------------------------------------
-- 2. hangar_posts - User discussion posts within topics
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS hangar_posts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    topic_id UUID NOT NULL REFERENCES hangar_topics(id) ON DELETE CASCADE,
    author_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    like_count INTEGER NOT NULL DEFAULT 0,
    comment_count INTEGER NOT NULL DEFAULT 0,
    is_pinned BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_hangar_posts_topic_id ON hangar_posts(topic_id);
CREATE INDEX IF NOT EXISTS idx_hangar_posts_author_id ON hangar_posts(author_id);
CREATE INDEX IF NOT EXISTS idx_hangar_posts_created_at ON hangar_posts(created_at DESC);

ALTER TABLE hangar_posts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can view all posts" ON hangar_posts FOR SELECT USING (TRUE);
CREATE POLICY "Users can create posts" ON hangar_posts FOR INSERT WITH CHECK (author_id = auth.uid());
CREATE POLICY "Users can update their own posts" ON hangar_posts FOR UPDATE USING (author_id = auth.uid());
CREATE POLICY "Users can delete their own posts" ON hangar_posts FOR DELETE USING (author_id = auth.uid());

-- ----------------------------------------------------------------------------
-- 3. hangar_comments - Threaded replies to posts
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS hangar_comments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    post_id UUID NOT NULL REFERENCES hangar_posts(id) ON DELETE CASCADE,
    parent_comment_id UUID REFERENCES hangar_comments(id) ON DELETE CASCADE,
    author_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    body TEXT NOT NULL,
    like_count INTEGER NOT NULL DEFAULT 0,
    depth INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_hangar_comments_post_id ON hangar_comments(post_id);
CREATE INDEX IF NOT EXISTS idx_hangar_comments_parent_id ON hangar_comments(parent_comment_id);
CREATE INDEX IF NOT EXISTS idx_hangar_comments_author_id ON hangar_comments(author_id);

ALTER TABLE hangar_comments ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can view all comments" ON hangar_comments FOR SELECT USING (TRUE);
CREATE POLICY "Users can create comments" ON hangar_comments FOR INSERT WITH CHECK (author_id = auth.uid());
CREATE POLICY "Users can update their own comments" ON hangar_comments FOR UPDATE USING (author_id = auth.uid());
CREATE POLICY "Users can delete their own comments" ON hangar_comments FOR DELETE USING (author_id = auth.uid());

-- ----------------------------------------------------------------------------
-- 4. hangar_likes - Likes/upvotes on posts and comments
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS hangar_likes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    post_id UUID REFERENCES hangar_posts(id) ON DELETE CASCADE,
    comment_id UUID REFERENCES hangar_comments(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT hangar_likes_target_check CHECK (
        (post_id IS NOT NULL AND comment_id IS NULL) OR
        (post_id IS NULL AND comment_id IS NOT NULL)
    ),
    CONSTRAINT hangar_likes_unique_post UNIQUE (user_id, post_id),
    CONSTRAINT hangar_likes_unique_comment UNIQUE (user_id, comment_id)
);

CREATE INDEX IF NOT EXISTS idx_hangar_likes_user_id ON hangar_likes(user_id);
CREATE INDEX IF NOT EXISTS idx_hangar_likes_post_id ON hangar_likes(post_id);
CREATE INDEX IF NOT EXISTS idx_hangar_likes_comment_id ON hangar_likes(comment_id);

ALTER TABLE hangar_likes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can view all likes" ON hangar_likes FOR SELECT USING (TRUE);
CREATE POLICY "Users can create their own likes" ON hangar_likes FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY "Users can delete their own likes" ON hangar_likes FOR DELETE USING (user_id = auth.uid());

-- ----------------------------------------------------------------------------
-- 5. Triggers - Auto-update like_count and comment_count
-- ----------------------------------------------------------------------------

-- Post like count trigger
CREATE OR REPLACE FUNCTION update_hangar_post_like_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' AND NEW.post_id IS NOT NULL THEN
        UPDATE hangar_posts SET like_count = like_count + 1 WHERE id = NEW.post_id;
    ELSIF TG_OP = 'DELETE' AND OLD.post_id IS NOT NULL THEN
        UPDATE hangar_posts SET like_count = GREATEST(like_count - 1, 0) WHERE id = OLD.post_id;
    END IF;
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER hangar_post_like_count_trigger
    AFTER INSERT OR DELETE ON hangar_likes
    FOR EACH ROW EXECUTE FUNCTION update_hangar_post_like_count();

-- Comment like count trigger
CREATE OR REPLACE FUNCTION update_hangar_comment_like_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' AND NEW.comment_id IS NOT NULL THEN
        UPDATE hangar_comments SET like_count = like_count + 1 WHERE id = NEW.comment_id;
    ELSIF TG_OP = 'DELETE' AND OLD.comment_id IS NOT NULL THEN
        UPDATE hangar_comments SET like_count = GREATEST(like_count - 1, 0) WHERE id = OLD.comment_id;
    END IF;
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER hangar_comment_like_count_trigger
    AFTER INSERT OR DELETE ON hangar_likes
    FOR EACH ROW EXECUTE FUNCTION update_hangar_comment_like_count();

-- Post comment count trigger
CREATE OR REPLACE FUNCTION update_hangar_post_comment_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE hangar_posts SET comment_count = comment_count + 1 WHERE id = NEW.post_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE hangar_posts SET comment_count = GREATEST(comment_count - 1, 0) WHERE id = OLD.post_id;
    END IF;
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER hangar_post_comment_count_trigger
    AFTER INSERT OR DELETE ON hangar_comments
    FOR EACH ROW EXECUTE FUNCTION update_hangar_post_comment_count();
