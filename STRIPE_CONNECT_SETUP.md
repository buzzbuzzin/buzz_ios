# Stripe Connect Express Account Setup Guide

This guide explains how to set up Stripe Connect Express accounts for pilots to receive payments in the Buzz app.

## Overview

The payment flow works as follows:
1. **Pilot sets up account**: Pilot creates a Stripe Express connected account through the app
2. **Onboarding**: Pilot completes Stripe's onboarding flow (includes bank account linking if Financial Connections is enabled)
3. **Customer creates booking**: Customer pays via Stripe PaymentSheet when creating a booking
4. **Booking completed**: When pilot marks booking as completed, funds are automatically transferred to the pilot's Stripe connected account

## Architecture

- **Express Connected Accounts**: Pilots have their own Stripe Express accounts
- **Separate Charges and Transfers**: Charges are created on the platform account, transfers happen later to connected accounts
- **Financial Connections**: Bank accounts can be linked during onboarding (if enabled in Stripe Dashboard)
- **Account Links**: Stripe-hosted onboarding flow for Express accounts

## Prerequisites

1. **Stripe Account**: You need an active Stripe account with Connect enabled
2. **Stripe Connect Settings**: Configure Express accounts in Stripe Dashboard
3. **Financial Connections** (Optional): Enable in Connect Settings to allow bank account linking during onboarding
4. **Supabase Project**: Your Supabase project must be set up with Edge Functions support

## Setup Steps

### 1. Configure Stripe Connect

1. Go to [Stripe Dashboard → Connect → Settings](https://dashboard.stripe.com/settings/connect)
2. Enable Express accounts
3. (Optional) Enable Financial Connections for bank account linking:
   - Go to Connect Settings → External Accounts
   - Enable "Collect external account details"
   - Enable Financial Connections if you want instant verification

### 2. Deploy Supabase Edge Functions

Deploy the following Edge Functions:

```bash
# Deploy create-connected-account
supabase functions deploy create-connected-account

# Deploy create-account-link
supabase functions deploy create-account-link

# Deploy check-account-status
supabase functions deploy check-account-status

# Deploy create-financial-connections-session (optional, for later use)
supabase functions deploy create-financial-connections-session

# Deploy attach-external-account (optional, for later use)
supabase functions deploy attach-external-account
```

### 3. Set Stripe Secret Key

Set your Stripe secret key as a Supabase secret:

```bash
supabase secrets set STRIPE_SECRET_KEY=sk_test_YOUR_SECRET_KEY
```

For production:
```bash
supabase secrets set STRIPE_SECRET_KEY=sk_live_YOUR_LIVE_SECRET_KEY --env prod
```

### 4. Database Schema

The database already includes the `stripe_account_id` column in the `profiles` table. No migration needed.

### 5. iOS App Configuration

The iOS app is already configured:
- StripeConnectService handles account creation and onboarding
- StripeAccountSetupView provides the UI for pilots
- Navigation link added in ProfileView for pilots

## Usage Flow

### For Pilots

1. **Access Payment Account Setup**:
   - Go to Profile tab
   - Tap "Payment Account" in Account section

2. **Create Account**:
   - Tap "Set Up Payment Account"
   - Stripe Express account is created automatically
   - Onboarding flow opens in Safari View Controller

3. **Complete Onboarding**:
   - Fill in personal/business information
   - Link bank account (if Financial Connections enabled)
   - Complete identity verification if required
   - Return to app when done

4. **Check Status**:
   - View account status in Payment Account view
   - Status updates automatically after onboarding

### Account Statuses

- **Not Created**: Account hasn't been set up yet
- **Onboarding**: Account created but onboarding not completed
- **Pending**: Onboarding complete, awaiting verification
- **Active**: Account fully set up and can receive payments
- **Restricted**: Account has restrictions (check Stripe Dashboard)

## Edge Functions

### `create-connected-account`

Creates an Express connected account for a pilot.

**Request:**
```json
{
  "user_id": "uuid",
  "email": "pilot@example.com",
  "country": "US"
}
```

**Response:**
```json
{
  "account_id": "acct_xxx",
  "already_exists": false
}
```

### `create-account-link`

Creates an account link for onboarding.

**Request:**
```json
{
  "account_id": "acct_xxx",
  "refresh_url": "https://stripe.com/connect/onboarding/refresh",
  "return_url": "https://stripe.com/connect/onboarding/return"
}
```

**Response:**
```json
{
  "url": "https://connect.stripe.com/setup/..."
}
```

### `check-account-status`

Checks the status of a connected account.

**Request:**
```json
{
  "account_id": "acct_xxx"
}
```

**Response:**
```json
{
  "account_id": "acct_xxx",
  "status": "active",
  "details_submitted": true,
  "charges_enabled": true,
  "payouts_enabled": true
}
```

## Financial Connections

If you've enabled Financial Connections in Stripe Connect settings, bank accounts will be collected automatically during the Express onboarding flow. No additional code is needed.

The `create-financial-connections-session` and `attach-external-account` functions are available for future use if you need to add bank accounts separately.

## Testing

1. **Test Mode**: Use Stripe test mode keys
2. **Test Accounts**: Use Stripe test account numbers for bank account linking
3. **Test Cards**: Use Stripe test cards for payment testing

## Troubleshooting

### Account Status Stuck on "Onboarding"

- Check Stripe Dashboard for account requirements
- Ensure all required information is provided
- Check for any verification holds

### Bank Account Not Linking

- Verify Financial Connections is enabled in Connect Settings
- Check that the account country supports Financial Connections
- Review Stripe Dashboard for error messages

### Transfer Failures

- Ensure pilot account is active (`charges_enabled` and `payouts_enabled` are true)
- Check that bank account is verified
- Review transfer logs in Stripe Dashboard

## Security Notes

- Never expose Stripe secret keys in client code
- All Stripe API calls are made server-side via Edge Functions
- Account links are single-use and expire after a few minutes
- Always verify account status before processing transfers

## References

- [Stripe Connect Express Accounts](https://docs.stripe.com/connect/express-accounts)
- [Financial Connections](https://docs.stripe.com/connect/payouts-bank-accounts)
- [Account Links](https://docs.stripe.com/api/account_links)

