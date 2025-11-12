# Fix RLS Policies for Pilot Licenses and Drone Registrations

This document explains how to fix the Row Level Security (RLS) policy errors when uploading pilot licenses and drone registrations.

## Problem

When uploading pilot licenses or drone registrations, you may encounter the error:
```
new row violates row-level security policy
```

This happens because:
1. The `drone_registrations` table may not exist in your database
2. RLS policies may be missing or incorrectly configured
3. Storage bucket policies may not be set up correctly

## Solution

Run the SQL migration file `fix_rls_policies.sql` in your Supabase SQL Editor. This will:

1. **Create the `drone_registrations` table** (if it doesn't exist)
2. **Set up RLS policies** for both `pilot_licenses` and `drone_registrations` tables
3. **Create the storage bucket** for drone registrations
4. **Set up storage policies** for both buckets using the `owner` field

## How to Apply the Fix

1. **Open your Supabase Dashboard**
   - Go to your project dashboard
   - Navigate to the SQL Editor

2. **Run the Migration**
   - Copy the contents of `fix_rls_policies.sql`
   - Paste it into the SQL Editor
   - Click "Run" to execute the migration

3. **Verify the Changes**
   - Check that the `drone_registrations` table exists
   - Verify that RLS is enabled on both tables
   - Confirm that storage buckets and policies are created

## What the Migration Does

### Database Tables

- **Creates `drone_registrations` table** with columns:
  - `id` (UUID, primary key)
  - `pilot_id` (UUID, references profiles)
  - `file_url` (TEXT)
  - `file_type` (TEXT: 'pdf' or 'image')
  - `uploaded_at` (TIMESTAMP)

- **Enables RLS** on both `pilot_licenses` and `drone_registrations` tables

- **Creates RLS policies** that allow:
  - Users to view only their own records
  - Users to insert only records with their own `pilot_id`
  - Users to update only their own records
  - Users to delete only their own records

### Storage Buckets

- **Creates `drone-registrations` bucket** (if it doesn't exist)
- **Ensures `pilot-licenses` bucket exists**

### Storage Policies

- **Uses the `owner` field** to verify file ownership
- Allows authenticated users to:
  - Upload files to their own folders
  - View only their own files
  - Update only their own files
  - Delete only their own files

## Key Points

1. **Authentication Required**: All policies require the user to be authenticated (`TO authenticated`)

2. **Ownership Verification**: 
   - Database tables: Checks that `auth.uid() = pilot_id`
   - Storage: Checks that `owner = auth.uid()`

3. **Automatic Owner Assignment**: When files are uploaded through the Supabase client SDK with an authenticated user, the `owner` field is automatically set to the user's ID

## Testing

After applying the migration, test the following:

1. **Upload a pilot license** - Should succeed without RLS errors
2. **Upload a drone registration** - Should succeed without RLS errors
3. **View your own files** - Should work correctly
4. **Try to access another user's files** - Should be blocked by RLS

## Troubleshooting

If you still encounter issues:

1. **Check Authentication**: Ensure the user is properly authenticated before uploading
2. **Verify User ID**: Make sure `pilot_id` matches `auth.uid()` in the database
3. **Check Storage Buckets**: Verify that buckets exist and are configured correctly
4. **Review Policies**: Check that RLS policies are active in the Supabase dashboard

## Notes

- The migration is idempotent (safe to run multiple times)
- Existing policies are dropped and recreated to ensure correctness
- The migration uses `DROP POLICY IF EXISTS` to avoid errors if policies don't exist
- Storage policies use the `owner` field, which is more reliable than parsing file paths

