# Buzz App - Architecture Documentation

## Overview

Buzz is a native iOS application built with SwiftUI following the MVVM (Model-View-ViewModel) architecture pattern. The app connects to a Supabase backend for authentication, database, and file storage.

## Architecture Pattern: MVVM

```
┌─────────────────────────────────────────────────────────┐
│                         Views                            │
│  (SwiftUI Views - UI Layer)                             │
│  - AuthenticationView                                    │
│  - BookingListView                                       │
│  - ProfileView                                           │
│  - etc.                                                  │
└───────────────────┬─────────────────────────────────────┘
                    │ @StateObject/@ObservedObject
                    │ @EnvironmentObject
┌───────────────────▼─────────────────────────────────────┐
│                    ViewModels/Services                   │
│  (ObservableObject - Business Logic)                    │
│  - AuthService                                           │
│  - BookingService                                        │
│  - RankingService                                        │
│  - LicenseUploadService                                  │
└───────────────────┬─────────────────────────────────────┘
                    │ async/await
                    │ Task/Publishers
┌───────────────────▼─────────────────────────────────────┐
│                      Models                              │
│  (Data Structures)                                       │
│  - UserProfile                                           │
│  - Booking                                               │
│  - PilotStats                                            │
│  - PilotLicense                                          │
└───────────────────┬─────────────────────────────────────┘
                    │
┌───────────────────▼─────────────────────────────────────┐
│                  Supabase Client                         │
│  (Backend Integration)                                   │
│  - Authentication                                        │
│  - Database (PostgREST)                                  │
│  - Storage                                               │
└─────────────────────────────────────────────────────────┘
```

## Layer Breakdown

### 1. View Layer (SwiftUI)

**Responsibility**: Presentation and user interaction

**Components**:
- **Auth Views**: Sign in, sign up, authentication methods
- **Booking Views**: List, map, detail views for bookings
- **Profile Views**: User profile, edit profile
- **License Views**: Upload and manage licenses
- **Ranking Views**: Leaderboard, tier badges
- **Navigation**: Tab views for different user types
- **Components**: Reusable UI elements (buttons, loading, errors)

**Key Patterns**:
- Declarative UI with SwiftUI
- State management with `@State`, `@Binding`
- Dependency injection with `@EnvironmentObject`
- Navigation with `NavigationView` and `NavigationLink`

### 2. Service Layer (Business Logic)

**Responsibility**: Business logic, API communication, state management

**Services**:

#### AuthService
- User authentication (email, phone, OAuth)
- Session management
- Profile creation
- User state observation

#### BookingService
- CRUD operations for bookings
- Status updates
- Filtering and sorting
- Real-time updates (future)

#### RankingService
- Pilot statistics calculation
- Tier progression
- Leaderboard management
- Flight hour tracking

#### LicenseUploadService
- File upload to Supabase Storage
- License management
- Image compression
- File validation

#### ProfileService
- Profile CRUD operations
- Call sign validation
- Profile updates

**Key Patterns**:
- `ObservableObject` for state management
- `@Published` properties for reactive updates
- `async/await` for asynchronous operations
- Error handling and propagation

### 3. Model Layer

**Responsibility**: Data structures and domain logic

**Models**:

```swift
UserProfile
├── id: UUID
├── userType: UserType (pilot/customer)
├── callSign: String?
├── email: String?
└── phone: String?

Booking
├── id: UUID
├── customerId: UUID
├── pilotId: UUID?
├── location: (lat, lng)
├── description: String
├── paymentAmount: Decimal
├── status: BookingStatus
└── estimatedFlightHours: Double?

PilotStats
├── pilotId: UUID
├── totalFlightHours: Double
├── completedBookings: Int
└── tier: Int (0-10)

PilotLicense
├── id: UUID
├── pilotId: UUID
├── fileUrl: String
├── fileType: LicenseFileType
└── uploadedAt: Date
```

**Key Patterns**:
- `Codable` for JSON serialization
- `Identifiable` for SwiftUI lists
- Computed properties for derived data
- Type-safe enums for status values

### 4. Integration Layer

**SupabaseClient**: Singleton managing Supabase connection

```swift
SupabaseClient.shared.client
├── auth      → Authentication
├── from()    → Database queries
└── storage   → File storage
```

## Data Flow

### Authentication Flow

```
User Input → AuthenticationView
           ↓
       AuthService.signIn()
           ↓
       Supabase Auth API
           ↓
       AuthService updates @Published properties
           ↓
       View updates automatically
           ↓
       Navigate to MainTabView
```

### Booking Creation Flow (Customer)

```
User selects location on map
           ↓
Fills in booking details
           ↓
Taps "Create Booking"
           ↓
BookingService.createBooking()
           ↓
Insert into Supabase database
           ↓
RLS policies verify customer_id
           ↓
Booking appears in customer's list
           ↓
Available to pilots
```

### Booking Acceptance Flow (Pilot)

```
Pilot browses available bookings
           ↓
Taps on booking → BookingDetailView
           ↓
Taps "Accept Booking"
           ↓
BookingService.acceptBooking()
           ↓
Update booking with pilot_id
           ↓
Status changes to "accepted"
           ↓
Booking moves to pilot's "My Flights"
```

### Booking Completion Flow

