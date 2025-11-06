# Fix: Verification Status Not Checking Actual Stripe Result

## Problem

Previously, when a user completed the Stripe Identity verification flow, the app would immediately mark the ID as "verified" without checking if Stripe actually verified the document. This meant that failed verifications would still show as verified in the app.

## Solution

The app now checks the actual verification status from Stripe after the flow completes, ensuring that only truly verified IDs are marked as verified.

## Changes Made

### 1. New Edge Function: `check-verification-status`

Created a new Supabase Edge Function that queries Stripe's API to get the actual verification status of a session.

**Location**: `supabase/functions/check-verification-status/index.ts`

**What it does**:
- Takes a Stripe verification session ID
- Queries Stripe API for the session status
- Returns the actual verification status (verified, rejected, or pending)

### 2. Updated iOS Code

Updated `IdentityVerificationService.swift` to:
- After flow completion, call the new Edge Function to check actual status
- Only mark as "verified" if Stripe confirms verification
- Mark as "rejected" if Stripe indicates verification failed
- Mark as "pending" if verification is still processing

## Deployment Steps

### 1. Deploy the New Edge Function

```bash
cd /Users/xinyufang/Documents/Buzz
supabase functions deploy check-verification-status
```

The function uses the same `STRIPE_SECRET_KEY` secret that you already set for `create-verification-session`, so no additional secrets are needed.

### 2. Test the Fix

1. **Test Successful Verification**:
   - Complete a verification flow with valid test documents
   - App should show "Verified" status

2. **Test Failed Verification**:
   - Complete a verification flow with invalid/failed test documents
   - App should show "Rejected" status (not "Verified")

3. **Test Pending Verification**:
   - If verification is still processing, app should show "Pending"

## How It Works Now

```
1. User completes Stripe Identity flow
   ↓
2. Flow returns "completed" status
   ↓
3. App calls check-verification-status Edge Function
   ↓
4. Edge Function queries Stripe API for actual status
   ↓
5. App updates database with actual status:
   - "verified" if Stripe verified the document
   - "rejected" if Stripe rejected the document
   - "pending" if still processing
```

## Stripe Status Mapping

| Stripe Status | App Status | Description |
|--------------|------------|-------------|
| `verified` | `verified` | Document successfully verified |
| `requires_input` | `rejected` | Verification failed or needs more info |
| `unverified` | `pending` | Still processing |

## Verification

After deploying, test with Stripe's test mode:
- Use test documents that will fail verification
- Verify that the app shows "Rejected" status, not "Verified"
- Use valid test documents and verify "Verified" status appears

## Troubleshooting

### Function Not Found Error

If you get a 404 error when checking status:
- Make sure you deployed `check-verification-status`: 
  ```bash
  supabase functions deploy check-verification-status
  ```

### Status Always Shows Pending

- Check Edge Function logs in Supabase Dashboard
- Verify Stripe secret key is set correctly
- Ensure session ID is being passed correctly

### Status Shows Verified When It Shouldn't

- Check Stripe Dashboard to see actual verification status
- Verify the Edge Function is returning correct status
- Check Edge Function logs for errors

