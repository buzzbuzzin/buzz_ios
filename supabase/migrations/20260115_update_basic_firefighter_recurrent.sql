-- Migration: Update Basic Fire Fighter badge to not be recurrent
-- Description: Removes the "Recurrent" designation from the Basic Fire Fighter badge

-- Update the badges_catalog table to set is_recurrent to false for Basic Fire Fighter
UPDATE public.badges_catalog
SET is_recurrent = false
WHERE badge_type = 'basic_firefighter';

-- Update any existing Basic Fire Fighter badges in the badges table
-- to also have is_recurrent = false
UPDATE public.badges
SET is_recurrent = false
WHERE badge_type = 'basic_firefighter';
