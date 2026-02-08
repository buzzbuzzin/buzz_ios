-- Add image_urls array column to hangar_posts
ALTER TABLE hangar_posts ADD COLUMN image_urls text[] DEFAULT '{}';
