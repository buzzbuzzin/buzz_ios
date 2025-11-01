# Buzz App - Detailed Setup Guide

This guide will walk you through setting up the Buzz drone pilot booking app from scratch.

## Step 1: Create a Supabase Project

1. Go to [https://supabase.com](https://supabase.com) and sign up or log in
2. Click "New Project"
3. Fill in the project details:
   - Name: Buzz
   - Database Password: (choose a strong password)
   - Region: (choose closest to your location)
4. Wait for the project to be created (~2 minutes)

## Step 2: Set Up the Database

1. In your Supabase dashboard, click on "SQL Editor" in the left sidebar
2. Click "New Query"
3. Open the `database_schema.sql` file from the project
4. Copy all the SQL code and paste it into the query editor
5. Click "Run" to execute the script
6. You should see messages indicating successful table and policy creation

## Step 3: Configure Authentication Providers

### Email Authentication (Already enabled by default)

1. In Supabase dashboard, go to Authentication → Providers
2. Email provider should already be enabled
3. Configure email templates if desired (optional)

### Phone Authentication

1. In Supabase dashboard, go to Authentication → Providers
2. Find "Phone" and enable it
3. Choose a SMS provider (Twilio recommended)
4. Enter your Twilio credentials:
   - Account SID
   - Auth Token
   - Phone Number
5. Save the configuration

### Google Sign-In

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Create a new project or select existing one
3. Enable "Google Sign-In API"
4. Go to Credentials → Create Credentials → OAuth 2.0 Client ID
5. Choose "iOS" as application type
6. Enter your Bundle ID: `com.yourcompany.Buzz` (or your actual bundle ID)
7. Copy the Client ID
8. In Supabase dashboard, go to Authentication → Providers
9. Enable Google provider
10. Paste your Google Client ID and Client Secret

### Apple Sign-In

1. Go to [Apple Developer Portal](https://developer.apple.com)
2. Go to Certificates, Identifiers & Profiles
3. Select your App Identifier
4. Add "Sign in with Apple" capability
5. In Supabase dashboard, go to Authentication → Providers
6. Enable Apple provider
7. Follow the instructions to configure Apple authentication

## Step 4: Get Your Supabase Credentials

1. In Supabase dashboard, go to Settings → API
2. Copy the following values:
   - Project URL (e.g., `https://xxxxx.supabase.co`)
   - Anon/Public Key (the long string under "Project API keys")

## Step 5: Configure the iOS App

1. Open the Buzz project in Xcode
2. Locate `Config.example.swift` in the project
3. Create a copy and rename it to `Config.swift`
4. Replace the placeholder values:

```swift
struct Config {
    static let supabaseURL = "https://xxxxx.supabase.co"  // Your Project URL
    static let supabaseAnonKey = "your-actual-anon-key"   // Your Anon Key
    static let googleClientID = "your-google-client-id.apps.googleusercontent.com"
}
```

5. Save the file

## Step 6: Add Swift Package Dependencies

1. In Xcode, go to File → Add Package Dependencies
2. Add Supabase Swift SDK:
   - Enter URL: `https://github.com/supabase/supabase-swift`
   - Click "Add Package"
   - Select all Supabase modules
   - Click "Add Package"
3. Add Google Sign-In:
   - Go to File → Add Package Dependencies again
   - Enter URL: `https://github.com/google/GoogleSignIn-iOS`
   - Click "Add Package"
   - Select GoogleSignIn
   - Click "Add Package"

## Step 7: Configure Info.plist

1. In Xcode, locate the `Info.plist` file
2. Right-click → Open As → Source Code
3. Add the following keys:

```xml
<!-- Add inside the <dict> tag -->

<!-- Google Sign-In URL Scheme -->
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.googleusercontent.apps.YOUR-CLIENT-ID-HERE</string>
        </array>
    </dict>
</array>

<!-- Google Client ID -->
<key>GIDClientID</key>
<string>YOUR-GOOGLE-CLIENT-ID.apps.googleusercontent.com</string>

<!-- Camera Usage -->
<key>NSCameraUsageDescription</key>
<string>We need access to your camera to take photos of your pilot license.</string>

<!-- Photo Library Usage -->
<key>NSPhotoLibraryUsageDescription</key>
<string>We need access to your photo library to upload your pilot license.</string>

<!-- Location Usage -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>We need your location to show nearby drone pilot jobs.</string>
```

**Note**: Replace `YOUR-CLIENT-ID-HERE` and `YOUR-GOOGLE-CLIENT-ID` with your actual Google Client ID values. The URL scheme should be your Client ID reversed (e.g., if your Client ID is `123-abc.apps.googleusercontent.com`, the URL scheme is `com.googleusercontent.apps.123-abc`).

## Step 8: Configure Signing & Capabilities

1. In Xcode, select your project in the navigator
2. Select the Buzz target
3. Go to "Signing & Capabilities" tab
4. Select your development team
5. Add the "Sign in with Apple" capability:
   - Click "+ Capability"
   - Search for "Sign in with Apple"
   - Add it

## Step 9: Build and Run

1. Select a target device or simulator (iOS 16.0+)
2. Click the Play button or press Cmd + R
3. Wait for the build to complete
4. The app should launch on your device/simulator

## Step 10: Test the App

### Create a Pilot Account
1. Open the app
2. Tap "Sign Up"
3. Select "Pilot" as user type
4. Enter a call sign (e.g., "MAVERICK")
5. Enter email and password
6. Tap "Sign Up"
7. You should be logged in and see the pilot interface

### Upload a License
1. Go to the Profile tab
2. Tap "Manage Licenses"
3. Tap the + button
4. Choose "Take Photo" or "Choose File"
5. Select or take a photo of a test license
6. The license should appear in the list

### Create a Booking (Customer Account)
1. Sign out from the pilot account
2. Create a new customer account
3. Go to the Bookings tab
4. Tap the + button
5. Tap on the map to select a location
6. Fill in the booking details
7. Tap "Create Booking"

### Accept a Booking (Pilot Account)
1. Sign out and log back in as the pilot
2. You should see the booking in "Available Jobs"
3. Tap on the booking
4. Review the details
5. Tap "Accept Booking"
6. The booking should now appear in "My Flights"

### Complete a Booking
1. In "My Flights", tap on the accepted booking
2. Tap "Mark as Completed"
3. Your flight hours should be updated
4. Check your profile to see the updated tier

## Troubleshooting

### "Module not found" errors
- Make sure all Swift Package Dependencies are properly resolved
- Go to File → Packages → Reset Package Caches
- Clean build folder (Shift + Cmd + K) and rebuild

### Authentication errors
- Double-check your Supabase URL and key in Config.swift
- Verify authentication providers are enabled in Supabase dashboard
- For Google Sign-In, make sure the Client ID is correct in both Config.swift and Info.plist

### Database errors
- Verify the database schema was created successfully
- Check the SQL Editor for any error messages
- Ensure Row Level Security policies were created

### Google Sign-In not working
- Verify the URL scheme in Info.plist matches your reversed Client ID
- Make sure GoogleSignIn SDK is properly added
- Check that Google Sign-In is enabled in Supabase

### Apple Sign-In not working
- Verify "Sign in with Apple" capability is added to your app
- Check that Apple Sign-In is configured in Supabase
- Ensure your App ID has "Sign in with Apple" enabled in Apple Developer Portal

### Map not showing
- Make sure location permissions are added to Info.plist
- Grant location permission when prompted
- Check that MapKit is properly imported

### File upload failing
- Verify the pilot-licenses storage bucket exists in Supabase
- Check storage policies in Supabase dashboard
- Ensure camera/photo library permissions are granted

## Next Steps

1. Customize the app with your branding
2. Add more booking categories or services
3. Implement payment processing
4. Add push notifications
5. Create admin dashboard for monitoring

## Support

If you encounter any issues not covered in this guide:
1. Check the README.md for additional information
2. Review Supabase documentation at [https://supabase.com/docs](https://supabase.com/docs)
3. Check Apple's documentation for iOS development
4. Review error logs in Xcode console

## Security Reminders

- Never commit Config.swift to version control
- Keep your Supabase keys secure
- Use environment variables for production deployments
- Enable 2FA on your Supabase account
- Regularly review Row Level Security policies

