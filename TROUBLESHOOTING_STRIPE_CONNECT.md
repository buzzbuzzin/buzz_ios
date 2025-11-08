# Troubleshooting Stripe Connect Edge Function 500 Error

If you're getting a 500 error when setting up a payment account, follow these steps:

## Step 1: Deploy the Edge Function

Make sure the Edge Function is deployed:

```bash
cd /Users/xinyufang/Documents/Buzz
supabase functions deploy create-connected-account
```

## Step 2: Verify Environment Variables

Check that all required secrets are set:

```bash
supabase secrets list
```

You should see:
- `STRIPE_SECRET_KEY` - Your Stripe secret key (starts with `sk_test_` or `sk_live_`)

**Note**: `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are automatically provided by Supabase - you don't need to set them manually.

## Step 3: Check Edge Function Logs

View the logs to see the actual error:

```bash
supabase functions logs create-connected-account
```

Or check in the Supabase Dashboard:
1. Go to your Supabase project
2. Navigate to **Edge Functions** → **create-connected-account**
3. Click on **Logs** tab

## Common Issues and Solutions

### Issue 1: Function Not Deployed
**Error**: 404 or Function not found

**Solution**:
```bash
supabase functions deploy create-connected-account
```

### Issue 2: Missing Stripe Secret Key
**Error**: "STRIPE_SECRET_KEY environment variable is not set"

**Solution**:
```bash
supabase secrets set STRIPE_SECRET_KEY=sk_test_YOUR_SECRET_KEY
```

### Issue 3: Database Query Fails
**Error**: "Failed to fetch user profile"

**Possible causes**:
- User profile doesn't exist in database
- RLS (Row Level Security) policies blocking access
- Database connection issue

**Solution**:
- Verify the user has a profile in the `profiles` table
- Check RLS policies allow service role to read profiles
- Verify database is accessible

### Issue 4: Stripe API Error
**Error**: Stripe API errors (invalid_request_error, api_error, etc.)

**Possible causes**:
- Invalid Stripe secret key
- Stripe Connect not enabled
- Account creation limits reached
- Invalid email format

**Solution**:
- Verify Stripe secret key is correct
- Enable Stripe Connect in Stripe Dashboard
- Check Stripe Dashboard for account limits
- Ensure email is valid format

### Issue 5: Email Missing
**Error**: "Email is required to create Stripe account"

**Solution**:
- Ensure user profile has an email address
- Or pass email in the request

## Testing the Function Manually

Test the function directly with curl:

```bash
curl -X POST https://YOUR_PROJECT_REF.supabase.co/functions/v1/create-connected-account \
  -H "Authorization: Bearer YOUR_SUPABASE_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "YOUR_USER_UUID",
    "email": "test@example.com",
    "country": "US"
  }'
```

Replace:
- `YOUR_PROJECT_REF` with your Supabase project reference
- `YOUR_SUPABASE_ANON_KEY` with your anon key from Config.swift
- `YOUR_USER_UUID` with an actual user ID from your database

## Checking Error Details in iOS App

The improved error handling will now show more detailed error messages. Check:
1. The error alert in the app
2. Xcode console logs for detailed error information

## Next Steps

After fixing the issue:
1. Redeploy the Edge Function if you made changes
2. Test again from the app
3. Check logs if errors persist

