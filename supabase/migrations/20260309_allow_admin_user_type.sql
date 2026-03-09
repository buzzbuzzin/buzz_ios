-- Allow 'admin' as a valid user_type in profiles.
-- The edge function update-license-approval and DB functions
-- approve_test_result / reject_test_result already check for
-- user_type = 'admin', but the CHECK constraint was never updated.

ALTER TABLE public.profiles
  DROP CONSTRAINT profiles_user_type_check,
  ADD CONSTRAINT profiles_user_type_check
    CHECK (user_type = ANY (ARRAY['pilot', 'customer', 'admin']));
