# Supabase Edge Functions

This directory contains Supabase Edge Functions for server-side operations related to Stripe Identity verification.

## Required Edge Functions

There are **3 edge functions** that need to be deployed:

1. **`create-verification-session`** - Creates Stripe Identity verification sessions with selfie check
2. **`check-verification-status`** - Checks the status of a verification session
3. **`get-selfie-from-verification`** - Retrieves the verified selfie image from Stripe (NEW - for profile pictures)

## Setup Instructions

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

5. **Deploy all functions**:
   ```bash
   # Deploy verification session creation
   supabase functions deploy create-verification-session
   
   # Deploy verification status check
   supabase functions deploy check-verification-status
   
   # Deploy selfie retrieval (NEW - required for profile picture verification)
   supabase functions deploy get-selfie-from-verification
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

## Function Endpoints

Once deployed, the functions will be available at:

- **Create Verification Session**: 
  ```
  https://YOUR_PROJECT_REF.supabase.co/functions/v1/create-verification-session
  ```
  Used when users initiate identity verification (government ID or profile picture)

- **Check Verification Status**:
  ```
  https://YOUR_PROJECT_REF.supabase.co/functions/v1/check-verification-status
  ```
  Used to check if a verification session completed successfully

- **Get Selfie from Verification** (NEW):
  ```
  https://YOUR_PROJECT_REF.supabase.co/functions/v1/get-selfie-from-verification
  ```
  Used to retrieve the verified selfie image from Stripe after successful verification (for profile pictures)

The iOS app will automatically call these endpoints when users initiate identity verification or update their profile picture.

## Function Details

### 1. create-verification-session

Creates a Stripe Identity verification session with selfie check enabled.

**Request Body:**
```json
{
  "user_id": "uuid-string",
  "email": "user@example.com",
  "for_profile_picture": false  // optional, for profile picture verification
}
```

**Response:**
```json
{
  "client_secret": "vs_xxx_secret_yyy",
  "id": "vs_xxx"
}
```

### 2. check-verification-status

Checks the status of a verification session.

**Request Body:**
```json
{
  "session_id": "vs_xxx"
}
```

**Response:**
```json
{
  "status": "verified" | "pending" | "rejected",
  "stripe_status": "verified" | "requires_input" | "processing",
  "verified_at": 1234567890,
  "last_error": null | { "type": "...", "code": "...", "reason": "..." }
}
```

### 3. get-selfie-from-verification (NEW)

Retrieves the verified selfie image URL from a completed verification session. This is used for profile picture updates.

**Request Body:**
```json
{
  "session_id": "vs_xxx"
}
```

**Response:**
```json
{
  "verified": true,
  "selfie_image_url": "https://files.stripe.com/..."
}
```

**Error Response:**
```json
{
  "verified": false,
  "error": "Error message"
}
```

## Security Notes

- The Stripe secret key is stored as a Supabase secret and never exposed to the client
- Only the client secret (single-use, expires in 24 hours) is returned to the frontend
- The functions validate requests and include user metadata for tracking
- File links from Stripe expire after 1 hour for security

## Troubleshooting

- **Function not found**: Make sure all functions are deployed and the names match exactly
- **Stripe API errors**: Check that your Stripe account has Identity enabled and the secret key is correct
- **CORS errors**: The functions include CORS headers, but ensure your Supabase project allows function invocations
- **Selfie retrieval fails**: Ensure the verification session status is "verified" and both document and selfie checks passed

