# Permit Badges Implementation Guide

## Overview

This document explains how the Permit Badges feature works in the Buzz application. Permit badges (Flight Reviewer and ROC-A Examiner) are automatically awarded by the backend when pilots upload qualifying licenses.

## Architecture

### Backend-Driven Badge Awarding

The permit badge system uses a **database-driven** approach where badge awarding is handled entirely by PostgreSQL triggers and functions, rather than application logic.

**Benefits:**
- ✅ Consistent badge awarding regardless of client (iOS, web, etc.)
- ✅ Atomic operations - badge is awarded in the same transaction as license upload
- ✅ No duplicate badges - database enforces uniqueness
- ✅ Automatic retroactive awarding for existing licenses
- ✅ Simpler client code - just insert license and sync badges

## Complete Flow

### 1. Pilot Uploads License (iOS App)

```swift
// LicenseUploadService.swift
func uploadLicense(pilotId: UUID, data: Data, fileName: String, fileType: LicenseFileType, licenseType: String?)
```

**What happens:**
1. Pilot selects "Flight Reviewer (CAN)" or "ROC-A (CAN)" from license type dropdown
2. App uploads file to Supabase Storage (`pilot-licenses` bucket)
3. App inserts record into `pilot_licenses` table with `license_type` field

### 2. Database Trigger Fires (Automatic)

```sql
CREATE TRIGGER trigger_award_permit_badge
AFTER INSERT ON public.pilot_licenses
FOR EACH ROW
EXECUTE FUNCTION public.award_permit_badge_for_license();
```

**What happens:**
1. Trigger detects new license inserted
2. Calls `award_permit_badge_for_license()` function
3. Function runs immediately in the same transaction

### 3. Badge Awarding Logic (Database Function)

```sql
CREATE OR REPLACE FUNCTION public.award_permit_badge_for_license()
```

**What the function does:**
1. Checks `license_type` field of newly inserted license
2. Maps license type to badge type:
   - `"Flight Reviewer (CAN)"` → `flight_reviewer` badge
   - `"ROC-A Certificate (CAN)"` → `roc_a_examiner` badge
3. Checks if pilot already has this badge type
4. If not, inserts new badge record into `badges` table
5. Returns control to complete the transaction

### 4. iOS App Syncs Badges

After license upload completes, the BadgesView automatically refreshes badges when the user navigates to it.

**BadgesView.swift:**
```swift
.task {
    await loadBadges()
}

private func loadBadges() async {
    guard let currentUser = authService.currentUser else { return }
    async let badgesTask = badgeService.fetchPilotBadges(pilotId: currentUser.id)
    async let availableBadgesTask = badgeService.fetchAvailableBadges(pilotId: currentUser.id)
    
    try? await badgesTask
    try? await availableBadgesTask
}
```

## Database Schema

### Tables Involved

#### `pilot_licenses`
```sql
CREATE TABLE public.pilot_licenses (
  id uuid PRIMARY KEY,
  pilot_id uuid REFERENCES public.profiles(id),
  file_url text NOT NULL,
  file_type text CHECK (file_type IN ('pdf', 'image')),
  license_type text,  -- Important: Must match exact strings
  uploaded_at timestamp with time zone DEFAULT now()
);
```

#### `badges`
```sql
CREATE TABLE public.badges (
  id uuid PRIMARY KEY,
  pilot_id uuid REFERENCES public.profiles(id),
  badge_type text CHECK (badge_type IN ('course', 'ex_military', 'buzz', 'government_employee', 'faa', 'flight_reviewer', 'roc_a_examiner')),
  course_id uuid (NULL for permit badges),
  course_title text,
  course_category text,
  provider text DEFAULT 'Buzz',
  earned_at timestamp with time zone DEFAULT now()
);
```

#### `badges_catalog`
```sql
-- Defines available badges
INSERT INTO public.badges_catalog VALUES
  ('flight_reviewer', 'Flight Reviewer', 'Permits', ...),
  ('roc_a_examiner', 'ROC-A Examiner', 'Permits', ...);
```

## License Type Strings (Important!)

The system requires **exact string matches** for automatic badge awarding:

| License Type (must match exactly)  | Badge Type        | Badge Display Name |
|------------------------------------|-------------------|--------------------|
| `Flight Reviewer (CAN)`        | `flight_reviewer` | Flight Reviewer    |
| `ROC-A Certificate (CAN)`          | `roc_a_examiner`  | ROC-A Examiner     |

These strings are defined in the iOS app:

**PilotLicense.swift:**
```swift
enum LicenseType: String, CaseIterable {
    case rpaFlightReviewer = "Flight Reviewer (CAN)"
    case rocaCertificate = "ROC-A Certificate (CAN)"
    // ... other license types
}
```

## Retroactive Badge Awarding

For existing licenses uploaded before this feature was implemented:

```sql
-- Award badges for all existing qualifying licenses
SELECT * FROM public.award_permit_badges_for_existing_licenses();
```

**Output example:**
```
pilot_id                              | badge_type        | license_type                  | status
--------------------------------------|-------------------|-------------------------------|---------------
550e8400-e29b-41d4-a716-446655440000 | flight_reviewer   | Flight Reviewer (CAN)    | awarded
660e8400-e29b-41d4-a716-446655440001 | roc_a_examiner    | ROC-A Certificate (CAN)      | already_exists
```

## UI Display

### Badge Categories

Badges are organized into three categories in BadgesView:

