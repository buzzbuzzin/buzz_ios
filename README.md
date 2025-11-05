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

**Cockpit Dashboard**
- Centralized dashboard for pilot operations
- Weather monitoring for current location and upcoming bookings
- Real-time weather data with wind speed, direction, and flying conditions
- Transponder management for drone registration and tracking
- Flight Radar with real-time drone location tracking on map
- Safety notifications for nearby active drones
- Availability calendar view for scheduling
- Progress tracking with rank progression requirements
- Revenue analytics with monthly breakdowns and charts
- Industry news feed

**Drone Management**
- Register and manage multiple drones with Remote ID
- Real-time location tracking for registered drones
- Transponder system for compliance and safety
- Flight radar visualization showing active drones
- Nearby drone detection (within 1 km radius)

**Analytics & Insights**
- Revenue tracking with base pay and tips breakdown
- Monthly revenue charts and statistics
- Booking completion metrics
- Progress tracking toward next rank tier
- Penalty tracking (no-shows, late arrivals)

**Badges & Certifications**
- Course completion badges
- Badge expiration tracking
- Recurrent training reminders
- Multi-provider badge support (Buzz, Amazon, T-Mobile, etc.)

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
- Charts - Data visualization (revenue charts)

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
│   ├── Message.swift
│   ├── Weather.swift
│   ├── Transponder.swift
│   ├── Badge.swift
│   └── TrainingCourse.swift
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
│   ├── ProfilePictureService.swift # Profile images
│   ├── WeatherService.swift       # Weather data
│   ├── TransponderService.swift   # Drone transponder management
│   ├── BadgeService.swift         # Badge management
│   └── LocationHelper.swift       # Location utilities
│
├── Views/                          # UI Components
│   ├── Auth/                      # Authentication
│   ├── Welcome/                   # Onboarding
│   ├── Bookings/                  # Booking views
│   ├── Profile/                   # User profile
│   ├── License/                   # License management
│   ├── Rankings/                  # Ranking & leaderboard
│   ├── Academy/                   # Training courses
│   ├── Cockpit/                   # Cockpit dashboard
│   │   ├── CockpitView.swift      # Main dashboard
│   │   ├── WeatherView.swift      # Weather information
│   │   ├── TransponderView.swift  # Drone management
│   │   └── FlightRadarView.swift  # Real-time drone tracking
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
- transponders - Drone transponder information and location tracking
- badges - Course completion badges and certifications

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
6. Weather Data: Uses demo/fallback data if API is unavailable (fallback to Ithaca, NY).
7. Flight Radar: Shows all active transponders but requires location permissions for nearby detection.

## Git Flow Branch Conventions

This project follows the **Git Flow** branching model for organized development and release management. We use [git-flow-next](https://git-flow.sh/) - a modern implementation of the git-flow branching model that provides Git extensions for high-level repository operations.

**Prerequisites:** Install git-flow-next before using these commands:
```bash
# macOS (using Homebrew)
brew install git-flow-avh

# Or install git-flow-next (modern Go implementation)
# See https://git-flow.sh/ for installation instructions
# git-flow-next is compatible with git-flow-avh and automatically detects existing configurations
```

### Branch Types

**Main Branches**

- **`main`** - Production branch
  - Contains stable, production-ready code
  - Protected branch (requires pull request and approval for changes)
  - Only merged from `develop` or `release/*` branches
  - Each merge should be tagged with a version number

- **`develop`** - Development branch
  - Integration branch for completed features
  - Always contains the latest delivered development changes
  - Used as the base branch for feature branches
  - Merged into `main` when preparing a release

**Supporting Branches**

- **`feature/*`** - Feature development branches
  - Created from: `develop`
  - Merged back into: `develop`
  - Naming convention: `feature/feature-name` (e.g., `feature/cockpit`, `feature/weather-integration`)
  - Used for developing new features
  - Deleted after merging

- **`release/*`** - Release preparation branches
  - Created from: `develop`
  - Merged into: `main` and `develop`
  - Naming convention: `release/version-number` (e.g., `release/1.1.0`)
  - Used for preparing a new production release
  - Bug fixes for the release can be done directly on this branch
  - Deleted after merging

- **`hotfix/*`** - Hotfix branches
  - Created from: `main`
  - Merged into: `main` and `develop`
  - Naming convention: `hotfix/issue-description` (e.g., `hotfix/auth-bug`)
  - Used for critical bug fixes in production
  - Allows immediate fixes without waiting for the next release cycle
  - Deleted after merging

### Initial Setup

**Initialize git-flow in your repository:**
```bash
# Initialize with Classic GitFlow preset (recommended)
git flow init --preset=classic --defaults

# Or initialize interactively to customize branch names
git flow init
```

This sets up the branch structure and configuration needed for git-flow operations. You'll be prompted to configure branch names (or use defaults).

### Workflow Examples

1. **Starting a new feature:**
   ```bash
   # Start a new feature branch (automatically created from develop)
   git flow feature start new-feature-name
   
   # Or fetch latest changes before starting
   git flow feature start new-feature-name --fetch
   ```

2. **Working on a feature:**
   ```bash
   # Update feature branch with latest changes from develop
   git flow feature update new-feature-name
   
   # Or use shorthand if you're on the feature branch
   git flow update
   ```

3. **Completing a feature:**
   ```bash
   # Finish the feature (merges to develop and deletes the branch)
   git flow feature finish new-feature-name
   
   # Or use shorthand if you're on the feature branch
   git flow finish
   
   # Keep the branch after finishing (useful for reference)
   git flow feature finish new-feature-name --keep
   ```

4. **Starting a release:**
   ```bash
   # Start a release branch (automatically created from develop)
   git flow release start 1.2.0
   
   # Make release-related changes, update version numbers, etc.
   # Then finish the release
   git flow release finish 1.2.0
   ```

5. **Hotfix process:**
   ```bash
   # Start a hotfix branch (automatically created from main)
   git flow hotfix start critical-bug
   
   # Fix the bug, commit changes
   # Then finish the hotfix (merges to both main and develop)
   git flow hotfix finish critical-bug
   ```

6. **Other useful commands:**
   ```bash
   # List all feature branches
   git flow feature list
   
   # List all release branches
   git flow release list
   
   # Checkout an existing feature branch
   git flow feature checkout feature-name
   
   # Delete a feature branch
   git flow feature delete old-feature-name
   
   # Rename a feature branch
   git flow feature rename old-name new-name
   
   # View repository workflow overview
   git flow overview
   ```

For more details on git-flow commands, see the [official documentation](https://git-flow.sh/docs/commands/).

### Branch Protection Rules

- `main` branch requires:
  - Pull request reviews (at least 1 approval)
  - Status checks to pass
  - No force pushes
  - No deletions

- `develop` branch requires:
  - Pull request reviews (at least 1 approval)
  - Status checks to pass

## Future Enhancements

- Push notifications for booking updates
- Real-time chat enhancements
- In-app payment processing (Stripe)
- Advanced search and filtering
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
