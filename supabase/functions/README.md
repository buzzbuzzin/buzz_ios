# Supabase Edge Functions

This directory contains Supabase Edge Functions for server-side operations.

## Stripe Identity Verification Function

### Setup Instructions

1. **Install Supabase CLI** (if not already installed):
   ```bash
   npm install -g supabase
   ```

2. **Login to Supabase**:
   ```bash
   supabase login
   ```

3. **Link your project**:
   ```bash
   supabase link --project-ref your-project-ref
   ```

4. **Set Stripe Secret Key as environment variable**:
   ```bash
   supabase secrets set STRIPE_SECRET_KEY=sk_test_YOUR_SECRET_KEY
   ```
   
   For production:
   ```bash
   supabase secrets set STRIPE_SECRET_KEY=sk_live_YOUR_LIVE_SECRET_KEY --env prod
   ```

5. **Deploy the function**:
   ```bash
   supabase functions deploy create-verification-session
   ```

### Testing Locally

1. **Start Supabase locally** (optional, for local development):
   ```bash
   supabase start
   ```

2. **Serve the function locally**:
   ```bash
   supabase functions serve create-verification-session
   ```

3. **Test with curl**:
   ```bash
   curl -X POST http://localhost:54321/functions/v1/create-verification-session \
     -H "Authorization: Bearer YOUR_ANON_KEY" \
     -H "Content-Type: application/json" \
     -d '{"user_id": "test-user-id", "email": "test@example.com"}'
   ```

### Function Endpoint

Once deployed, the function will be available at:
```
https://YOUR_PROJECT_REF.supabase.co/functions/v1/create-verification-session
```

The iOS app will automatically call this endpoint when users initiate identity verification.

### Security Notes

- The Stripe secret key is stored as a Supabase secret and never exposed to the client
- Only the client secret (single-use, expires in 24 hours) is returned to the frontend
- The function validates the request and includes user metadata for tracking

### Troubleshooting

- **Function not found**: Make sure the function is deployed and the name matches exactly
- **Stripe API errors**: Check that your Stripe account has Identity enabled and the secret key is correct
- **CORS errors**: The function includes CORS headers, but ensure your Supabase project allows function invocations

