# Buzz - Drone Pilot Booking Platform

A comprehensive iOS application that connects certified drone pilots with customers who need professional drone services. Built with SwiftUI and Supabase.

## Overview

Buzz is a modern marketplace platform designed for the drone industry. It provides booking management, pilot certification tracking, ranking systems, and communication tools for both pilots and customers.

## Key Features

### For Pilots

**Authentication & Profile**
- Multiple authentication methods (Email, Phone, Google Sign-In, Apple Sign-In)
- Unique call sign creation and management
- License upload and verification (photos and PDFs)
- Profile customization with photo upload

**Booking Management**
- Browse available jobs on interactive map
- List and map views with booking details
- Accept and manage flight bookings
- Track active and completed flights
- Specialized booking categories (Real Estate, Cinematography, Inspections, etc.)

**Ranking & Recognition**
- 5-tier ranking system (Ensign → Captain)
- Automatic tier progression based on flight hours
- Real-time leaderboard with top pilots
- Flight hour tracking

**Education & Training**
- Academy with specialized training courses
- Course categories: Safety, Operations, Photography, Cinematography, etc.
- Progress tracking and enrollment management

**Revenue & Ratings**
- Track payment amounts and tips
- View revenue details and statistics
- Two-way rating system (pilot ↔ customer)
- Review management

**Communication**
- In-app messaging with customers
- Conversation management

### For Customers

**Service Booking**
- Create bookings with precise location selection
- Interactive map for location picking
- Detailed job descriptions and specifications
- Flexible scheduling with date selection
- Multiple specialization categories
- Payment amount setting

**Booking Management**
- View all active and completed bookings
- Track booking status in real-time
- Cancel or modify bookings
- View booking history and activity

**Profile & Settings**
- User profile management
- App settings and preferences
- Appearance mode (Light/Dark/System)

## Tech Stack

**Frontend**
- SwiftUI - Declarative UI framework
- Combine - Reactive programming
- MapKit - Map display and location services
- CoreLocation - Location services

**Backend**
- Supabase - Backend-as-a-Service
  - PostgreSQL - Relational database with Row Level Security
  - Supabase Auth - Authentication and session management
  - Supabase Storage - File storage
  - PostgREST - RESTful API layer

**Third-Party**
- Google Sign-In - OAuth authentication
- Apple Sign-In - Native authentication

**Architecture**
- MVVM (Model-View-ViewModel) pattern
- ObservableObject for state management
- Async/await for asynchronous operations

## Requirements

- iOS 16.0 or later
- Xcode 15.0 or later
- Swift 5.9 or later

## Quick Start

