# Remove Demo Courses Instructions

## Problem
Demo courses like "3D Mapping & Surveying", "FAA Part 107 Certification Prep", etc. are appearing in the Academy view because they were inserted as sample data in the database.

## Solution
Run the SQL script `remove_demo_courses.sql` in your Supabase SQL Editor to delete all courses except the UAS Pilot Course.

## Steps

1. **Open Supabase Dashboard**
   - Go to your Supabase project
   - Navigate to SQL Editor

2. **Run the Cleanup Script**
   - Copy the contents of `remove_demo_courses.sql`
   - Paste into SQL Editor
   - Click "Run" or press Cmd/Ctrl + Enter

3. **Verify Results**
   - Uncomment the verification queries at the bottom of the script
   - Run them to confirm only UAS Pilot Course remains

## What Gets Deleted

- ✅ All demo courses (FAA Part 107, Advanced Flight Maneuvers, Aerial Photography, etc.)
- ✅ Course units belonging to deleted courses
- ✅ Course enrollments for deleted courses (automatically via CASCADE)

## What Gets Preserved

- ✅ UAS Pilot Course (with UUID: `a1b2c3d4-e5f6-7890-abcd-ef1234567890`)
- ✅ All 20 units for UAS Pilot Course
- ✅ Badges (they reference courses but won't be deleted, just set to NULL)

## After Running

After running the script, refresh your Academy view in the app. You should only see:
- **UAS Pilot Course** (Provider: Buzz, Rating: 4.95, Students: dynamically updated)

## Notes

- This operation is **irreversible** - make sure you want to delete these courses
- If you need to keep any specific course, modify the WHERE clause in the script
- The script uses the UUID to identify UAS Pilot Course, which is more reliable than using title

