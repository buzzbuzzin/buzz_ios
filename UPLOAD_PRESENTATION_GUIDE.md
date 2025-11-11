# How to Upload Presentation to Supabase Storage

## Step 1: Create a Storage Bucket

1. Go to your Supabase Dashboard: https://supabase.com/dashboard
2. Select your project: `mzapuczjijqjzdcujetx`
3. Click on **Storage** in the left sidebar
4. Click **New bucket**
5. Create a bucket named: `presentations`
6. Make it **Public** (so the app can access it without authentication)
7. Click **Create bucket**

## Step 2: Upload Your Presentation

1. Click on the `presentations` bucket
2. Click **Upload file**
3. Select your presentation file (PDF, PowerPoint converted to PDF, or images)
   - Recommended: Convert your slideshow to PDF for best compatibility
   - Maximum file size: 50MB (can be increased in settings)
4. Name it something like: `buzz-auto-presentation.pdf`
5. Click **Upload**

## Step 3: Get the Public URL

After uploading, you'll see your file in the bucket. Click on it and you'll see:

**Public URL format:**
```
https://mzapuczjijqjzdcujetx.supabase.co/storage/v1/object/public/presentations/buzz-auto-presentation.pdf
```

## Step 4: Update the App

1. Open `Buzz/Views/Profile/FlightPackageView.swift`
2. Find line ~1098 where it says:
   ```swift
   private let slideshowURL = "YOUR_SUPABASE_STORAGE_URL_HERE"
   ```
3. Replace it with your actual URL:
   ```swift
   private let slideshowURL = "https://mzapuczjijqjjzdcujetx.supabase.co/storage/v1/object/public/presentations/buzz-auto-presentation.pdf"
   ```

## Alternative: Upload via Supabase CLI

```bash
# Install Supabase CLI if you haven't
npm install -g supabase

# Login
supabase login

# Link to your project
supabase link --project-ref mzapuczjijqjzdcujetx

# Upload file
supabase storage cp /path/to/your/presentation.pdf presentations/buzz-auto-presentation.pdf
```

## Supported File Formats

- **PDF** (Recommended) - Works on all devices
- **Images** (JPG, PNG) - Can create a gallery
- **Google Slides** - Export as PDF first
- **PowerPoint** - Export as PDF first

## Tips

1. **Optimize file size**: Compress your PDF to reduce loading time
2. **Use descriptive names**: e.g., `buzz-auto-membership-2024.pdf`
3. **Version control**: Add dates to filenames for updates
4. **Test the URL**: Open it in a browser first to make sure it works

## Security Note

Since this is a public bucket, anyone with the URL can access the file. If you need private presentations:
1. Make the bucket private
2. Generate signed URLs in your app
3. Use Row Level Security (RLS) policies

For now, public is fine for marketing materials.

