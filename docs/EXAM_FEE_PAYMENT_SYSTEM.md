# Exam Fee Payment System Implementation

## Overview
This document describes the implementation of the new exam fee payment system that fetches prices directly from the `course_tests` table instead of using Stripe product IDs.

## Changes Made

### 1. Database Schema (`supabase/migrations/20260119_add_price_of_schedule_to_course_tests.sql`)
- Added `price_of_schedule` column to `course_tests` table
- Stores price in cents (e.g., 9900 = $99.00)
- NULL or 0 means free exam

### 2. Model Updates (`Buzz/Models/CourseTest.swift`)
- Added `priceOfSchedule: Int?` property to `CourseTest` model
- Added `formattedPrice` computed property that returns formatted string (e.g., "$99.00" or "Free")
- Maps to `price_of_schedule` column in database

### 3. New Views

#### ProctorTestIntroView (`Buzz/Views/Academy/TestCenter/ProctorTestIntroView.swift`)
- Displays test details, description, and pricing information
- Shows prerequisites status and eligibility
- Navigates to scheduling view when user clicks "Schedule Exam"
- Uses `test.formattedPrice` to display the price from database

#### ProctorTestSchedulingView (`Buzz/Views/Academy/TestCenter/ProctorTestSchedulingView.swift`)
- Complete exam scheduling interface with:
  - Date picker (tomorrow to 3 months out)
  - Time slot selection (9 AM - 5 PM, 30-minute intervals)
  - Location type selection (In-Person or Online via Zoom)
  - Address input for in-person exams
  - Summary section showing all details
- Handles payment processing:
  - For paid exams: Creates Stripe Payment Intent and shows payment sheet
  - For free exams: Creates appointment directly without payment
- Uses `test.priceOfSchedule` (in cents) to initialize Stripe payment

### 4. Backend Edge Function (`supabase/functions/create-test-exam-payment/index.ts`)
- New Supabase Edge Function that replaces `get-exam-price` and `create-exam-payment`
- Fetches test details and price directly from `course_tests` table
- Validates that the amount matches the test's `price_of_schedule`
- Creates or retrieves Stripe customer for the pilot
- Creates Stripe Payment Intent with the test price
- Returns payment intent details for client-side payment sheet

### 5. Supporting Components

#### DetailRow
- Reusable component for displaying test details (duration, type, passing score, price)

#### TimeSlotButton
- Button for selecting time slots in the scheduling view

#### LocationTypeButton
- Button for selecting location type (In-Person vs Online)

#### SummaryRow
- Row component for the confirmation summary section

#### ExamSummaryTestCard
- Card showing test name, duration, and price at the top of scheduling view

## Payment Flow

1. **User clicks on a proctored test** in Test Center
2. **ProctorTestIntroView** displays:
   - Test details and description
   - Price from `test.formattedPrice` (fetched from database)
   - Prerequisites status
3. **User clicks "Schedule Exam"**
4. **ProctorTestSchedulingView** opens with:
   - Date and time selection
   - Location preference (in-person or online)
   - Summary showing `test.formattedPrice`
5. **User clicks "Proceed to Payment"**:
   - For **paid exams** (`test.priceOfSchedule > 0`):
     - Calls backend function `create-test-exam-payment` with price from database
     - Backend validates price matches what's in database
     - Backend creates Stripe Payment Intent
     - Shows Stripe Payment Sheet for user to complete payment
   - For **free exams** (`test.priceOfSchedule == null` or `0`):
     - Creates appointment directly without payment

## Data Flow

```
Database (course_tests.price_of_schedule)
    ↓
CourseTest.priceOfSchedule (Int? in cents)
    ↓
CourseTest.formattedPrice (String, e.g., "$99.00")
    ↓
UI Display (ProctorTestIntroView, ProctorTestSchedulingView)
    ↓
Payment Intent Creation (create-test-exam-payment function)
    ↓
Stripe Payment Sheet
    ↓
Appointment Creation
```

## Key Benefits

1. **Single Source of Truth**: Price is stored in database, not in Stripe configuration
2. **Simplified Setup**: No need to create products and prices in Stripe dashboard
3. **Flexibility**: Easy to update prices by updating database rows
4. **Consistency**: Same price is displayed throughout the UI and used for payment
5. **Validation**: Backend validates that client-provided price matches database price

## Configuration

To set up exam pricing:

```sql
-- Update price for specific tests
UPDATE course_tests 
SET price_of_schedule = 9900  -- $99.00
WHERE test_name = 'Flight Review Exam' AND needs_proctor = true;

UPDATE course_tests 
SET price_of_schedule = 7900  -- $79.00
WHERE test_name = 'ROC-A Practical Exam';

-- Set free exams
UPDATE course_tests 
SET price_of_schedule = 0
WHERE test_type = 'multiple_choice' AND needs_proctor = false;
```

## Testing

To test the implementation:

1. Set a test's `price_of_schedule` in the database
2. Navigate to Test Center in the app
3. Click on a proctored test (test with `needs_proctor = true`)
4. Verify the price displays correctly in ProctorTestIntroView
5. Click "Schedule Exam"
6. Select date, time, and location
7. Verify summary shows correct price
8. Click "Proceed to Payment"
9. Complete payment in Stripe Payment Sheet
10. Verify appointment is created

## Files Modified/Created

### Created:
- `Buzz/Views/Academy/TestCenter/ProctorTestIntroView.swift`
- `Buzz/Views/Academy/TestCenter/ProctorTestSchedulingView.swift`
- `supabase/functions/create-test-exam-payment/index.ts`
- `supabase/migrations/20260119_add_price_of_schedule_to_course_tests.sql`

### Modified:
- `Buzz/Models/CourseTest.swift` (added `priceOfSchedule` and `formattedPrice`)

### Already Exists (Used):
- `Buzz/Models/ExamAppointment.swift` (contains `ExamLocationType`, `ExamPaymentIntentResponse`)
- `Buzz/Services/ExamService.swift` (contains `getAvailableTimeSlots`)
- `Buzz/Views/Academy/TestCenter/TestCenterView.swift` (navigates to `ProctorTestIntroView`)

## Next Steps

1. **Run database migration** to add `price_of_schedule` column
2. **Update test prices** in the database for all proctored tests
3. **Deploy edge function** `create-test-exam-payment`
4. **Test payment flow** with test Stripe keys
5. **Handle appointment creation after successful payment** (may need additional work)
6. **Add email confirmation** after successful booking (may use existing exam service method)