### Prerequisites
- Supabase account (sign up at https://supabase.com)
- Google Cloud Console account (for Google Sign-In)
- Apple Developer account (for Apple Sign-In)

### Setup Instructions

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd Buzz
   ```

2. **Database Setup**
   - Create a new project at Supabase
   - Run `database_schema.sql` in SQL Editor
   - Run `database_academy.sql` for Academy features (optional)

3. **Configure Authentication**
   - Enable Email, Phone, Google, and Apple providers in Supabase
   - Configure with necessary credentials

4. **Configure the App**
   - Copy `Config.example.swift` to `Buzz/Config.swift`
   - Update with your credentials:
   ```swift
   struct Config {
       static let supabaseURL = "YOUR_SUPABASE_URL"
       static let supabaseAnonKey = "YOUR_SUPABASE_ANON_KEY"
       static let googleClientID = "YOUR_GOOGLE_CLIENT_ID"
   }
   ```

5. **Add Dependencies**
   In Xcode → File → Add Package Dependencies:
   - Supabase Swift SDK: https://github.com/supabase/supabase-swift
   - Google Sign-In: https://github.com/google/GoogleSignIn-iOS

6. **Build and Run**
   - Open `Buzz.xcodeproj` in Xcode
   - Build and run (Cmd + R)

For detailed instructions, see SETUP_GUIDE.md. For a 30-minute setup, see QUICKSTART.md.

## Project Structure

```
Buzz/
├── Config.swift                    # App configuration
├── BuzzApp.swift                   # App entry point
│
├── Models/                         # Data models
│   ├── UserProfile.swift
│   ├── Booking.swift
│   ├── PilotLicense.swift
│   ├── PilotStats.swift
│   ├── Rating.swift
│   └── Message.swift
│
├── Services/                       # Business logic
│   ├── SupabaseClient.swift       # Database connection
│   ├── AuthService.swift          # Authentication
│   ├── ProfileService.swift       # Profile management
│   ├── BookingService.swift       # Booking operations
│   ├── RankingService.swift       # Ranking system
│   ├── LicenseUploadService.swift # File uploads
│   ├── AcademyService.swift       # Training courses
│   ├── RatingService.swift        # Ratings
│   ├── MessageService.swift       # Messaging
│   └── ProfilePictureService.swift # Profile images
│
├── Views/                          # UI Components
│   ├── Auth/                      # Authentication
│   ├── Welcome/                   # Onboarding
│   ├── Bookings/                  # Booking views
│   ├── Profile/                   # User profile
│   ├── License/                   # License management
│   ├── Rankings/                  # Ranking & leaderboard
│   ├── Academy/                   # Training courses
│   ├── Navigation/                # App navigation
│   └── Components/                # Reusable UI
│
└── Assets.xcassets/               # App assets
```

## Database Schema

**Core Tables**
- profiles - User information and preferences
- pilot_licenses - License documents for pilots
- bookings - Job listings and assignments
- pilot_stats - Flight hours and tier information
- ratings - Two-way rating system
- messages - In-app messaging
- training_courses - Course catalog for Academy
- course_enrollments - Pilot course enrollments

**Storage Buckets**
- pilot-licenses: License document storage
- profile-pictures: User profile images

**Security**
- Row Level Security (RLS) enabled on all tables
- Users can only access their own data
- Secure file access policies

## Ranking System

Pilots progress through 5 tiers based on total flight hours:

| Tier | Name | Flight Hours |
|------|------|--------------|
| 0 | Ensign | 0 - 24 hours |
| 1 | Sub Lieutenant | 25 - 74 hours |
| 2 | Lieutenant | 75 - 199 hours |
| 3 | Commander | 200 - 499 hours |
| 4 | Captain | 500+ hours |

Tier progression is automatic when pilots complete bookings. The leaderboard ranks all pilots by total flight hours.

## Security

- Row Level Security (RLS) - Database-level access control
- JWT Authentication - Secure session management
- OAuth 2.0 - Google and Apple Sign-In
- Secure File Storage - Encrypted bucket policies

## Known Limitations

1. Academy Courses: Currently uses hardcoded sample data. See ACADEMY_BACKEND_MIGRATION.md for backend migration.
2. Phone Authentication: Requires Twilio configuration in Supabase.
3. Push Notifications: Not yet implemented.
4. Payment Processing: External for now.
5. Offline Support: Requires network connection.

## Future Enhancements

- Push notifications for booking updates
- Real-time chat enhancements
- In-app payment processing (Stripe)
- Advanced search and filtering
- Weather API integration
- Flight path recording
- Multi-language support
- iPad optimization

## Documentation

- QUICKSTART.md - 30-minute setup guide
- SETUP_GUIDE.md - Detailed setup instructions
- ARCHITECTURE.md - Technical architecture
- DEPENDENCIES.md - Package dependencies
- PROJECT_SUMMARY.md - Feature overview
- database_schema.sql - Database schema
- database_academy.sql - Academy tables

## License

This project is for educational purposes.

## Support

For issues or questions:
1. Check the documentation files
2. Review error messages in Xcode console
3. Check Supabase logs
4. Verify configuration settings

**Current Version**: 1.0.0  
**Status**: Production-ready MVP

Built with SwiftUI and Supabase
