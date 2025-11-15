-- Create storage bucket for course materials (PDFs)
-- Run this SQL in your Supabase SQL Editor

-- Create the course-materials bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'course-materials',
    'course-materials',
    true, -- Public bucket so PDFs can be accessed
    52428800, -- 50MB file size limit
    ARRAY['application/pdf'] -- Only allow PDF files
)
ON CONFLICT (id) DO NOTHING;

-- Set up storage policies for course-materials bucket
-- Allow anyone to read/view course materials (public bucket)
CREATE POLICY "Anyone can view course materials"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'course-materials');

-- Allow authenticated users to upload course materials
CREATE POLICY "Authenticated users can upload course materials"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'course-materials');

-- Allow authenticated users to update course materials
CREATE POLICY "Authenticated users can update course materials"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'course-materials');

-- Allow authenticated users to delete course materials
CREATE POLICY "Authenticated users can delete course materials"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'course-materials');

-- Verify bucket was created
-- SELECT * FROM storage.buckets WHERE id = 'course-materials';

