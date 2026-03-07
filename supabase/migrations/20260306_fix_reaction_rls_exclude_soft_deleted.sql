-- ============================================================================
-- Fix Reaction RLS: Exclude Soft-Deleted Messages
-- Migration: 20260306_fix_reaction_rls_exclude_soft_deleted.sql
-- Description: Updates SELECT policies to hide reactions on soft-deleted messages.
-- ============================================================================

DROP POLICY IF EXISTS "Conversation participants can view booking message reactions" ON public.booking_message_reactions;
CREATE POLICY "Conversation participants can view booking message reactions"
ON public.booking_message_reactions FOR SELECT
USING (
    EXISTS (
        SELECT 1
        FROM public.messages m
        WHERE m.id = booking_message_reactions.booking_message_id
          AND m.deleted_at IS NULL
          AND auth.uid() IN (m.from_user_id, m.to_user_id)
    )
);

DROP POLICY IF EXISTS "Conversation participants can view direct message reactions" ON public.direct_message_reactions;
CREATE POLICY "Conversation participants can view direct message reactions"
ON public.direct_message_reactions FOR SELECT
USING (
    EXISTS (
        SELECT 1
        FROM public.direct_messages dm
        WHERE dm.id = direct_message_reactions.direct_message_id
          AND dm.deleted_at IS NULL
          AND auth.uid() IN (dm.from_user_id, dm.to_user_id)
    )
);
