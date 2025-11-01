-- Storage Setup for Profile Pictures
-- Run this SQL in your Supabase SQL Editor to set up the profile-pictures bucket

-- Create the profile-pictures bucket (public access for viewing)
INSERT INTO storage.buckets (id, name, public)
VALUES ('profile-pictures', 'profile-pictures', true)
ON CONFLICT (id) DO NOTHING;

-- Profile Pictures Storage Policies
-- Allow everyone to view profile pictures
CREATE POLICY "Users can view all profile pictures"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'profile-pictures');

-- Allow users to upload their own profile picture
CREATE POLICY "Users can upload their own profile picture"
    ON storage.objects FOR INSERT
    WITH CHECK (
        bucket_id = 'profile-pictures' 
        AND auth.uid()::text = (storage.foldername(name))[1]
    );

-- Allow users to update their own profile picture
CREATE POLICY "Users can update their own profile picture"
    ON storage.objects FOR UPDATE
    USING (
        bucket_id = 'profile-pictures' 
        AND auth.uid()::text = (storage.foldername(name))[1]
    );

-- Allow users to delete their own profile picture
CREATE POLICY "Users can delete their own profile picture"
    ON storage.objects FOR DELETE
    USING (
        bucket_id = 'profile-pictures' 
        AND auth.uid()::text = (storage.foldername(name))[1]
    );

