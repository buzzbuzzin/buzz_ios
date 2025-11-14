-- Add Soft Delete Columns to Messages Tables
-- This migration adds deleted_at and deleted_by columns for soft delete functionality
-- Messages will be kept on server for 7 days before permanent deletion

-- Add columns to messages table
ALTER TABLE messages ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE messages ADD COLUMN IF NOT EXISTS deleted_by UUID REFERENCES profiles(id);

-- Add columns to direct_messages table
ALTER TABLE direct_messages ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE direct_messages ADD COLUMN IF NOT EXISTS deleted_by UUID REFERENCES profiles(id);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_messages_deleted_at ON messages(deleted_at);
CREATE INDEX IF NOT EXISTS idx_direct_messages_deleted_at ON direct_messages(deleted_at);

-- Function to permanently delete old soft-deleted messages
CREATE OR REPLACE FUNCTION delete_old_soft_deleted_messages()
RETURNS void AS $$
BEGIN
    -- Delete messages soft-deleted more than 7 days ago
    DELETE FROM messages
    WHERE deleted_at IS NOT NULL
    AND deleted_at < NOW() - INTERVAL '7 days';
    
    -- Delete direct messages soft-deleted more than 7 days ago
    DELETE FROM direct_messages
    WHERE deleted_at IS NOT NULL
    AND deleted_at < NOW() - INTERVAL '7 days';
END;
$$ LANGUAGE plpgsql;

-- Create a scheduled job to run cleanup daily
-- Note: This requires pg_cron extension (available in Supabase)
-- Uncomment the following lines if pg_cron is available:
-- CREATE EXTENSION IF NOT EXISTS pg_cron;
-- SELECT cron.schedule('delete-old-messages', '0 2 * * *', 'SELECT delete_old_soft_deleted_messages()');

-- Alternative: Create a trigger-based approach for auto-deletion
-- This function will be called when querying messages to filter out old deleted ones
CREATE OR REPLACE FUNCTION filter_deleted_messages()
RETURNS TRIGGER AS $$
BEGIN
    -- Automatically hard-delete messages that have been soft-deleted for more than 7 days
    DELETE FROM messages
    WHERE deleted_at IS NOT NULL
    AND deleted_at < NOW() - INTERVAL '7 days';
    
    DELETE FROM direct_messages
    WHERE deleted_at IS NOT NULL
    AND deleted_at < NOW() - INTERVAL '7 days';
    
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Update RLS policies to exclude soft-deleted messages from queries
-- Messages table
DROP POLICY IF EXISTS "Users can view their messages (excluding deleted)" ON messages;
CREATE POLICY "Users can view their messages (excluding deleted)"
    ON messages FOR SELECT
    TO authenticated
    USING (
        (auth.uid() = from_user_id OR auth.uid() = to_user_id)
        AND (deleted_at IS NULL OR deleted_by != auth.uid())
    );

-- Direct Messages table
DROP POLICY IF EXISTS "Users can view their direct messages (excluding deleted)" ON direct_messages;
CREATE POLICY "Users can view their direct messages (excluding deleted)"
    ON direct_messages FOR SELECT
    TO authenticated
    USING (
        (auth.uid() = from_user_id OR auth.uid() = to_user_id)
        AND (deleted_at IS NULL OR deleted_by != auth.uid())
    );

-- Allow users to update deleted_at and deleted_by columns
DROP POLICY IF EXISTS "Users can update their direct messages" ON direct_messages;
CREATE POLICY "Users can update their direct messages"
    ON direct_messages FOR UPDATE
    TO authenticated
    USING (auth.uid() = from_user_id OR auth.uid() = to_user_id);

DROP POLICY IF EXISTS "Users can update their messages" ON messages;
CREATE POLICY "Users can update their messages"
    ON messages FOR UPDATE
    TO authenticated
    USING (auth.uid() = from_user_id OR auth.uid() = to_user_id);

