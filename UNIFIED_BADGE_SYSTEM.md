# Unified Badge System Architecture

## Overview
This document describes the unified badge system where **ALL badges** (course badges + criteria badges) are managed through a single `badges_catalog` table. This provides a single source of truth, better scalability, and easier management.

## Architecture

### Tables

1. **`badges_catalog`** - Single source of truth for ALL badge definitions
   - Stores both course badges and criteria badges
   - Contains badge metadata: title, icon, color, provider, etc.
   - `is_active` flag to enable/disable badges without deleting them
   - `display_order` for custom ordering

2. **`badges`** - Stores earned badges (who has what badge)
   - Links pilot to badge via `course_id` (for course badges) or `badge_type` (for criteria badges)
   - Stores `earned_at` timestamp
   - Stores expiration info for recurrent badges

### Key Functions

1. **`get_available_badges_for_pilot(pilot_id)`**
   - Returns all badges from `badges_catalog` that the pilot can earn but hasn't earned yet
   - Filters out already-earned badges by checking `badges` table
   - **ONLY** fetches from `badges_catalog` (no more direct `training_courses` queries)

2. **`award_badge_from_catalog(pilot_id, course_id, badge_type)`**
   - Awards a badge by fetching details from `badges_catalog`
   - Ensures badge details (title, icon, color) come from catalog
   - Prevents duplicate badges

3. **`sync_course_to_badge_catalog()`** (Trigger)
   - Automatically syncs new courses to `badges_catalog` when courses are created/updated
   - Ensures course badges are always in sync with courses

## How It Works

### Course Badges

1. **When a course is created:**
   - Trigger `trigger_sync_course_to_badge_catalog` fires
   - Course is automatically added to `badges_catalog` with `badge_type = 'course'`

2. **When a pilot completes a course:**
   - App calls `awardBadge(pilotId, courseId, ...)`
   - `BadgeService.awardBadge()` calls `award_badge_from_catalog()` database function
   - Function fetches badge details from `badges_catalog`
   - Badge is inserted into `badges` table with correct metadata

3. **When viewing available badges:**
   - App calls `fetchAvailableBadges(pilotId)`
   - `get_available_badges_for_pilot()` returns badges from `badges_catalog`
   - Filters out badges pilot already has (from `badges` table)

### Criteria Badges

1. **Badge definitions:**
   - Stored in `badges_catalog` with `badge_type` = 'ex_military', 'buzz', 'government_employee', or 'faa'
   - Created via migration or admin interface

2. **When criteria is met:**
   - Trigger `trigger_award_criteria_badges` fires on `profiles` table update
   - Calls `award_criteria_badges()` function
   - Function fetches badge details from `badges_catalog`
   - Badge is inserted into `badges` table

3. **When viewing available badges:**
   - Same as course badges - fetched from `badges_catalog`

## Benefits

1. **Single Source of Truth**: All badge definitions in one place
2. **Easy Management**: Add/edit/disable badges without code changes
3. **Consistency**: Badge titles/icons always match catalog
4. **Scalability**: Works efficiently with many users and badges
5. **Safety**: Badge details can't be hardcoded incorrectly
6. **Flexibility**: Can easily add new badge types or modify existing ones

## Migration Steps

1. Run `unified_badge_system_migration.sql`:
   - Syncs existing courses to `badges_catalog`
   - Creates trigger to auto-sync new courses
   - Updates `get_available_badges_for_pilot()` to only use catalog
   - Creates `award_badge_from_catalog()` function

2. Update app code:
   - `BadgeService.awardBadge()` now uses `award_badge_from_catalog()` function
   - Falls back to direct insert if function doesn't exist (backward compatibility)

## Managing Badges

### Adding a New Course Badge
- Just create a new course in `training_courses` table
- Trigger automatically adds it to `badges_catalog`

### Adding a New Criteria Badge
1. Insert into `badges_catalog`:
```sql
INSERT INTO badges_catalog (badge_type, title, category, course_id, icon_name, color_name, provider, is_recurrent, is_active, display_order)
VALUES ('new_type', 'New Badge', 'Category', NULL, 'icon.name', 'blue', 'Buzz', FALSE, TRUE, 5);
```

2. Update `BadgeType` enum in `Badge.swift` if needed
3. Update trigger function to award badge when criteria is met

### Disabling a Badge
```sql
UPDATE badges_catalog SET is_active = FALSE WHERE badge_type = 'course' AND course_id = '...';
```

### Changing Badge Display Name
```sql
UPDATE badges_catalog SET title = 'New Name' WHERE badge_type = 'buzz';
```

## Performance Considerations

- **Indexes**: Ensure indexes on:
  - `badges_catalog(badge_type, course_id)` - for lookups
  - `badges(pilot_id, course_id)` - for checking earned badges
  - `badges(pilot_id, badge_type)` - for criteria badges

- **Caching**: Consider caching `badges_catalog` in app (rarely changes)
- **Pagination**: For large badge lists, consider pagination in `get_available_badges_for_pilot()`

## Security

- RLS policies ensure pilots can only view their own earned badges
- `badges_catalog` is read-only for authenticated users
- Badge awarding functions use `SECURITY DEFINER` for controlled access

