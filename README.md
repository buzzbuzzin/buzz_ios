# Buzz - Drone Pilot Booking App

A comprehensive iOS application connecting drone pilots with customers who need drone services. Built with SwiftUI and Supabase.

## Features

### For Pilots
- Multi-method authentication (Email, Phone, Google Sign-In, Apple Sign-In)
- Create unique call signs
- Upload and manage drone pilot licenses (photos and PDFs)
- Browse available bookings on a map
- Accept and complete bookings
- Track flight hours and rankings
- Tier-based ranking system (Tier 0-10)
- View leaderboard of top pilots

### For Customers
- Multi-method authentication
- Create drone service bookings
- Set location, description, and payment amount
- Track booking status
- Manage active and completed bookings

## Tech Stack

- **Frontend**: SwiftUI (iOS 16+)
- **Backend**: Supabase
  - Authentication (Email, Phone, OAuth)
  - PostgreSQL Database
  - Storage (for license uploads)
- **Map Integration**: MapKit
- **Dependencies**:
  - Supabase Swift SDK
  - GoogleSignIn SDK

## Prerequisites

- Xcode 15.0 or later
- iOS 16.0 or later
- Supabase account
- Google Cloud Console account (for Google Sign-In)
- Apple Developer account (for Apple Sign-In)

## Setup Instructions

### 1. Supabase Setup

1. Create a new project at [Supabase](https://supabase.com)
2. Navigate to SQL Editor in your Supabase dashboard
3. Run the SQL script from `database_schema.sql` to create all tables and policies
4. Enable authentication providers:
   - Go to Authentication → Providers
   - Enable Email, Phone, Google, and Apple providers
   - Configure each provider with necessary credentials

### 2. Google Sign-In Setup

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Create a new project or select an existing one
3. Enable Google Sign-In API
4. Create OAuth 2.0 credentials
5. Add your iOS Bundle ID
6. Download the configuration and note your Client ID

### 3. Apple Sign-In Setup

1. Go to [Apple Developer Portal](https://developer.apple.com)
2. Add "Sign in with Apple" capability to your app identifier
3. Enable Sign in with Apple in your Supabase project settings

### 4. Configure the App

1. Clone the repository
2. Open `Buzz.xcodeproj` in Xcode
3. Update `Buzz/Config.swift` with your credentials:

```swift
struct Config {
    static let supabaseURL = "YOUR_SUPABASE_URL"
    static let supabaseAnonKey = "YOUR_SUPABASE_ANON_KEY"
    static let googleClientID = "YOUR_GOOGLE_CLIENT_ID"
}
```

### 5. Add Swift Package Dependencies

Add the following packages in Xcode (File → Add Package Dependencies):

1. **Supabase Swift SDK**
   - URL: `https://github.com/supabase/supabase-swift`
   - Version: Latest

2. **Google Sign-In**
   - URL: `https://github.com/google/GoogleSignIn-iOS`
   - Version: Latest

### 6. Configure Info.plist

Add the following to your `Info.plist`:

```xml
<!-- Google Sign-In URL Scheme -->
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>YOUR_REVERSED_CLIENT_ID</string>
        </array>
    </dict>
</array>

<!-- Google Client ID -->
<key>GIDClientID</key>
<string>YOUR_GOOGLE_CLIENT_ID</string>

<!-- Camera and Photo Library Usage -->
<key>NSCameraUsageDescription</key>
<string>We need access to your camera to take photos of your pilot license.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>We need access to your photo library to upload your pilot license.</string>

<!-- Location -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>We need your location to show nearby drone pilot jobs.</string>
```

### 7. Build and Run

1. Select your target device or simulator
2. Build and run the app (Cmd + R)

## Project Structure

```
Buzz/
├── Models/
│   ├── UserProfile.swift
│   ├── Booking.swift
│   ├── PilotLicense.swift
│   └── PilotStats.swift
├── Services/
│   ├── SupabaseClient.swift
│   ├── AuthService.swift
│   ├── ProfileService.swift
│   ├── BookingService.swift
│   ├── RankingService.swift
│   └── LicenseUploadService.swift
├── Views/
│   ├── Auth/
│   │   ├── AuthenticationView.swift
│   │   └── SignUpView.swift
│   ├── Bookings/
│   │   ├── BookingMapView.swift
│   │   ├── PilotBookingListView.swift
│   │   ├── BookingDetailView.swift
│   │   └── CustomerBookingView.swift
│   ├── License/
│   │   └── LicenseManagementView.swift
│   ├── Profile/
│   │   └── ProfileView.swift
│   ├── Rankings/
│   │   ├── RankingBadgeView.swift
│   │   └── LeaderboardView.swift
│   ├── Navigation/
│   │   └── MainTabView.swift
│   └── Components/
│       ├── CustomButton.swift
│       ├── LoadingView.swift
│       ├── ErrorView.swift
│       └── EmptyStateView.swift
├── Config.swift
└── BuzzApp.swift
```

## Database Schema

### Tables

- **profiles**: User profiles with user type (pilot/customer) and call signs
- **pilot_licenses**: Uploaded license files for pilots
- **bookings**: Drone service bookings with location, status, and payment info
- **pilot_stats**: Pilot statistics including flight hours, completed bookings, and tier

### Storage Buckets

- **pilot-licenses**: Stores uploaded pilot license files (photos and PDFs)

## Ranking System

Pilots are ranked into tiers (0-10) based on their total flight hours:

- **Tier 0 (Novice)**: 0-10 hours
- **Tier 1 (Apprentice)**: 10-25 hours
- **Tier 2 (Intermediate)**: 25-50 hours
- **Tier 3 (Skilled)**: 50-100 hours
- **Tier 4 (Advanced)**: 100-200 hours
- **Tier 5 (Expert)**: 200-350 hours
- **Tier 6 (Master)**: 350-550 hours
- **Tier 7 (Elite)**: 550-800 hours
- **Tier 8 (Legend)**: 800-1100 hours
- **Tier 9 (Supreme)**: 1100-1500 hours
- **Tier 10 (Grand Master)**: 1500+ hours

## Security

- Row Level Security (RLS) enabled on all tables
- Users can only view and modify their own data
- Pilots can only accept available bookings
- Storage policies ensure users can only access their own files

## Troubleshooting

### Build Errors
- Make sure all Swift Package Dependencies are properly resolved
- Clean build folder (Shift + Cmd + K) and rebuild

### Authentication Issues
- Verify Supabase credentials in Config.swift
- Check that authentication providers are enabled in Supabase dashboard
- For Google Sign-In, ensure the Client ID and reversed Client ID are correct

### Database Errors
- Verify that the database schema has been properly created
- Check Row Level Security policies in Supabase dashboard

## Future Enhancements

- Push notifications for booking updates
- Real-time chat between pilots and customers
- In-app payment processing
- Pilot reviews and ratings
- Advanced search and filtering
- Booking history and analytics
- Weather integration for flight planning

## License

This project is for educational purposes.

## Support

For issues and questions, please check the documentation or contact support.

