# Buzz App - Quick Start Guide

Get up and running with the Buzz drone pilot booking app in under 30 minutes!

## Prerequisites Checklist

- [ ] Xcode 15+ installed
- [ ] Supabase account created
- [ ] Google Cloud Console account (for Google Sign-In)
- [ ] Apple Developer account

## 5-Step Quick Setup

### Step 1: Database Setup (5 minutes)

1. Create a new Supabase project at https://supabase.com
2. Go to SQL Editor → New Query
3. Copy and run the entire `database_schema.sql` file
4. Verify tables created: profiles, bookings, pilot_licenses, pilot_stats

### Step 2: Configure Authentication (5 minutes)

In Supabase Dashboard → Authentication → Providers:

- ✅ Email (enabled by default)
- ✅ Phone (optional for MVP, configure Twilio)
- ✅ Google (add your Client ID)
- ✅ Apple (enable in Supabase)

### Step 3: App Configuration (5 minutes)

1. Copy `Config.example.swift` → `Config.swift`
2. Update with your credentials from Supabase Settings → API:

```swift
static let supabaseURL = "https://YOUR-PROJECT.supabase.co"
static let supabaseAnonKey = "YOUR-ANON-KEY"
static let googleClientID = "YOUR-CLIENT-ID.apps.googleusercontent.com"
```

### Step 4: Add Dependencies (10 minutes)

In Xcode → File → Add Package Dependencies:

1. **Supabase**: `https://github.com/supabase/supabase-swift`
2. **Google Sign-In**: `https://github.com/google/GoogleSignIn-iOS`

Select all modules and add to your target.

### Step 5: Update Info.plist (5 minutes)

Add these keys to `Info.plist`:

```xml
<!-- Google Sign-In URL Scheme -->
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.googleusercontent.apps.YOUR-CLIENT-ID</string>
        </array>
    </dict>
</array>

<!-- Permissions -->
<key>NSCameraUsageDescription</key>
<string>Take photos of your pilot license</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Upload your pilot license</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>Show nearby jobs</string>
```

## Build and Run! 🚀

1. Select a simulator (iOS 16+)
2. Press Cmd + R
3. Create an account and start testing!

## First Test: Complete User Flow

### As a Pilot:

1. **Sign Up**
   - Tap "Sign Up" → Select "Pilot"
   - Enter call sign: "MAVERICK"
   - Enter email/password → Sign Up

2. **Upload License**
   - Profile → Manage Licenses → +
   - Take a test photo → Upload

3. **Browse Jobs**
   - Jobs tab → View available bookings
   - Tap Map icon to see location view

### As a Customer:

1. **Create Account**
   - Sign Out → Sign Up
   - Select "Customer" → Complete signup

2. **Create Booking**
   - Bookings tab → + button
   - Tap map to select location
   - Fill details: description, amount ($100), hours (2.5)
   - Create Booking

3. **View Status**
   - See booking in your list
   - Check when pilot accepts

### Back to Pilot:

1. **Accept Job**
   - Jobs tab → Tap the new booking
   - Review details → Accept Booking

2. **Complete Job**
   - My Flights → Tap accepted booking
   - Mark as Completed
   - Check Profile → Stats updated!

## Common First-Run Issues

### "Cannot connect to Supabase"
- ✅ Check supabaseURL in Config.swift
- ✅ Verify internet connection
- ✅ Confirm Supabase project is active

### "Google Sign-In failed"
- ✅ Verify Client ID in Config.swift and Info.plist
- ✅ URL scheme must be reversed Client ID
- ✅ Check GoogleSignIn package is installed

### "Database error"
- ✅ Run database_schema.sql completely
- ✅ Check Row Level Security policies exist
- ✅ Verify storage bucket "pilot-licenses" created

### Build errors
- ✅ Clean Build Folder (Shift + Cmd + K)
- ✅ Reset Package Caches (File → Packages)
- ✅ Rebuild (Cmd + B)

## Key Features to Test

- ✅ Email sign-up and login
- ✅ Phone authentication (if configured)
- ✅ Google Sign-In
- ✅ Apple Sign-In
- ✅ Pilot call sign uniqueness
- ✅ License upload (photo & PDF)
- ✅ Map-based location selection
- ✅ Booking creation
- ✅ Booking acceptance
- ✅ Booking completion
- ✅ Flight hours tracking
- ✅ Tier system updates
- ✅ Leaderboard rankings

## Project Structure Overview

```
Buzz/
├── Models/          → Data structures
├── Services/        → Business logic & API
├── Views/
│   ├── Auth/        → Login & signup
│   ├── Bookings/    → Job listings & maps
│   ├── License/     → License management
│   ├── Profile/     → User profile
│   ├── Rankings/    → Leaderboard & tiers
│   ├── Navigation/  → Tab navigation
│   └── Components/  → Reusable UI
├── Config.swift     → API credentials (DO NOT COMMIT)
└── BuzzApp.swift    → App entry point
```

## Development Tips

### Testing Authentication
- Use disposable email services for testing multiple accounts
- Test with different user types (pilot vs customer)
- Verify call sign uniqueness enforcement

### Testing Bookings
- Create multiple bookings with different locations
- Test booking lifecycle: create → accept → complete
- Verify flight hours calculation

### Testing Rankings
- Create bookings with varying flight hours
- Complete bookings to see tier progression
- Check leaderboard updates

### Debugging
- Enable Xcode console for error messages
- Check Supabase dashboard logs
- Use Xcode's View Hierarchy debugger for UI issues

## Next Steps

1. **Customize Branding**
   - Update app icon in Assets.xcassets
   - Modify color scheme
   - Add custom fonts

2. **Add Features**
   - Push notifications
   - In-app chat
   - Payment integration
   - Reviews and ratings

3. **Deployment**
   - Set up TestFlight
   - Prepare App Store assets
   - Review Apple guidelines

## Useful Commands

```bash
# Clean derived data
rm -rf ~/Library/Developer/Xcode/DerivedData

# Reset git (if needed)
git clean -fdx
git reset --hard HEAD

# View Xcode logs
tail -f ~/Library/Logs/CoreSimulator/*/system.log
```

## Resources

- 📖 [Full Setup Guide](SETUP_GUIDE.md)
- 📦 [Dependencies](DEPENDENCIES.md)
- 🗄️ [Database Schema](database_schema.sql)
- 🏗️ [Main README](README.md)

## Getting Help

1. Check error messages in Xcode console
2. Review SETUP_GUIDE.md for detailed instructions
3. Verify Supabase dashboard for backend issues
4. Check package dependencies are resolved

## Success Checklist

By the end of quick start, you should have:

- ✅ Working authentication (at least email)
- ✅ Pilot and customer user types
- ✅ Ability to create bookings
- ✅ Ability to accept bookings
- ✅ Map integration working
- ✅ License upload functional
- ✅ Tier system calculating correctly
- ✅ Leaderboard displaying

Congratulations! You're ready to start customizing Buzz! 🎉

