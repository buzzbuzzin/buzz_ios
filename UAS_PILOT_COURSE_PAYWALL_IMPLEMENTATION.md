# UAS Pilot Course Paywall Implementation

## Overview
This document describes the implementation of the paywall system, badge awarding, and testing functionality for the UAS Pilot Course.

## Features Implemented

### 1. Paywall System
- **Free Units**: Units 1-3 (Ground School) are free for all pilots
- **Premium Units**: Units 4-20 require a monthly subscription ($9.99/month)
- **Subscription Management**: Pilots can subscribe through Stripe integration
- **Access Control**: Units 4+ are locked until subscription is active

### 2. Promotion Section
- Added "New Pilot Specials" promotion card in AcademyView
- Displays discounted price ($9.99/month) for UAS Pilot Course
- Shows benefits of subscription
- Direct link to subscription flow

### 3. Ground School Badge
- Badge awarded after completing units 1-3 AND passing the test
- Badge title: "Ground School - UAS Pilot Course"
- Category: "Safety & Regulations"
- Provider: Buzz

### 4. Testing System
- Test available after completing units 1-3
- 5 questions covering ground school material
- Passing score: 70%
- Test results stored in database
- Badge only awarded upon passing the test

## Database Changes

### Migration File: `uas_pilot_course_paywall_migration.sql`

#### Tables Created:

1. **course_subscriptions**
   - Tracks subscription status for pilots
   - Links to Stripe subscription IDs
   - Stores subscription period dates
   - Status: active, canceled, past_due, incomplete, trialing

2. **unit_completions**
   - Tracks which units each pilot has completed
   - Links pilot, unit, and course
   - Timestamp of completion

3. **ground_school_test_results**
   - Stores test scores and results
   - Stores answers as JSONB
   - Tracks pass/fail status
   - One test result per pilot per course

## Code Changes

### New Services

1. **CourseSubscriptionService.swift**
   - `checkSubscriptionStatus()`: Checks if pilot has active subscription
   - `createSubscriptionRecord()`: Creates subscription record after Stripe payment
   - `updateSubscriptionStatus()`: Updates subscription status
   - `hasAccessToUnit()`: Checks if pilot can access a specific unit

### New Views

1. **CourseSubscriptionView.swift**
   - Subscription purchase flow
   - Displays pricing and features
   - Integrates with Stripe PaymentSheet
   - Shows free vs premium units

2. **GroundSchoolTestView.swift**
   - Interactive test interface
   - Progress tracking
   - Score calculation
   - Results display
   - Badge awarding on pass

### Updated Views

1. **AcademyView.swift**
   - Added `UASPilotCoursePromotionCard` component
   - Shows promotion banner for UAS Pilot Course
   - Links to subscription flow

2. **CourseContentView.swift**
   - Checks subscription status for UAS Pilot Course
   - Shows locked units for units 4+
   - Displays paywall for locked units
   - Updated `StepSectionView` to handle subscription checks
   - Updated `UnitRow` to show lock icons

3. **UnitDetailView.swift**
   - Added unit completion tracking
   - "Mark as Complete" button for units 1-3
   - "Take Ground School Test" button after completing units 1-3
   - Checks if all mandatory units are completed before showing test button

## Setup Instructions

### 1. Database Migration
Run the SQL migration file in Supabase SQL Editor:
```sql
-- Run: uas_pilot_course_paywall_migration.sql
```

### 2. Stripe Configuration
1. Create a Product in Stripe Dashboard for "UAS Pilot Course"
2. Create a Price for $9.99/month (recurring)
3. Note the Price ID (starts with `price_`)
4. Update `CourseSubscriptionView.swift` with the actual Price ID
   - Currently has placeholder: `price_placeholder`
   - Replace with actual Stripe Price ID

### 3. Edge Function (if needed)
The existing `create-subscription` edge function should work, but ensure:
- It's deployed and configured
- Stripe secret key is set in Supabase secrets
- Product/Price IDs match your Stripe configuration

## User Flow

### Free Units (1-3)
1. Pilot enrolls in UAS Pilot Course
2. Accesses units 1-3 freely
3. Marks each unit as complete
4. After completing all 3 units, "Take Ground School Test" button appears
5. Takes test (must score 70%+)
6. Upon passing, receives Ground School badge

### Premium Units (4+)
1. Pilot sees locked units 4-20
2. Clicks on locked unit or "Subscribe Now" in promotion
3. Views subscription details
4. Completes Stripe payment
5. Subscription record created in database
6. All units 4-20 become unlocked
7. Can access all premium content

## Testing Checklist

- [ ] Run database migration
- [ ] Configure Stripe Product and Price
- [ ] Test free unit access (units 1-3)
- [ ] Test unit completion tracking
- [ ] Test ground school test flow
- [ ] Verify badge awarding after passing test
- [ ] Test subscription purchase flow
- [ ] Verify units 4+ are locked without subscription
- [ ] Verify units 4+ unlock after subscription
- [ ] Test promotion card display
- [ ] Test paywall display for locked units

## Notes

- The UAS Pilot Course UUID is hardcoded: `a1b2c3d4-e5f6-7890-abcd-ef1234567890`
- Test questions are currently hardcoded in `GroundSchoolTestView.swift`
- In production, consider moving test questions to database
- Subscription price is $9.99/month (hardcoded in UI)
- Passing test score is 70% (hardcoded)

## Future Enhancements

1. Move test questions to database
2. Add more test questions
3. Add retake functionality for failed tests
4. Add subscription management (cancel, pause)
5. Add email notifications for badge awards
6. Add progress tracking dashboard
7. Add analytics for subscription conversions

