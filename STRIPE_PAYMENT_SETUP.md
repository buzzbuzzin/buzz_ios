# Stripe Connect Payment Integration Setup Guide

This guide explains how to set up Stripe Connect with separate charges and transfers for the Buzz app.

## Overview

The payment flow works as follows:
1. **Customer creates booking**: Customer pays via Stripe PaymentSheet when creating a booking
2. **Pilot accepts booking**: Booking status changes to "accepted"
3. **Booking completed**: When pilot marks booking as completed, funds are automatically transferred to the pilot's Stripe connected account

## Architecture

- **Separate Charges and Transfers**: Charges are created on the platform account, transfers happen later to connected accounts
- **PaymentSheet**: Pre-built Stripe UI for customer payments
- **Transfer Group**: Links charges and transfers together for accounting

## Setup Steps

### 1. Database Migration

Run the SQL migration script to add payment fields:

```sql
-- Run stripe_payment_migration.sql in Supabase SQL Editor
```

This adds:
- `payment_intent_id` to `bookings` table
- `transfer_id` to `bookings` table
- `charge_id` to `bookings` table
- `stripe_account_id` to `profiles` table (for pilots)

### 2. Deploy Supabase Edge Functions

Deploy the three Edge Functions:

```bash
# Deploy create-payment-intent
supabase functions deploy create-payment-intent

# Deploy create-transfer
supabase functions deploy create-transfer

# Deploy get-payment-intent
supabase functions deploy get-payment-intent
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

### 4. Configure Stripe Connect

1. **Enable Stripe Connect** in your Stripe Dashboard
2. **Create Connected Accounts** for pilots:
   - Use Stripe Connect API to onboard pilots
   - Store the `acct_xxx` account ID in `profiles.stripe_account_id`
   - Pilots can be onboarded via Express Dashboard or Custom flow

### 5. iOS App Configuration

The iOS app is already configured:
- Stripe PaymentSheet SDK is added
- Stripe publishable key is set in `Config.swift`
- PaymentService handles payment flow
- BookingService integrates payment into booking creation

## Payment Flow Details

### Creating a Booking (Customer)

1. Customer fills out booking form
2. When "Create Booking" is tapped:
   - PaymentIntent is created with `transfer_group`
   - PaymentSheet is presented to customer
   - Customer completes payment
   - Booking is created with `payment_intent_id` and `charge_id`

### Completing a Booking (Pilot)

1. Pilot marks booking as completed
2. System checks if booking has `charge_id` and `pilot_id`
3. Transfer is created to pilot's connected account:
   - Amount: `payment_amount + tip_amount`
   - Linked to charge via `source_transaction`
   - Booking is updated with `transfer_id`

## Edge Functions

### `create-payment-intent`

Creates a Stripe PaymentIntent with:
- Amount and currency
- Customer (optional, for saving cards)
- Transfer group (for later transfers)
- Automatic payment methods enabled

**Request:**
```json
{
  "amount": 10000,
  "currency": "usd",
  "customer_id": "uuid",
  "transfer_group": "booking_uuid"
}
```

**Response:**
```json
{
  "client_secret": "pi_xxx_secret_xxx",
  "payment_intent_id": "pi_xxx",
  "customer_id": "cus_xxx",
  "ephemeral_key_secret": "ek_xxx"
}
```

### `create-transfer`

Creates a transfer to pilot's connected account:
- Gets booking details from database
- Gets pilot's Stripe account ID
- Creates transfer linked to charge
- Updates booking with transfer ID

**Request:**
```json
{
  "booking_id": "uuid",
  "amount": 10000,
  "currency": "usd",
  "charge_id": "ch_xxx"
}
```

**Response:**
```json
{
  "transfer_id": "tr_xxx",
  "amount": 10000,
  "currency": "usd"
}
```

### `get-payment-intent`

Retrieves PaymentIntent details including charge ID.

**Request:**
```json
{
  "payment_intent_id": "pi_xxx"
}
```

**Response:**
```json
{
  "payment_intent_id": "pi_xxx",
  "charge_id": "ch_xxx",
  "status": "succeeded",
  "amount": 10000,
  "currency": "usd"
}
```

## Platform Fees

The platform can collect fees by:
- Reducing the transfer amount to pilots
- Example: Customer pays $100, platform keeps $10, pilot receives $90

To implement platform fees, modify `create-transfer` to calculate:
```typescript
const platformFee = Math.round(amount * 0.10) // 10% platform fee
const transferAmount = amount - platformFee
```

## Testing

### Test Cards

Use Stripe test cards:
- Success: `4242 4242 4242 4242`
- Decline: `4000 0000 0000 0002`

### Test Connected Accounts

Create test connected accounts in Stripe Dashboard:
1. Go to Connect > Accounts
2. Create test account
3. Copy account ID (`acct_xxx`)
4. Update pilot profile in database

## Error Handling

Common errors and solutions:

1. **"Pilot does not have a Stripe connected account"**
   - Ensure pilot has `stripe_account_id` set in profile
   - Onboard pilot via Stripe Connect

2. **"Transfer failed"**
   - Check pilot's connected account status
   - Ensure charge has settled (may take time for some payment methods)

3. **"Payment failed"**
   - Check PaymentIntent status in Stripe Dashboard
   - Verify customer payment method

## Security Notes

- Stripe secret key is stored server-side only (Supabase secrets)
- PaymentSheet handles PCI compliance
- Never expose secret keys in client code
- Use test keys during development

## Production Checklist

- [ ] Switch to live Stripe keys
- [ ] Set up Stripe webhooks for payment events
- [ ] Implement platform fee calculation
- [ ] Set up refund handling
- [ ] Configure payout schedules for pilots
- [ ] Add error monitoring and logging
- [ ] Test with real payment methods
- [ ] Review Stripe Connect compliance requirements

## Resources

- [Stripe Connect Documentation](https://docs.stripe.com/connect)
- [Separate Charges and Transfers](https://docs.stripe.com/connect/separate-charges-and-transfers)
- [PaymentSheet iOS Documentation](https://stripe.dev/stripe-ios/stripepaymentsheet/documentation/stripepaymentsheet)
- [Stripe Dashboard](https://dashboard.stripe.com)

