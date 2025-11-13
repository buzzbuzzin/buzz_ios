-- Migration: Add Case-Insensitive Unique Constraint for Call Signs
-- This migration ensures:
-- 1. Call signs are case-insensitive unique (e.g., "SkyForge" and "skyforge" are treated as the same)
-- 2. Call signs are stored in uppercase by default
-- 3. Only letters are allowed (no numbers or special characters)
-- 4. Reserved word "Maverick" cannot be used

-- Step 1: Drop the existing case-sensitive unique constraint on call_sign
-- We'll replace it with a case-insensitive one
DO $$ 
BEGIN
    -- Drop existing unique constraint if it exists
    IF EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'profiles_call_sign_key'
    ) THEN
        ALTER TABLE profiles DROP CONSTRAINT profiles_call_sign_key;
    END IF;
END $$;

-- Step 2: Normalize all existing call signs to uppercase
UPDATE profiles 
SET call_sign = UPPER(call_sign) 
WHERE call_sign IS NOT NULL 
  AND call_sign != UPPER(call_sign);

-- Step 3: Create a unique index on UPPER(call_sign) for case-insensitive uniqueness
-- This ensures "SkyForge" and "skyforge" cannot both exist
CREATE UNIQUE INDEX IF NOT EXISTS profiles_call_sign_upper_unique 
ON profiles (UPPER(call_sign)) 
WHERE call_sign IS NOT NULL;

-- Step 4: Add a check constraint to ensure call_sign only contains letters
-- This prevents numbers, spaces, and special characters
ALTER TABLE profiles 
DROP CONSTRAINT IF EXISTS profiles_call_sign_letters_only;

ALTER TABLE profiles 
ADD CONSTRAINT profiles_call_sign_letters_only 
CHECK (
    call_sign IS NULL 
    OR call_sign ~ '^[A-Z]+$'
);

-- Step 5: Create a function to validate call_sign on insert/update
-- This will also prevent reserved words like "MAVERICK"
CREATE OR REPLACE FUNCTION validate_call_sign()
RETURNS TRIGGER AS $$
BEGIN
    -- Normalize call_sign to uppercase
    IF NEW.call_sign IS NOT NULL THEN
        NEW.call_sign := UPPER(TRIM(NEW.call_sign));
        
        -- Check for reserved words
        IF NEW.call_sign = 'MAVERICK' THEN
            RAISE EXCEPTION 'Call sign "Maverick" is reserved and cannot be used';
        END IF;
        
        -- Ensure only letters (this is also enforced by check constraint, but we validate here too)
        IF NEW.call_sign !~ '^[A-Z]+$' THEN
            RAISE EXCEPTION 'Call sign can only contain letters (A-Z)';
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Step 6: Create trigger to automatically normalize and validate call_sign
DROP TRIGGER IF EXISTS validate_call_sign_trigger ON profiles;

CREATE TRIGGER validate_call_sign_trigger
    BEFORE INSERT OR UPDATE OF call_sign ON profiles
    FOR EACH ROW
    EXECUTE FUNCTION validate_call_sign();

-- Step 7: Add comment for documentation
COMMENT ON COLUMN profiles.call_sign IS 
'Pilot call sign - must be unique (case-insensitive), uppercase, letters only. Reserved words like "MAVERICK" are not allowed.';