1. **Academy** - Course completion badges (badge_type = 'course')
2. **Affiliations** - Criteria-based badges (ex_military, government_employee, faa, buzz)
3. **Permits** - License-based badges (flight_reviewer, roc_a_examiner) ← NEW

**BadgesView.swift:**
```swift
enum BadgeCategory: String, Hashable {
    case academy = "Academy"
    case affiliations = "Affiliations"
    case permits = "Permits"
}
```

### Badge Display Properties

**Flight Reviewer Badge:**
- Color: Teal
- Icon: `person.text.rectangle.fill`
- Category: Permits
- Provider: Buzz

**ROC-A Examiner Badge:**
- Color: Indigo
- Icon: `antenna.radiowaves.left.and.right`
- Category: Permits
- Provider: Buzz

## Files Modified

### Backend (Database)
- ✅ `supabase/migrations/20251129_add_permit_badge_types.sql` - Main migration
- ✅ `supabase/migrations/20251129_add_permit_badge_types_rollback.sql` - Rollback migration
- ✅ `supabase/migrations/README.md` - Migration documentation

### iOS App
- ✅ `Buzz/Models/Badge.swift` - Added permit badge types
- ✅ `Buzz/Models/PilotLicense.swift` - License types already defined
- ✅ `Buzz/Views/Profile/BadgesView.swift` - Added Permits category
- ✅ `Buzz/Services/BadgeService.swift` - Added awardPermitBadge() (kept for manual use)
- ✅ `Buzz/Services/LicenseUploadService.swift` - Removed badge awarding logic (backend handles it)

## Testing

### Test New License Upload

1. Upload a license with type "Flight Reviewer (CAN)"
2. Check `pilot_licenses` table - should have new record
3. Check `badges` table - should automatically have new badge with `badge_type = 'flight_reviewer'`
4. Open Badges view in app - should show Flight Reviewer badge under "Permits" category

### Test Existing Licenses

```sql
-- Check for existing qualifying licenses without badges
SELECT pl.pilot_id, pl.license_type, pl.uploaded_at,
       CASE 
         WHEN EXISTS (
           SELECT 1 FROM badges b 
           WHERE b.pilot_id = pl.pilot_id 
           AND b.badge_type IN ('flight_reviewer', 'roc_a_examiner')
         ) THEN 'Has Badge'
         ELSE 'Missing Badge'
       END as badge_status
FROM pilot_licenses pl
WHERE pl.license_type IN ('Flight Reviewer (CAN)', 'ROC-A (CAN)');

-- Award badges for existing licenses
SELECT * FROM award_permit_badges_for_existing_licenses();
```

### Verify Trigger

```sql
-- Check trigger is enabled
SELECT tgname, tgenabled, tgrelid::regclass 
FROM pg_trigger 
WHERE tgname = 'trigger_award_permit_badge';

-- Should return:
-- tgname: trigger_award_permit_badge
-- tgenabled: O (enabled)
-- tgrelid: pilot_licenses
```

## Troubleshooting

### Badge Not Auto-Awarded

**Check 1: License type string**
```sql
SELECT license_type FROM pilot_licenses WHERE id = '<license-id>';
-- Must be EXACTLY: "Flight Reviewer (CAN)" or "ROC-A (CAN)"
```

**Check 2: Trigger enabled**
```sql
SELECT tgenabled FROM pg_trigger WHERE tgname = 'trigger_award_permit_badge';
-- Should be: 'O' (enabled)
```

**Check 3: Function exists**
```sql
SELECT proname FROM pg_proc WHERE proname = 'award_permit_badge_for_license';
-- Should return: award_permit_badge_for_license
```

**Check 4: Badge already exists**
```sql
SELECT * FROM badges 
WHERE pilot_id = '<pilot-id>' 
AND badge_type IN ('flight_reviewer', 'roc_a_examiner');
-- Function prevents duplicates
```

### Manual Badge Award

If you need to manually award a badge:

```sql
-- Award Flight Reviewer badge
INSERT INTO badges (pilot_id, badge_type, course_title, course_category, provider, earned_at)
VALUES ('<pilot-id>', 'flight_reviewer', 'Flight Reviewer', 'Permits', 'Buzz', NOW());

-- Award ROC-A Examiner badge
INSERT INTO badges (pilot_id, badge_type, course_title, course_category, provider, earned_at)
VALUES ('<pilot-id>', 'roc_a_examiner', 'ROC-A Examiner', 'Permits', 'Buzz', NOW());
```

## Security Considerations

### Row Level Security (RLS)

Ensure RLS policies allow:
1. Pilots to insert their own licenses
2. Pilots to read their own badges
3. Service role to insert badges via trigger

```sql
-- Example RLS policy for badges
CREATE POLICY "Pilots can view their own badges"
ON badges FOR SELECT
USING (auth.uid() = pilot_id);

-- Trigger runs as SECURITY DEFINER (bypasses RLS)
```

## Future Enhancements

Potential improvements:
- [ ] Badge expiration for permit badges (if permits expire)
- [ ] Email notification when badge is auto-awarded
- [ ] Push notification in iOS app
- [ ] Admin dashboard to view all permit badges
- [ ] Badge revocation if license is deleted/expired
- [ ] Support for additional permit types

## Summary

The permit badges feature demonstrates a **backend-first architecture** where business logic lives in the database rather than the application. This ensures consistency, reduces client complexity, and makes the system easier to maintain and extend.

**Key Takeaway:** When a pilot uploads a qualifying license, the database automatically awards the corresponding badge - no client-side logic required!

