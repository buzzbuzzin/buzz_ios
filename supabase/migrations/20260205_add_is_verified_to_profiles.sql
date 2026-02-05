-- Add is_verified column to profiles table as a manual override / fallback
-- for identity verification when no government_ids record exists.
-- Priority: government_ids.verification_status == 'verified' takes precedence.
-- This column is only checked when no government_ids record is found.

ALTER TABLE public.profiles
ADD COLUMN is_verified boolean NOT NULL DEFAULT false;

-- Auto-populate is_verified for users who already have a verified government_ids record
UPDATE public.profiles
SET is_verified = true
WHERE id IN (
    SELECT user_id FROM public.government_ids
    WHERE verification_status = 'verified'
);
