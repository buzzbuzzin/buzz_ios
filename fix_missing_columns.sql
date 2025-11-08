-- Migration script to add missing columns to bookings table
-- Run this in Supabase SQL Editor if you get "Could not find column" errors

DO $$ 
BEGIN
    -- Add end_date if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'bookings' AND column_name = 'end_date'
    ) THEN
        ALTER TABLE bookings ADD COLUMN end_date TIMESTAMP WITH TIME ZONE;
        RAISE NOTICE 'Added end_date column to bookings table';
    END IF;
    
    -- Add required_minimum_rank if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'bookings' AND column_name = 'required_minimum_rank'
    ) THEN
        ALTER TABLE bookings ADD COLUMN required_minimum_rank INTEGER DEFAULT 0;
        RAISE NOTICE 'Added required_minimum_rank column to bookings table';
    END IF;
    
    -- Add payment_intent_id if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'bookings' AND column_name = 'payment_intent_id'
    ) THEN
        ALTER TABLE bookings ADD COLUMN payment_intent_id TEXT;
        RAISE NOTICE 'Added payment_intent_id column to bookings table';
    END IF;
    
    -- Add transfer_id if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'bookings' AND column_name = 'transfer_id'
    ) THEN
        ALTER TABLE bookings ADD COLUMN transfer_id TEXT;
        RAISE NOTICE 'Added transfer_id column to bookings table';
    END IF;
    
    -- Add charge_id if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'bookings' AND column_name = 'charge_id'
    ) THEN
        ALTER TABLE bookings ADD COLUMN charge_id TEXT;
        RAISE NOTICE 'Added charge_id column to bookings table';
    END IF;
    
    -- Add stripe_account_id to profiles if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'profiles' AND column_name = 'stripe_account_id'
    ) THEN
        ALTER TABLE profiles ADD COLUMN stripe_account_id TEXT;
        RAISE NOTICE 'Added stripe_account_id column to profiles table';
    END IF;
END $$;

-- Create indexes for payment fields if they don't exist
CREATE INDEX IF NOT EXISTS idx_bookings_payment_intent_id ON bookings(payment_intent_id);
CREATE INDEX IF NOT EXISTS idx_bookings_transfer_id ON bookings(transfer_id);
CREATE INDEX IF NOT EXISTS idx_bookings_charge_id ON bookings(charge_id);
CREATE INDEX IF NOT EXISTS idx_profiles_stripe_account_id ON profiles(stripe_account_id);

-- Refresh Supabase schema cache
-- Note: This might require a Supabase dashboard refresh or API call
-- The schema cache should update automatically, but if issues persist,
-- try refreshing the Supabase dashboard or restarting the connection

