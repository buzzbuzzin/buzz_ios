-- Add metadata JSONB column for rich message content (listing cards, etc.)
ALTER TABLE public.direct_messages
ADD COLUMN metadata JSONB DEFAULT NULL;
