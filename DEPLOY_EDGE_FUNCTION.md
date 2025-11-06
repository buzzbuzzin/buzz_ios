# Deploy Supabase Edge Function for Stripe Identity

The 404 error you're seeing means the Edge Function hasn't been deployed yet. Follow these steps to deploy it.

## Prerequisites

1. **Node.js installed** (for Supabase CLI)
2. **Supabase account** with your project set up
3. **Stripe account** with Identity enabled and API keys

## Step-by-Step Deployment

### 1. Install Supabase CLI

```bash
npm install -g supabase
```

### 2. Login to Supabase

```bash
supabase login
```

This will open your browser to authenticate.

### 3. Link Your Project

Get your project reference ID from your Supabase dashboard (it's in the project URL: `https://YOUR_PROJECT_REF.supabase.co`)

```bash
supabase link --project-ref YOUR_PROJECT_REF
```

Replace `YOUR_PROJECT_REF` with your actual project reference ID.

### 4. Set Stripe Secret Key

**Important**: Use your Stripe **secret key** (starts with `sk_test_` for test mode or `sk_live_` for production), NOT the publishable key.

```bash
supabase secrets set STRIPE_SECRET_KEY=sk_test_YOUR_SECRET_KEY
```

To verify it was set:
```bash
supabase secrets list
```

### 5. Deploy the Function

Navigate to your project directory and deploy:

```bash
cd /Users/xinyufang/Documents/Buzz
supabase functions deploy create-verification-session
```

### 6. Verify Deployment

After deployment, you should see output like:
```
Deployed Function create-verification-session (project: YOUR_PROJECT_REF)
```

You can also verify in your Supabase Dashboard:
1. Go to your Supabase project dashboard
2. Navigate to **Edge Functions** in the sidebar
3. You should see `create-verification-session` listed

## Testing the Function

### Test Locally (Optional)

Before deploying, you can test locally:

```bash
# Start local Supabase (if you have it set up)
supabase start

# Serve the function locally
supabase functions serve create-verification-session

# In another terminal, test with curl:
curl -X POST http://localhost:54321/functions/v1/create-verification-session \
  -H "Authorization: Bearer YOUR_SUPABASE_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"user_id": "test-user-id", "email": "test@example.com"}'
```

### Test After Deployment

Once deployed, test from your app or with curl:

```bash
curl -X POST https://YOUR_PROJECT_REF.supabase.co/functions/v1/create-verification-session \
  -H "Authorization: Bearer YOUR_SUPABASE_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"user_id": "test-user-id", "email": "test@example.com"}'
```

You should get a response like:
```json
{
  "client_secret": "vs_xxx_secret_yyy",
  "id": "vs_xxx"
}
```

## Troubleshooting

### Error: "Function not found"
- Make sure you deployed the function: `supabase functions deploy create-verification-session`
- Check that the function name matches exactly (case-sensitive)

### Error: "STRIPE_SECRET_KEY not set"
- Set the secret: `supabase secrets set STRIPE_SECRET_KEY=sk_test_...`
- Verify: `supabase secrets list`

### Error: "Stripe API error"
- Verify your Stripe secret key is correct
- Check that Stripe Identity is enabled in your Stripe dashboard
- Ensure you're using test keys in test mode

### Function deployed but still getting 404
- Wait a few seconds for the deployment to propagate
- Check the function logs in Supabase Dashboard → Edge Functions → Logs
- Verify the function URL matches what your app is calling

## Production Deployment

For production:

1. **Switch to live Stripe keys**:
   ```bash
   supabase secrets set STRIPE_SECRET_KEY=sk_live_YOUR_LIVE_SECRET_KEY --env prod
   ```

2. **Update your iOS app** `Config.swift`:
   ```swift
   static let stripePublishableKey = "pk_live_YOUR_LIVE_PUBLISHABLE_KEY"
   ```

3. **Redeploy the function**:
   ```bash
   supabase functions deploy create-verification-session --env prod
   ```

## Next Steps

After deploying the Edge Function:

1. ✅ Run the SQL migration (`stripe_identity_migration.sql`) in Supabase SQL Editor
2. ✅ Add your Stripe publishable key to `Config.swift`
3. ✅ Test the verification flow in your app

The 404 error should be resolved once the function is deployed!

