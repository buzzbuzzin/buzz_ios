-- Add selected_region column to profiles table for course filtering
ALTER TABLE public.profiles
ADD COLUMN selected_region text CHECK (selected_region IS NULL OR selected_region = ANY (ARRAY[
    'Canada'::text,
    'USA'::text,
    'UK'::text,
    'Australia'::text,
    'New Zealand'::text,
    'South Africa'::text,
    'Other'::text,
    'Global'::text
]));