-- Fix counter trigger functions to use SECURITY DEFINER
-- so they can update posts owned by other users.
--
-- Problem: RLS policy "Users can update own posts" restricts UPDATE
-- to author_id = auth.uid(). When user A replies to/likes/reposts
-- user B's post, the trigger UPDATE is blocked by RLS because
-- auth.uid() is user A, not user B.
--
-- Solution: SECURITY DEFINER makes the function run as the owner
-- (postgres), bypassing RLS for counter updates.

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
$$ LANGUAGE plpgsql SECURITY DEFINER;

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
$$ LANGUAGE plpgsql SECURITY DEFINER;

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
$$ LANGUAGE plpgsql SECURITY DEFINER;
