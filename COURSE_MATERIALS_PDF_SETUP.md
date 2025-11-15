# Course Materials PDF Setup Guide

## Overview
This guide explains how to set up PDF course materials for the UAS Pilot Course units. The system uses Supabase Storage to store PDFs and displays them using an in-app PDF viewer.

## Database Setup

### 1. Create Storage Bucket
Run the SQL script `create_course_materials_bucket.sql` in your Supabase SQL Editor:
- Creates a public bucket named `course-materials`
- Sets 50MB file size limit
- Allows only PDF files
- Sets up proper access policies

### 2. Add PDF URL Column
The migration `create_uas_pilot_course_migration.sql` has been updated to include:
- `pdf_url` column in `course_units` table
- Migration script to add column if table already exists

## Uploading PDFs

### Step 1: Upload PDF to Supabase Storage
1. Go to Supabase Dashboard → Storage → `course-materials` bucket
2. Create folders for organization (e.g., `unit-1/`, `unit-2/`, etc.)
3. Upload your PDF files
4. Copy the public URL for each PDF

### Step 2: Update Course Units with PDF URLs
For each unit that has a PDF, update the `pdf_url` field in the `course_units` table:

```sql
-- Example: Update UNIT 1 with PDF URL
UPDATE course_units 
SET pdf_url = 'https://mzapuczjijqjzdcujetx.supabase.co/storage/v1/object/public/course-materials/unit-1/ground-school.pdf'
WHERE course_id = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890' 
  AND unit_number = 1;
```

### PDF URL Format
The URL format should be:
```
https://[your-project].supabase.co/storage/v1/object/public/course-materials/[folder]/[filename].pdf
```

Example:
```
https://mzapuczjijqjzdcujetx.supabase.co/storage/v1/object/public/course-materials/unit-1/ground-school.pdf
```

## How It Works

### User Flow
1. User navigates to Academy → UAS Pilot Course
2. User clicks "Enroll Now" → Goes to Course Content view
3. User taps on a unit → Goes to Unit Detail view
4. If PDF is available, user sees "View Course Material PDF" button
5. User clicks button → PDF opens in in-app viewer
6. User can read, zoom, and navigate the PDF

### Code Implementation

#### CourseUnit Model
- Added `pdfUrl: String?` field
- Automatically decoded from database `pdf_url` column

#### UnitDetailView
- Shows "View Course Material PDF" button if `pdfUrl` is not empty
- Uses `FileViewer` component to display PDF
- Opens PDF in a sheet modal with navigation controls

#### FileViewer Component
- Handles PDF loading and display
- Uses PDFKit for rendering
- Supports zoom, scroll, and navigation
- Shows loading state while fetching PDF

## Example: Adding PDF to Unit

### Via SQL (Recommended)
```sql
-- Update UNIT 1 - GROUND SCHOOL with PDF
UPDATE course_units 
SET pdf_url = 'https://mzapuczjijqjzdcujetx.supabase.co/storage/v1/object/public/course-materials/unit-1/ground-school.pdf',
    updated_at = NOW()
WHERE course_id = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890' 
  AND unit_number = 1;

-- Update UNIT 2 - HEALTH & SAFETY with PDF
UPDATE course_units 
SET pdf_url = 'https://mzapuczjijqjzdcujetx.supabase.co/storage/v1/object/public/course-materials/unit-2/health-safety.pdf',
    updated_at = NOW()
WHERE course_id = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890' 
  AND unit_number = 2;
```

### Via Supabase Dashboard
1. Go to Table Editor → `course_units`
2. Find the unit you want to update
3. Edit the `pdf_url` field
4. Paste the public URL from Storage
5. Save

## File Organization Recommendations

### Folder Structure
```
course-materials/
├── unit-1/
│   └── ground-school.pdf
├── unit-2/
│   └── health-safety.pdf
├── unit-3/
│   └── operations.pdf
├── step-1/
│   ├── unit-4-drone-pilot.pdf
│   └── unit-5-camera-payload.pdf
└── step-2/
    ├── unit-6-drone-business.pdf
    └── ...
```

### Naming Convention
- Use lowercase with hyphens: `unit-1-ground-school.pdf`
- Be descriptive but concise
- Include unit number for easy identification

## Testing

1. **Upload a test PDF** to the `course-materials` bucket
2. **Update a unit** with the PDF URL
3. **Open the app** → Academy → UAS Pilot Course
4. **Navigate to the unit** with the PDF
5. **Click "View Course Material PDF"** button
6. **Verify** PDF loads and displays correctly

## Troubleshooting

### PDF Button Not Showing
- Check that `pdf_url` is not NULL or empty in database
- Verify the URL is accessible (try opening in browser)
- Check that URL format matches expected pattern

### PDF Not Loading
- Verify PDF URL is correct and accessible
- Check bucket permissions (should be public)
- Verify file exists in Storage bucket
- Check network connectivity

### FileViewer Errors
- Ensure `FileViewer` component is imported
- Verify bucket name matches: `course-materials`
- Check that PDF file is valid (not corrupted)

## Security Notes

- The `course-materials` bucket is **public** for easy access
- Only authenticated users can upload/update/delete files
- Anyone can view/download PDFs (intended behavior for course materials)
- Consider adding authentication if you need restricted access later

## Next Steps

1. ✅ Run `create_course_materials_bucket.sql` to create storage bucket
2. ✅ Upload your PDF files to the bucket
3. ✅ Update `course_units` table with PDF URLs
4. ✅ Test PDF viewing in the app
5. ✅ Add PDFs for all units as they become available

## Support

If you need help:
- Check Supabase Storage documentation
- Verify file URLs are correct
- Test PDF URLs in browser first
- Check app logs for error messages

