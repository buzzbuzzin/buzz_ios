# Criteria-Based Badges Setup Guide

This guide explains how to set up and use criteria-based badges in the Buzz app.

## Overview

Criteria-based badges are automatically awarded to users based on their profile attributes. Unlike course badges, these badges are not tied to course completion but rather to user qualifications and affiliations.

## Available Badges

1. **Ex-Military Badge** - Awarded to users who are ex-military
2. **Buzz Badge** - Awarded to Buzz affiliates
3. **Government Employee Badge** - Awarded to government employees
4. **FAA Badge** - Awarded to users with FAA certification

## Database Setup

### Step 1: Run the Migration

Execute the migration SQL file in your Supabase SQL Editor:

```sql
-- Run: add_criteria_badges_migration.sql
```

This migration will:
- Add profile fields: `is_ex_military`, `is_government_employee`, `has_faa_certification`, `is_buzz_affiliate`
- Update badges table to support non-course badges (make `course_id`, `course_title`, `course_category` nullable)
- Add `badge_type` column to badges table
- Create automatic badge awarding function and trigger

### Step 2: Update User Profiles

To award badges to users, update their profile fields:

```sql
-- Award Ex-Military badge
UPDATE profiles 
SET is_ex_military = TRUE 
WHERE id = 'user-uuid-here';

-- Award Government Employee badge
UPDATE profiles 
SET is_government_employee = TRUE 
WHERE id = 'user-uuid-here';

-- Award FAA badge
UPDATE profiles 
SET has_faa_certification = TRUE 
WHERE id = 'user-uuid-here';

-- Award Buzz badge
UPDATE profiles 
SET is_buzz_affiliate = TRUE 
WHERE id = 'user-uuid-here';
```

Badges will be automatically awarded when these fields are set to `TRUE` via the database trigger.

## Badge Types

The `badge_type` field in the badges table can be:
- `course` - Badge earned from course completion (default)
- `ex_military` - Ex-Military badge
- `buzz` - Buzz Affiliate badge
- `government_employee` - Government Employee badge
- `faa` - FAA Certified badge

## Automatic Badge Awarding

The system automatically awards badges when:
1. A new profile is created with criteria fields set to `TRUE`
2. An existing profile is updated with criteria fields set to `TRUE`

The trigger `trigger_award_criteria_badges` checks for duplicate badges before inserting, so badges won't be duplicated if the profile is updated multiple times.

## Badge Display

Criteria-based badges are displayed in the Badges view alongside course badges. They have:
- Unique icons and colors based on badge type
- Display names (e.g., "Ex-Military", "FAA Certified")
- Categories (e.g., "Service Recognition", "Certification")
- No expiration dates (unlike some course badges)

## Code Changes

### Badge Model Updates

The `Badge` model now includes:
- Optional `courseId`, `courseTitle`, `courseCategory` (nullable for criteria badges)
- `badgeType` enum with all badge types
- Computed properties `displayTitle` and `displayCategory` for consistent display

### UserProfile Model Updates

The `UserProfile` model now includes:
- `isExMilitary: Bool?`
- `isGovernmentEmployee: Bool?`
- `hasFaaCertification: Bool?`
- `isBuzzAffiliate: Bool?`

## Testing

### Demo Mode

In demo mode, the BadgeService includes sample criteria badges:
- Ex-Military badge
- FAA Certified badge

### Production Mode

In production mode, badges are fetched from the database and will include any criteria-based badges that have been awarded to the user.

## Future Enhancements

Potential future improvements:
- Admin UI to manage badge criteria
- Badge verification system
- Badge revocation functionality
- Badge expiration for certain criteria badges
- Badge levels/tiers

