-- ============================================================================
-- Message Reactions
-- Migration: 20260306_add_message_reactions.sql
-- Description: Adds persisted reactions for booking and direct messages.
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.booking_message_reactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    booking_message_id UUID NOT NULL REFERENCES public.messages(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    reaction TEXT NOT NULL CHECK (reaction IN ('like', 'dislike', 'love', 'haha', 'emphasize', 'question')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT booking_message_reactions_unique UNIQUE (booking_message_id, user_id)
);

CREATE INDEX idx_booking_message_reactions_message_id
    ON public.booking_message_reactions(booking_message_id);

CREATE INDEX idx_booking_message_reactions_user_id
    ON public.booking_message_reactions(user_id);

CREATE TABLE IF NOT EXISTS public.direct_message_reactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    direct_message_id UUID NOT NULL REFERENCES public.direct_messages(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    reaction TEXT NOT NULL CHECK (reaction IN ('like', 'dislike', 'love', 'haha', 'emphasize', 'question')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT direct_message_reactions_unique UNIQUE (direct_message_id, user_id)
);

CREATE INDEX idx_direct_message_reactions_message_id
    ON public.direct_message_reactions(direct_message_id);

CREATE INDEX idx_direct_message_reactions_user_id
    ON public.direct_message_reactions(user_id);

CREATE OR REPLACE FUNCTION public.message_reactions_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER booking_message_reactions_set_updated_at
    BEFORE UPDATE ON public.booking_message_reactions
    FOR EACH ROW EXECUTE FUNCTION public.message_reactions_set_updated_at();

CREATE TRIGGER direct_message_reactions_set_updated_at
    BEFORE UPDATE ON public.direct_message_reactions
    FOR EACH ROW EXECUTE FUNCTION public.message_reactions_set_updated_at();

ALTER TABLE public.booking_message_reactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.direct_message_reactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Conversation participants can view booking message reactions"
ON public.booking_message_reactions FOR SELECT
USING (
    EXISTS (
        SELECT 1
        FROM public.messages m
        WHERE m.id = booking_message_reactions.booking_message_id
          AND auth.uid() IN (m.from_user_id, m.to_user_id)
    )
);

CREATE POLICY "Users can add booking message reactions"
ON public.booking_message_reactions FOR INSERT
WITH CHECK (
    user_id = auth.uid()
    AND EXISTS (
        SELECT 1
        FROM public.messages m
        WHERE m.id = booking_message_reactions.booking_message_id
          AND auth.uid() IN (m.from_user_id, m.to_user_id)
    )
);

CREATE POLICY "Users can update booking message reactions"
ON public.booking_message_reactions FOR UPDATE
USING (
    user_id = auth.uid()
    AND EXISTS (
        SELECT 1
        FROM public.messages m
        WHERE m.id = booking_message_reactions.booking_message_id
          AND auth.uid() IN (m.from_user_id, m.to_user_id)
    )
)
WITH CHECK (
    user_id = auth.uid()
    AND EXISTS (
        SELECT 1
        FROM public.messages m
        WHERE m.id = booking_message_reactions.booking_message_id
          AND auth.uid() IN (m.from_user_id, m.to_user_id)
    )
);

CREATE POLICY "Users can delete booking message reactions"
ON public.booking_message_reactions FOR DELETE
USING (
    user_id = auth.uid()
    AND EXISTS (
        SELECT 1
        FROM public.messages m
        WHERE m.id = booking_message_reactions.booking_message_id
          AND auth.uid() IN (m.from_user_id, m.to_user_id)
    )
);

CREATE POLICY "Conversation participants can view direct message reactions"
ON public.direct_message_reactions FOR SELECT
USING (
    EXISTS (
        SELECT 1
        FROM public.direct_messages dm
        WHERE dm.id = direct_message_reactions.direct_message_id
          AND auth.uid() IN (dm.from_user_id, dm.to_user_id)
    )
);

CREATE POLICY "Users can add direct message reactions"
ON public.direct_message_reactions FOR INSERT
WITH CHECK (
    user_id = auth.uid()
    AND EXISTS (
        SELECT 1
        FROM public.direct_messages dm
        WHERE dm.id = direct_message_reactions.direct_message_id
          AND auth.uid() IN (dm.from_user_id, dm.to_user_id)
    )
);

CREATE POLICY "Users can update direct message reactions"
ON public.direct_message_reactions FOR UPDATE
USING (
    user_id = auth.uid()
    AND EXISTS (
        SELECT 1
        FROM public.direct_messages dm
        WHERE dm.id = direct_message_reactions.direct_message_id
          AND auth.uid() IN (dm.from_user_id, dm.to_user_id)
    )
)
WITH CHECK (
    user_id = auth.uid()
    AND EXISTS (
        SELECT 1
        FROM public.direct_messages dm
        WHERE dm.id = direct_message_reactions.direct_message_id
          AND auth.uid() IN (dm.from_user_id, dm.to_user_id)
    )
);

CREATE POLICY "Users can delete direct message reactions"
ON public.direct_message_reactions FOR DELETE
USING (
    user_id = auth.uid()
    AND EXISTS (
        SELECT 1
        FROM public.direct_messages dm
        WHERE dm.id = direct_message_reactions.direct_message_id
          AND auth.uid() IN (dm.from_user_id, dm.to_user_id)
    )
);
