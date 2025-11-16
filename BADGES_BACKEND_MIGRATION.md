# Badges Backend Migration Guide

## Overview
Badges are now dynamically managed through a backend catalog system instead of being hardcoded in the app. This allows for easy badge management without code changes.

## Migration Steps

### Step 1: Run Badges Catalog Migration
Run `create_badges_catalog_migration.sql` in your Supabase SQL Editor. This creates:
- `badges_catalog` table - stores all available badge definitions
- `get_available_badges_for_pilot()` function - returns badges available to a specific pilot

### Step 2: Run Criteria Badges Migration (if not already done)
Run `add_criteria_badges_migration.sql` in your Supabase SQL Editor. This:
- Adds profile fields for badge criteria
- Updates badges table to support criteria badges
- Creates automatic badge awarding function

## Badge Names

The following badge names are used:
- **Ex-Military** (was: Ex-Military) ✓
- **Buzz** (was: Buzz Affiliate)
- **Government** (was: Government Employee)
- **FAA** (was: FAA Certified)

## Badges Catalog Table

The `badges_catalog` table stores badge definitions with:
- `badge_type`: Type of badge (course, ex_military, buzz, government_employee, faa)
- `title`: Display name of the badge
- `category`: Category text (optional, not displayed in UI)
- `course_id`: For course badges only
- `icon_name`: SF Symbol name
- `color_name`: Color name (blue, purple, green, red, etc.)
- `provider`: Provider name
- `is_active`: Whether badge is currently available
- `display_order`: Order for display

## How It Works

1. **Fetching Available Badges**: The app calls `get_available_badges_for_pilot()` which:
   - Returns criteria badges from `badges_catalog` that haven't been earned
   - Returns course badges from `training_courses` that haven't been earned
   - Filters out badges the pilot already has

2. **Badge Awarding**: When profile criteria are met, the `award_criteria_badges()` trigger:
   - Fetches badge details from `badges_catalog`
   - Creates a badge record with the correct title and metadata

## Adding New Badges

To add a new badge:

1. Insert into `badges_catalog`:
```sql
INSERT INTO badges_catalog (badge_type, title, category, course_id, icon_name, color_name, provider, is_recurrent, is_active, display_order)
VALUES ('new_badge_type', 'New Badge Name', 'Category', NULL, 'icon.name', 'blue', 'Buzz', FALSE, TRUE, 5);
```

2. Update the `BadgeType` enum in `Badge.swift` if needed
3. Update the trigger function if it's a criteria-based badge

## UI Changes

- Badge titles come from the backend (no hardcoding)
- Category text is removed from display
- "Complete course to earn" / "Meet criteria to earn" text is removed
- Provider tags show "Academy" for course badges, "Affiliations" for criteria badges

