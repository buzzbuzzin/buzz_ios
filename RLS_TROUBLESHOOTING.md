# RLS Troubleshooting Guide

## Problem
Even after disabling RLS in Supabase UI, you're still getting "new row violates row-level security policy" errors.

## Root Causes

The issue can be caused by several things:

1. **Policies still exist** - Disabling RLS in the UI doesn't always remove policies
2. **Storage RLS blocking uploads** - The error might be from storage, not the database table
3. **Foreign key constraint** - The `pilot_id` must reference an existing profile
4. **Authentication mismatch** - `auth.uid()` doesn't match the `pilot_id` being inserted

## Solution Steps

### Step 1: Run the Complete Fix SQL

Run `fix_rls_complete.sql` in your Supabase SQL Editor. This script will:

- Drop ALL existing policies (even hidden ones)
- Create very permissive policies for testing
- Set up storage buckets and policies correctly
- Verify everything is set up

### Step 2: Test the Upload

After running the SQL:

1. Try uploading a pilot license or drone registration
2. Check the Xcode console for DEBUG messages
3. The debug messages will tell you:
   - If authentication is working
   - If the profile exists
   - If storage upload succeeds
   - If database insert succeeds
   - Exactly where the error occurs

### Step 3: Check the Debug Output

Look for these DEBUG messages in Xcode console:

```
DEBUG LicenseUpload: Current user ID: [UUID]
DEBUG LicenseUpload: Pilot ID: [UUID]
DEBUG LicenseUpload: IDs match: true/false
DEBUG LicenseUpload: Profile found for user
DEBUG LicenseUpload: Storage upload successful
DEBUG LicenseUpload: Database insert successful
```

### Step 4: Common Issues and Fixes

#### Issue: "User profile not found"
**Fix:** Ensure the user has a profile in the `profiles` table. The profile must exist before uploading files.

#### Issue: "Storage upload failed"
**Fix:** Check storage bucket policies. Run the storage policy section of `fix_rls_complete.sql`.

#### Issue: "IDs don't match"
**Fix:** The `pilot_id` being passed must match `auth.uid()`. Check that `currentUser.id` matches the authenticated user.

#### Issue: "Foreign key constraint violation"
**Fix:** Ensure the profile exists in the `profiles` table with the same ID as `pilot_id`.

### Step 5: Tighten Security (After Testing)

Once uploads work, you can tighten the policies. Replace the permissive policies with:

```sql
-- More secure policies (only allow users to access their own data)
DROP POLICY "Allow authenticated users full access to pilot_licenses" ON pilot_licenses;
DROP POLICY "Allow authenticated users full access to drone_registrations" ON drone_registrations;

CREATE POLICY "Pilots can manage their own licenses"
    ON pilot_licenses
    FOR ALL
    TO authenticated
    USING (auth.uid() = pilot_id)
    WITH CHECK (auth.uid() = pilot_id);

CREATE POLICY "Pilots can manage their own registrations"
    ON drone_registrations
    FOR ALL
    TO authenticated
    USING (auth.uid() = pilot_id)
    WITH CHECK (auth.uid() = pilot_id);
```

## Diagnostic Queries

Run `diagnose_rls_issue.sql` to check:

1. If RLS is enabled on tables
2. What policies exist
3. If storage buckets exist
4. If storage policies exist
5. If user profiles exist

## Still Having Issues?

1. **Check Xcode Console** - The debug messages will pinpoint the exact issue
2. **Check Supabase Logs** - Go to Supabase Dashboard → Logs to see server-side errors
3. **Verify Authentication** - Ensure the user is properly authenticated before uploading
4. **Check Profile Exists** - Run: `SELECT * FROM profiles WHERE id = 'YOUR_USER_ID';`
5. **Verify Storage Buckets** - Run: `SELECT * FROM storage.buckets WHERE id IN ('pilot-licenses', 'drone-registrations');`

## Files Created

- `fix_rls_complete.sql` - Complete fix (run this first)
- `diagnose_rls_issue.sql` - Diagnostic queries
- `fix_rls_policies.sql` - Original fix (may not work if policies are hidden)
- Updated `LicenseUploadService.swift` - Added debugging
- Updated `DroneRegistrationService.swift` - Added debugging

## Next Steps

1. Run `fix_rls_complete.sql`
2. Try uploading a file
3. Check Xcode console for debug messages
4. Share the debug output if issues persist

