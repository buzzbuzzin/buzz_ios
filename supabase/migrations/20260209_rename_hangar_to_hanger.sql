-- ============================================================================
-- Rename hangar_* tables to hanger_*
-- Migration: 20260209_rename_hangar_to_hanger.sql
-- Description: Renames all hangar-prefixed tables, indexes, constraints,
--              triggers, and functions to use the correct spelling "hanger".
-- ============================================================================

-- ============================================================
-- 1. Drop existing triggers (they reference old function names)
-- ============================================================

DROP TRIGGER IF EXISTS hangar_post_like_count_trigger ON hangar_likes;
DROP TRIGGER IF EXISTS hangar_comment_like_count_trigger ON hangar_likes;
DROP TRIGGER IF EXISTS hangar_post_comment_count_trigger ON hangar_comments;

-- ============================================================
-- 2. Drop existing functions (they reference old table names)
-- ============================================================

DROP FUNCTION IF EXISTS update_hangar_post_like_count();
DROP FUNCTION IF EXISTS update_hangar_comment_like_count();
DROP FUNCTION IF EXISTS update_hangar_post_comment_count();

-- ============================================================
-- 3. Rename all 9 tables
--    (RLS policies automatically stay attached to the table)
-- ============================================================

ALTER TABLE hangar_topics RENAME TO hanger_topics;
ALTER TABLE hangar_posts RENAME TO hanger_posts;
ALTER TABLE hangar_comments RENAME TO hanger_comments;
ALTER TABLE hangar_likes RENAME TO hanger_likes;
ALTER TABLE hangar_saved_posts RENAME TO hanger_saved_posts;
ALTER TABLE hangar_followed_posts RENAME TO hanger_followed_posts;
ALTER TABLE hangar_hidden_posts RENAME TO hanger_hidden_posts;
ALTER TABLE hangar_saved_comments RENAME TO hanger_saved_comments;
ALTER TABLE hangar_followed_comments RENAME TO hanger_followed_comments;

-- ============================================================
-- 4. Rename indexes
-- ============================================================

-- hanger_posts indexes
ALTER INDEX IF EXISTS idx_hangar_posts_topic_id RENAME TO idx_hanger_posts_topic_id;
ALTER INDEX IF EXISTS idx_hangar_posts_author_id RENAME TO idx_hanger_posts_author_id;
ALTER INDEX IF EXISTS idx_hangar_posts_created_at RENAME TO idx_hanger_posts_created_at;

-- hanger_comments indexes
ALTER INDEX IF EXISTS idx_hangar_comments_post_id RENAME TO idx_hanger_comments_post_id;
ALTER INDEX IF EXISTS idx_hangar_comments_parent_id RENAME TO idx_hanger_comments_parent_id;
ALTER INDEX IF EXISTS idx_hangar_comments_author_id RENAME TO idx_hanger_comments_author_id;

-- hanger_likes indexes
ALTER INDEX IF EXISTS idx_hangar_likes_user_id RENAME TO idx_hanger_likes_user_id;
ALTER INDEX IF EXISTS idx_hangar_likes_post_id RENAME TO idx_hanger_likes_post_id;
ALTER INDEX IF EXISTS idx_hangar_likes_comment_id RENAME TO idx_hanger_likes_comment_id;

-- hanger_saved_posts indexes
ALTER INDEX IF EXISTS idx_hangar_saved_posts_user_id RENAME TO idx_hanger_saved_posts_user_id;
ALTER INDEX IF EXISTS idx_hangar_saved_posts_post_id RENAME TO idx_hanger_saved_posts_post_id;

-- hanger_followed_posts indexes
ALTER INDEX IF EXISTS idx_hangar_followed_posts_user_id RENAME TO idx_hanger_followed_posts_user_id;
ALTER INDEX IF EXISTS idx_hangar_followed_posts_post_id RENAME TO idx_hanger_followed_posts_post_id;

-- hanger_hidden_posts indexes
ALTER INDEX IF EXISTS idx_hangar_hidden_posts_user_id RENAME TO idx_hanger_hidden_posts_user_id;
ALTER INDEX IF EXISTS idx_hangar_hidden_posts_post_id RENAME TO idx_hanger_hidden_posts_post_id;

