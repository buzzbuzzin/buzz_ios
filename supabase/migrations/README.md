# Database Migrations

This directory contains SQL migration files for the Buzz application database.

## Migration Files

### `20251129_add_permit_badge_types.sql`
Adds support for permit badges (Flight Reviewer and ROC-A Examiner).

**Changes:**
- Updates `badges` table constraint to allow `flight_reviewer` and `roc_a_examiner` badge types
- Updates `badges_catalog` table constraint to allow new badge types
- Inserts permit badge definitions into `badges_catalog`
- Creates optional database function `award_permit_badge_for_license()` for automatic badge awarding
- Includes optional trigger (commented out by default)

### `20251129_add_permit_badge_types_rollback.sql`
Rollback migration to undo the permit badges changes.

**Warning:** This will delete all existing permit badges from the database!

## How to Run Migrations

### Using Supabase CLI

If you have the Supabase CLI installed:

```bash
# Run the migration
supabase db push

# Or run a specific migration
psql -h <your-db-host> -U <your-db-user> -d <your-db-name> -f supabase/migrations/20251129_add_permit_badge_types.sql
```

### Using Supabase Dashboard

1. Go to your Supabase project dashboard
2. Navigate to the SQL Editor
3. Copy the contents of `20251129_add_permit_badge_types.sql`
4. Paste into the SQL Editor
5. Click "Run"

### Using Direct Database Connection

```bash
# Connect to your database
psql <your-database-connection-string>

# Run the migration
\i supabase/migrations/20251129_add_permit_badge_types.sql
```

## Rollback Instructions

If you need to undo the migration:

```bash
# Using psql
psql <your-database-connection-string> -f supabase/migrations/20251129_add_permit_badge_types_rollback.sql

# Or via Supabase Dashboard SQL Editor
# Copy and run the contents of 20251129_add_permit_badge_types_rollback.sql
```

## Notes

### Automatic Badge Awarding

The migration includes a database function and trigger that automatically awards permit badges when licenses are uploaded. 

**Current Setup:** Badge awarding is handled by the database trigger. When a pilot uploads a license with type "RPA Flight Reviewer (CAN)" or "ROC-A Certificate (CAN)", the database automatically creates the corresponding badge entry.

**How It Works:**
1. Pilot uploads a license via the iOS app (`LicenseUploadService`)
2. License is inserted into `pilot_licenses` table with `license_type` field
3. Database trigger `trigger_award_permit_badge` fires automatically
4. Function `award_permit_badge_for_license()` checks the license type and awards the appropriate badge
5. iOS app syncs badges from backend to display the newly awarded badge

### Badge Catalog Entries

The migration automatically populates the `badges_catalog` table with:

1. **Flight Reviewer**
   - Type: `flight_reviewer`
   - Category: Permits
   - Icon: `person.text.rectangle.fill`
   - Color: Teal
   - Display Order: 100

2. **ROC-A Examiner**
   - Type: `roc_a_examiner`
   - Category: Permits
   - Icon: `antenna.radiowaves.left.and.right`
   - Color: Indigo
   - Display Order: 101

### License Type Mapping

The system maps the following license types to permit badges:

- `"RPA Flight Reviewer (CAN)"` → Flight Reviewer badge
- `"ROC-A Certificate (CAN)"` → ROC-A Examiner badge

This mapping is defined in the database function `award_permit_badge_for_license()`.

**Important:** The `license_type` field in the `pilot_licenses` table must exactly match these strings for automatic badge awarding to work.

## Awarding Badges for Existing Licenses

If you have existing licenses in your database that were uploaded before this migration, you can retroactively award permit badges using the provided function:

```sql
-- Run this to award badges for all existing qualifying licenses
SELECT * FROM public.award_permit_badges_for_existing_licenses();
```

This function will:
- Find all licenses with type "RPA Flight Reviewer (CAN)" or "ROC-A Certificate (CAN)"
- Check if the pilot already has the corresponding badge
- Award the badge if they don't have it yet
- Return a table showing results for each license

Example output:
```
pilot_id                              | badge_type        | license_type                  | status
--------------------------------------|-------------------|-------------------------------|---------------
550e8400-e29b-41d4-a716-446655440000 | flight_reviewer   | RPA Flight Reviewer (CAN)    | awarded
660e8400-e29b-41d4-a716-446655440001 | roc_a_examiner    | ROC-A Certificate (CAN)      | already_exists
```

## Verification

After running the migration, verify the changes:

```sql
-- Check badges table constraint
SELECT conname, pg_get_constraintdef(oid) 
FROM pg_constraint 
WHERE conname = 'badges_badge_type_check';

-- Check badges_catalog entries
SELECT badge_type, title, category, icon_name, color_name 
FROM public.badges_catalog 
WHERE badge_type IN ('flight_reviewer', 'roc_a_examiner');

-- Check functions exist
SELECT proname 
FROM pg_proc 
WHERE proname IN ('award_permit_badge_for_license', 'award_permit_badges_for_existing_licenses');

-- Check trigger exists
SELECT tgname, tgenabled 
FROM pg_trigger 
WHERE tgname = 'trigger_award_permit_badge';

-- Test badge awarding for existing licenses (dry run - view results without committing)
BEGIN;
SELECT * FROM public.award_permit_badges_for_existing_licenses();
ROLLBACK;
```

## Support

For issues or questions, refer to the main project documentation or contact the development team.

