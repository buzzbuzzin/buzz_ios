# Step-by-Step Guide: Enable Stripe Connect Express Accounts and Financial Connections

## Prerequisites
- A Stripe account (test or live mode)
- Access to Stripe Dashboard

## Step 1: Enable Stripe Connect

1. **Go to Stripe Dashboard**
   - Visit: https://dashboard.stripe.com
   - Log in to your Stripe account

2. **Navigate to Connect Settings**
   - Click on **Settings** in the left sidebar
   - Click on **Connect** (or go directly to: https://dashboard.stripe.com/settings/connect)

3. **Enable Connect**
   - If you see "Get started" or "Enable Connect", click it
   - Complete the Connect onboarding:
     - Accept the Stripe Connect terms of service
     - Provide your platform/business information
     - Complete your platform profile

## Step 2: Enable Express Accounts

1. **In Connect Settings**
   - After enabling Connect, you'll see options for account types
   - Look for **"Onboarding hosted by Stripe"** section

2. **Select Express Accounts**
   - Choose **"Onboarding hosted by Stripe"** (first option)
   - This enables Express accounts with Stripe-hosted onboarding

3. **Configure Express Settings** (optional)
   - You can customize:
     - Branding (logo, colors)
     - Onboarding requirements
     - Payout schedules

## Step 3: Enable Financial Connections

1. **Navigate to External Accounts Settings**
   - Still in **Settings → Connect**
   - Scroll down to **"External Accounts"** section
   - Or go directly to: https://dashboard.stripe.com/settings/connect/external_accounts

2. **Enable External Account Collection**
   - Toggle ON **"Collect external account details"**
   - This allows collecting bank account information

3. **Enable Financial Connections** (for instant verification)
   - Toggle ON **"Financial Connections"**
   - This enables instant bank account verification using Stripe Financial Connections
   - Note: Financial Connections is available in select countries (US, UK, etc.)

4. **Configure Financial Connections Settings** (if enabled)
   - Select which features to enable:
     - **Balances** - View account balances
     - **Ownership** - Verify account ownership
     - **Transactions** - View transaction history (optional)
   - Choose which countries to enable it for

## Step 4: Verify Settings

1. **Check Express Accounts Status**
   - In Connect Settings, verify Express accounts show as "Enabled"
   - You should see "Express" listed under account types

2. **Check Financial Connections Status**
   - In External Accounts section, verify:
     - "Collect external account details" is ON
     - "Financial Connections" is ON (if you enabled it)

## Step 5: Test the Integration

1. **Test Mode**
   - Make sure you're in **Test Mode** (toggle in top right of Stripe Dashboard)
   - Use test API keys in your Edge Functions

2. **Test Account Creation**
   - Run your app
   - Try creating a payment account as a pilot
   - The onboarding flow should redirect to Stripe

## Visual Guide

### Connect Settings Page Structure:
```
Settings → Connect
├── Account Types
│   └── Onboarding hosted by Stripe ✓ (Enable this)
├── External Accounts
│   ├── Collect external account details ✓ (Enable this)
│   └── Financial Connections ✓ (Enable this)
└── Other settings...
```

## Important Notes

1. **Test vs Live Mode**
   - Enable Connect in both Test and Live modes separately
   - Test mode: Use for development
   - Live mode: Use for production

2. **Financial Connections Availability**
   - Financial Connections is available in limited countries
   - Check Stripe's documentation for current availability
   - US and UK are typically supported

3. **Account Requirements**
   - Express accounts require minimal information upfront
   - Additional information is collected during onboarding
   - Bank accounts are collected during onboarding if Financial Connections is enabled

## Troubleshooting

### If Express accounts option doesn't appear:
- Make sure Connect is fully enabled
- Complete the Connect onboarding process
- Refresh the page

### If Financial Connections option doesn't appear:
- Check if your account country supports Financial Connections
- Verify you're using a supported Stripe account type
- Contact Stripe support if needed

### After enabling, test again:
- The error "You can only create new accounts if you've signed up for Connect" should be resolved
- Account creation should work
- Onboarding flow should redirect to Stripe

## Quick Links

- **Connect Settings**: https://dashboard.stripe.com/settings/connect
- **External Accounts**: https://dashboard.stripe.com/settings/connect/external_accounts
- **Stripe Connect Docs**: https://docs.stripe.com/connect
- **Express Accounts Docs**: https://docs.stripe.com/connect/express-accounts
- **Financial Connections Docs**: https://docs.stripe.com/connect/payouts-bank-accounts

