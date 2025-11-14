-- Create Direct Messages Table
-- This table stores direct messages between users (not tied to bookings)

CREATE TABLE IF NOT EXISTS direct_messages (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    from_user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    to_user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    text TEXT NOT NULL,
    is_read BOOLEAN DEFAULT FALSE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()) NOT NULL,
    deleted_at TIMESTAMP WITH TIME ZONE,
    deleted_by UUID REFERENCES profiles(id)
);

-- Enable Row Level Security
ALTER TABLE direct_messages ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view their direct messages" ON direct_messages;
DROP POLICY IF EXISTS "Users can send direct messages" ON direct_messages;
DROP POLICY IF EXISTS "Users can update their direct messages" ON direct_messages;

-- Direct Messages Policies
CREATE POLICY "Users can view their direct messages"
    ON direct_messages FOR SELECT
    TO authenticated
    USING (
        auth.uid() = from_user_id 
        OR auth.uid() = to_user_id
    );

CREATE POLICY "Users can send direct messages"
    ON direct_messages FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = from_user_id);

CREATE POLICY "Users can update their direct messages"
    ON direct_messages FOR UPDATE
    TO authenticated
    USING (auth.uid() = from_user_id);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_direct_messages_from_user_id ON direct_messages(from_user_id);
CREATE INDEX IF NOT EXISTS idx_direct_messages_to_user_id ON direct_messages(to_user_id);
CREATE INDEX IF NOT EXISTS idx_direct_messages_created_at ON direct_messages(created_at);
CREATE INDEX IF NOT EXISTS idx_direct_messages_conversation ON direct_messages(from_user_id, to_user_id, created_at);
CREATE INDEX IF NOT EXISTS idx_direct_messages_deleted_at ON direct_messages(deleted_at);