```
Pilot completes job
           ↓
Taps "Mark as Completed"
           ↓
BookingService.completeBooking()
           ↓
Status → "completed"
           ↓
RankingService.updateFlightHours()
           ↓
Add estimated hours to pilot stats
           ↓
Recalculate tier
           ↓
Update pilot_stats table
           ↓
Profile and leaderboard update
```

## State Management

### Global State (AuthService)
```swift
@StateObject var authService = AuthService()
```
- Shared across entire app
- Injected via `.environmentObject()`
- Manages authentication state
- Accessible in all child views

### Local State (View-Specific Services)
```swift
@StateObject private var bookingService = BookingService()
```
- Owned by specific view
- Lifecycle tied to view
- Not shared between views

### Derived State
```swift
@State private var filteredBookings: [Booking]
```
- Computed from other state
- View-local
- Recalculated on dependency changes

## Security Architecture

### Row Level Security (RLS)

Supabase enforces security at the database level:

```sql
-- Pilots can only view available bookings or their own
CREATE POLICY "pilot_booking_access" ON bookings
  FOR SELECT USING (
    status = 'available' 
    OR auth.uid() = pilot_id
  );

-- Users can only modify their own data
CREATE POLICY "own_profile_update" ON profiles
  FOR UPDATE USING (auth.uid() = id);
```

### Authentication Security

- JWT tokens managed by Supabase
- Tokens auto-refresh
- Secure storage in iOS keychain (handled by Supabase SDK)
- OAuth handled by providers (Google, Apple)

### Storage Security

```sql
-- Pilots can only access their own license files
CREATE POLICY "pilot_license_access" ON storage.objects
  USING (
    bucket_id = 'pilot-licenses'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );
```

## Navigation Structure

### Pilot Interface
```
TabView
├── Jobs (PilotBookingListView)
│   ├── Map View
│   └── Booking Detail
├── My Flights (MyFlightsView)
│   ├── Active
│   └── Completed
├── Rankings (LeaderboardView)
└── Profile (ProfileView)
    └── License Management
```

### Customer Interface
```
TabView
├── Bookings (CustomerBookingView)
│   ├── Create Booking
│   └── Booking Detail
└── Profile (ProfileView)
```

## Error Handling Strategy

### Layered Error Handling

1. **Service Layer**: Catch and transform errors
   ```swift
   do {
       try await supabase.from("bookings").insert(data)
   } catch {
       errorMessage = error.localizedDescription
       throw error
   }
   ```

2. **View Layer**: Display errors to user
   ```swift
   .alert("Error", isPresented: $showError) {
       Text(errorMessage)
   }
   ```

3. **User Feedback**: Loading states, error views
   ```swift
   if isLoading { LoadingView() }
   else if error { ErrorView() }
   else { ContentView() }
   ```

## Performance Considerations

### Optimization Strategies

1. **Lazy Loading**: Lists load data on-demand
2. **Image Compression**: Reduce file sizes before upload
3. **Caching**: Supabase SDK handles response caching
4. **Pagination**: Future enhancement for large datasets
5. **Background Processing**: File uploads use async tasks

### Memory Management

- SwiftUI handles view lifecycle
- `@StateObject` ensures single instance
- Services cleaned up with view deallocation
- Large images compressed before storage

## Testing Strategy

### Unit Tests (Future)
- Test business logic in services
- Mock Supabase client
- Test tier calculation
- Test validation logic

### Integration Tests (Future)
- Test API communication
- Test database operations
- Test authentication flows

### UI Tests (Future)
- Test user flows
- Test navigation
- Test form validation

## Scalability Considerations

### Current Architecture Supports:

- **Horizontal Scaling**: Supabase handles database scaling
- **Feature Addition**: New services easily added
- **User Growth**: RLS ensures efficient queries
- **Data Growth**: Indexed columns for performance

### Future Enhancements:

1. **Caching Layer**: Add local database (CoreData/Realm)
2. **Offline Support**: Queue operations when offline
3. **Push Notifications**: Real-time booking updates
4. **Analytics**: Track user behavior and app performance
5. **A/B Testing**: Experiment with UI variations

## Technology Stack Summary

| Layer | Technology | Purpose |
|-------|-----------|---------|
| UI | SwiftUI | Declarative interface |
| State | Combine | Reactive programming |
| Backend | Supabase | BaaS platform |
| Database | PostgreSQL | Relational database |
| Storage | Supabase Storage | File storage |
| Auth | Supabase Auth | User authentication |
| Maps | MapKit | Location services |
| Language | Swift 5.9+ | iOS development |

## Design Patterns Used

1. **MVVM**: Separation of concerns
2. **Singleton**: SupabaseClient shared instance
3. **Dependency Injection**: EnvironmentObject
4. **Repository Pattern**: Services abstract data access
5. **Observer Pattern**: Combine/ObservableObject
6. **Factory Pattern**: Tier calculation
7. **Strategy Pattern**: Multiple auth methods

## Conclusion

The Buzz app architecture is designed for:
- ✅ Maintainability through separation of concerns
- ✅ Scalability through modular design
- ✅ Security through RLS and proper authentication
- ✅ Testability through dependency injection
- ✅ Performance through efficient data handling

This architecture provides a solid foundation for future enhancements while maintaining code quality and user experience.

