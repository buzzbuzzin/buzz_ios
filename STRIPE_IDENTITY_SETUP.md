# Stripe Identity Integration Setup Guide

This guide explains how to set up Stripe Identity for government ID verification in the Buzz app.

## Overview

The app now uses Stripe Identity to securely verify government-issued IDs with both document verification and selfie checks. This replaces the previous manual upload flow with Stripe's automated verification system.

**Selfie Verification**: The verification flow includes a selfie check that compares the user's face with the photo on their government-issued ID. This provides an additional layer of security against identity fraud using stolen documents.

## Prerequisites

1. **Stripe Account**: You need an active Stripe account
2. **Stripe Identity Enabled**: Complete the [Stripe Identity application](https://dashboard.stripe.com/identity/application)
3. **Supabase Project**: Your Supabase project must be set up with Edge Functions support

## Setup Steps

### 1. Configure Stripe Keys

Update `Buzz/Config.swift` with your Stripe keys:

```swift
static let stripePublishableKey = "pk_test_YOUR_PUBLISHABLE_KEY"
static let stripeSecretKey = "sk_test_YOUR_SECRET_KEY" // Only used server-side
```

**Important**: Never expose your secret key in the client app. It's only used in the Supabase Edge Function.

### 2. Deploy Supabase Edge Function

The Edge Function creates Stripe VerificationSessions server-side. This is required for security.

#### Install Supabase CLI

```bash
npm install -g supabase
```

#### Login and Link Project

```bash
supabase login
supabase link --project-ref your-project-ref
```

#### Set Stripe Secret Key

```bash
supabase secrets set STRIPE_SECRET_KEY=sk_test_YOUR_SECRET_KEY
```

#### Deploy Function

```bash
supabase functions deploy create-verification-session
```

The function is located at: `supabase/functions/create-verification-session/index.ts`

### 3. Update Database Schema

Add the `stripe_session_id` column to your `government_ids` table:

```sql
ALTER TABLE government_ids 
ADD COLUMN stripe_session_id TEXT;

-- Make file_url and file_type nullable since Stripe handles storage
ALTER TABLE government_ids 
ALTER COLUMN file_url DROP NOT NULL,
ALTER COLUMN file_type DROP NOT NULL;
```

### 4. Test the Integration

1. **Test Mode**: Use Stripe test mode keys first
2. **Test Documents**: Stripe provides test document images in their dashboard
3. **Verify Flow**: 
   - Open the Government ID view in the app
   - Tap "Verify Identity with Stripe"
   - Complete the verification flow
   - Check that the status updates to "Verified"

## How It Works

1. **User Initiates Verification**: User taps "Verify Identity with Stripe" button
2. **Create Session**: App calls Supabase Edge Function to create a Stripe VerificationSession with selfie check enabled
3. **Present Flow**: Stripe Identity SDK presents the document capture UI
4. **User Submits Document**: User captures/uploads their ID document
5. **User Takes Selfie**: User takes a selfie photo (automatically prompted by Stripe SDK)
6. **Stripe Verifies**: Stripe processes and verifies both the document and selfie match
7. **Update Status**: App updates the database with verification status

**Note**: Both the document check and selfie check must pass for verification to be successful. If either check fails, the verification status will be set to "rejected".

## Architecture

```
┌─────────────┐
│   iOS App   │
│             │
│ 1. Request  │──┐
│  verification│  │
└─────────────┘  │
                 │
                 ▼
┌─────────────────────────┐
│  Supabase Edge Function  │
│                         │
│ 2. Create Stripe        │
│    VerificationSession  │──┐
└─────────────────────────┘  │
                             │
                             ▼
                    ┌─────────────────┐
                    │  Stripe API     │
                    │                 │
                    │ 3. Return       │
                    │    client_secret│
                    └─────────────────┘
                             │
                             │
┌─────────────┐              │
│   iOS App   │◄─────────────┘
│             │
│ 4. Present  │
│  Stripe UI  │
└─────────────┘
```

## Security Considerations

- ✅ Stripe secret key is stored server-side only (Supabase secrets)
- ✅ Client secret is single-use and expires in 24 hours
- ✅ Verification data is encrypted by Stripe
- ✅ No sensitive data stored in app or database
- ✅ Stripe handles all document storage and processing
- ✅ Selfie verification prevents use of stolen identity documents
- ✅ Biometric matching uses advanced machine learning algorithms

**Privacy Note**: Selfie checks use biometric technology. In some jurisdictions (e.g., EU), you may need to:
- Justify the use of biometric technology
- Offer an alternative non-biometric verification option
- Consult with legal counsel regarding compliance requirements

## Troubleshooting

### Function Not Found Error

**Problem**: "Backend verification endpoint not configured"

**Solution**: 
- Ensure the Edge Function is deployed: `supabase functions deploy create-verification-session`
- Check function name matches exactly: `create-verification-session`
- Verify Supabase project is linked correctly

### Stripe API Errors

**Problem**: Stripe API returns errors

**Solution**:
- Verify Stripe Identity is enabled in your Stripe dashboard
- Check that the secret key is correct and has Identity permissions
- Ensure you're using test keys in test mode

### Verification Not Completing

**Problem**: Verification flow doesn't complete

**Solution**:
- Check network connectivity
- Verify camera permissions are granted
- Check Stripe dashboard for verification session status
- Review error messages in app logs

### Selfie Check Failures

**Problem**: Verification fails with selfie check errors

**Common Error Codes**:
- `selfie_face_mismatch`: The selfie doesn't match the photo on the ID document
- `selfie_document_missing_photo`: The ID document doesn't contain a photo
- `selfie_manipulated`: The selfie image was manipulated or edited
- `selfie_unverified_other`: General selfie verification failure

**Solution**:
- Ensure the ID document has a clear photo of the user's face
- Make sure the selfie is taken in good lighting
- Ensure the user's face is clearly visible in the selfie
- Verify the user is using their own ID document
- Check that the ID document type is supported for selfie checks (see Stripe documentation for supported countries)

## Production Checklist

Before going live:

- [ ] Switch to Stripe live keys (update Config.swift and Edge Function secret)
- [ ] Test with real documents (not test documents)
- [ ] Set up webhook endpoint to handle verification events (optional)
- [ ] Review Stripe Identity compliance requirements
- [ ] Update privacy policy to mention Stripe Identity
- [ ] Test error handling and edge cases

## Webhook Setup (Optional)

To get real-time updates when verification completes, set up a Stripe webhook:

1. Create webhook endpoint in Supabase Edge Functions
2. Listen for `identity.verification_session.verified` event
3. Update database when verification completes

See Stripe documentation for webhook setup: https://docs.stripe.com/webhooks

## Support

- **Stripe Identity Docs**: https://docs.stripe.com/identity
- **Supabase Edge Functions**: https://supabase.com/docs/guides/functions
- **Stripe Support**: https://support.stripe.com