-- hanger_saved_comments indexes
ALTER INDEX IF EXISTS idx_hangar_saved_comments_user_id RENAME TO idx_hanger_saved_comments_user_id;
ALTER INDEX IF EXISTS idx_hangar_saved_comments_comment_id RENAME TO idx_hanger_saved_comments_comment_id;

-- hanger_followed_comments indexes
ALTER INDEX IF EXISTS idx_hangar_followed_comments_user_id RENAME TO idx_hanger_followed_comments_user_id;
ALTER INDEX IF EXISTS idx_hangar_followed_comments_comment_id RENAME TO idx_hanger_followed_comments_comment_id;

-- ============================================================
-- 5. Rename constraints
-- ============================================================

ALTER TABLE hanger_likes RENAME CONSTRAINT hangar_likes_target_check TO hanger_likes_target_check;
ALTER TABLE hanger_likes RENAME CONSTRAINT hangar_likes_unique_post TO hanger_likes_unique_post;
ALTER TABLE hanger_likes RENAME CONSTRAINT hangar_likes_unique_comment TO hanger_likes_unique_comment;
ALTER TABLE hanger_saved_posts RENAME CONSTRAINT hangar_saved_posts_unique TO hanger_saved_posts_unique;
ALTER TABLE hanger_followed_posts RENAME CONSTRAINT hangar_followed_posts_unique TO hanger_followed_posts_unique;
ALTER TABLE hanger_hidden_posts RENAME CONSTRAINT hangar_hidden_posts_unique TO hanger_hidden_posts_unique;
ALTER TABLE hanger_saved_comments RENAME CONSTRAINT hangar_saved_comments_unique TO hanger_saved_comments_unique;
ALTER TABLE hanger_followed_comments RENAME CONSTRAINT hangar_followed_comments_unique TO hanger_followed_comments_unique;

-- ============================================================
-- 6. Recreate functions with new table names
-- ============================================================

-- Post like count trigger function
CREATE OR REPLACE FUNCTION update_hanger_post_like_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' AND NEW.post_id IS NOT NULL THEN
        UPDATE hanger_posts SET like_count = like_count + 1 WHERE id = NEW.post_id;
    ELSIF TG_OP = 'DELETE' AND OLD.post_id IS NOT NULL THEN
        UPDATE hanger_posts SET like_count = GREATEST(like_count - 1, 0) WHERE id = OLD.post_id;
    END IF;
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Comment like count trigger function
CREATE OR REPLACE FUNCTION update_hanger_comment_like_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' AND NEW.comment_id IS NOT NULL THEN
        UPDATE hanger_comments SET like_count = like_count + 1 WHERE id = NEW.comment_id;
    ELSIF TG_OP = 'DELETE' AND OLD.comment_id IS NOT NULL THEN
        UPDATE hanger_comments SET like_count = GREATEST(like_count - 1, 0) WHERE id = OLD.comment_id;
    END IF;
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Post comment count trigger function
CREATE OR REPLACE FUNCTION update_hanger_post_comment_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE hanger_posts SET comment_count = comment_count + 1 WHERE id = NEW.post_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE hanger_posts SET comment_count = GREATEST(comment_count - 1, 0) WHERE id = OLD.post_id;
    END IF;
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 7. Recreate triggers on renamed tables
-- ============================================================

CREATE TRIGGER hanger_post_like_count_trigger
    AFTER INSERT OR DELETE ON hanger_likes
    FOR EACH ROW EXECUTE FUNCTION update_hanger_post_like_count();

CREATE TRIGGER hanger_comment_like_count_trigger
    AFTER INSERT OR DELETE ON hanger_likes
    FOR EACH ROW EXECUTE FUNCTION update_hanger_comment_like_count();

CREATE TRIGGER hanger_post_comment_count_trigger
    AFTER INSERT OR DELETE ON hanger_comments
    FOR EACH ROW EXECUTE FUNCTION update_hanger_post_comment_count();
