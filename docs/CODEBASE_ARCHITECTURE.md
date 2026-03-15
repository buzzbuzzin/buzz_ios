# Buzz iOS Application - Codebase Architecture Document

> **Last Updated:** 2026-03-15
> **Platform:** iOS (SwiftUI)
> **Backend:** Supabase (PostgreSQL + Edge Functions + Storage + Realtime)
> **Total Swift Files:** ~344 (50 Models, 80+ Services, 176 Views)

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Directory Structure](#2-directory-structure)
3. [Architecture Patterns](#3-architecture-patterns)
4. [App Lifecycle & Entry Point](#4-app-lifecycle--entry-point)
5. [Navigation Architecture](#5-navigation-architecture)
6. [Models Layer](#6-models-layer)
7. [Services Layer](#7-services-layer)
8. [Views Layer](#8-views-layer)
9. [Supabase Backend](#9-supabase-backend)
10. [Edge Functions](#10-edge-functions)
11. [Database Schema](#11-database-schema)
12. [Row Level Security](#12-row-level-security)
13. [Database Functions & Triggers](#13-database-functions--triggers)
14. [Storage Buckets](#14-storage-buckets)
15. [Third-Party Integrations](#15-third-party-integrations)
16. [Business Logic & Workflows](#16-business-logic--workflows)
17. [Shared Components & Utilities](#17-shared-components--utilities)
18. [Testing Infrastructure](#18-testing-infrastructure)
19. [Configuration & Environment](#19-configuration--environment)

---

## 1. Project Overview

Buzz is an enterprise-scale iOS application for the drone services industry. It serves two user types:

- **Pilots:** Accept missions, manage flight operations, log hours, earn certifications, participate in social features, sell equipment
- **Customers:** Book drone services across 10 specializations, manage missions, communicate with pilots

### Key Feature Areas

| Feature | Description |
|---------|-------------|
| **Mission Booking** | Multi-step booking with 10 specializations (automotive, real estate, S&R, etc.) |
| **Cockpit** | Flight operations hub with weather, checklists, flight logs, plans |
| **HangerTalk** | Social feed with posts, replies, reposts, likes, bookmarks, @mentions |
| **Hanger Spaces** | Live audio rooms powered by LiveKit |
| **Academy** | Training courses, slide presentations, proctored exams, certifications |
| **Hanger Help** | Community Q&A forum with topics, posts, comments |
| **Marketplace** | Peer-to-peer equipment marketplace with offers, transactions, reviews |
| **Beacon** | Search & Rescue volunteer program with training requirements |
| **Leaderboard** | Pilot rankings by tier (Ensign to Captain) |
| **Shop** | Shopify-powered merchandise store |

---

## 2. Directory Structure

```
Buzz/                                  # Root project directory
├── Buzz/                              # Main iOS app source
│   ├── BuzzApp.swift                  # @main entry point
│   ├── Config.swift                   # API keys, URLs, feature flags
│   ├── Config/
│   │   └── ProductIdentifiers.swift   # StoreKit product IDs
│   ├── Models/                        # 50 model files (most Codable; some Identifiable-only)
│   ├── Services/                      # 80+ service classes
│   ├── Views/                         # 180+ SwiftUI views
│   │   ├── Navigation/               # MainTabView (root dispatcher)
│   │   ├── Auth/                     # Authentication flows
│   │   ├── Welcome/                  # Splash screen
│   │   ├── Cockpit/                  # Flight operations (61 files)
│   │   ├── Bookings/                 # Mission management (18 files)
│   │   ├── Academy/                  # Training platform (28 files)
│   │   ├── Profile/                  # User account (44 files)
│   │   ├── Rankings/                 # Leaderboard (2 files)
│   │   ├── License/                  # Credentials (2 files)
│   │   ├── Shared/                   # Reusable utilities (4 files)
│   │   └── Components/              # Generic UI components (9 files)
│   ├── ViewModels/
│   │   └── SlideshowViewModel.swift
│   ├── Utilities/
│   │   ├── MentionParser.swift
│   │   └── CallSignValidator.swift
│   ├── Helpers/
│   │   └── StoreKitExtensions.swift
│   ├── Assets.xcassets/              # Images, colors, icons
│   └── Info.plist                    # Permissions, background modes
│
├── Buzz.xcodeproj/                   # Xcode project configuration
├── BuzzTests/                        # Unit tests (54 flat files, Swift Testing framework)
├── BuzzUITests/                      # UI tests (stub)
├── supabase/                         # Backend infrastructure
│   ├── config.toml                   # Supabase local config
│   ├── migrations/                   # 113+ SQL migration files
│   └── functions/                    # 51 Deno edge functions
├── docs/                             # Documentation
├── Config.swift                      # Root-level config
├── backend_scheme.sql                # Database schema reference
└── atis_api_docs.json                # ATIS API documentation
```

---

## 3. Architecture Patterns

### Service Pattern

All services follow a consistent `@MainActor ObservableObject` pattern:

```swift
@MainActor
class SomeService: ObservableObject {
    @Published var data: [Type] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let supabase = SupabaseClient.shared.client

    func fetchData() async {
        // 1. Demo mode check
        if DemoModeManager.shared.isDemoModeEnabled {
            self.data = Self.demoData
            return
        }

        // 2. Set loading state
        isLoading = true
        defer { isLoading = false }

        // 3. Supabase query
        do {
            let response: [Type] = try await supabase
                .from("table_name")
                .select("*, related_table(columns)")
                .eq("field", value: value)
                .order("created_at", ascending: false)
                .execute()
                .value
            self.data = response
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
}
```

### Model Pattern

Most models use `Codable` with `CodingKeys` for snake_case mapping. Notable exceptions: `TrainingCourse` and `CompletedUnit` conform only to `Identifiable` (constructed programmatically in `AcademyService`).

Each major model typically has three companion structs:
- `*Insert` — stripped of server-generated fields, used for Supabase POST operations
- `*Response` — includes joined `HangerAuthorProfileOrArray` for Supabase join queries
- `*WithAuthor` / `*WithSeller` — display struct with resolved profile data

```swift
struct Model: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let displayName: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case displayName = "display_name"
        case createdAt = "created_at"
    }
}

// Separate structs for Supabase join responses
struct ModelResponse: Codable {
    let id: UUID
    let profiles: HangerAuthorProfileOrArray?
}

// Display struct with resolved joins
struct ModelWithAuthor {
    let id: UUID
    let authorName: String
    let authorAvatar: String?
}
```

### View Pattern

```swift
struct SomeView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var service = SomeService()
    @State private var showModal = false
    @State private var navigateToId: UUID?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Main content (ScrollView/List)
            ScrollView { ... }

            // Floating action button
            Button { showModal = true } label: {
                Image(systemName: "plus")
            }
            .padding(.trailing, 20)
            .padding(.bottom, 20)
        }
        .sheet(isPresented: $showModal) {
            ComposeView()
        }
        .task { await service.fetchData() }
        .refreshable { await service.fetchData() }
    }
}
```

### Singleton Managers

| Manager | Pattern | Access |
|---------|---------|--------|
| `SupabaseClient` | `static let shared` | `SupabaseClient.shared.client` |
| `DemoModeManager` | `@MainActor` Singleton | `DemoModeManager.shared.isDemoModeEnabled` |
| `DeepLinkManager` | `@MainActor` Singleton | `DeepLinkManager.shared.pendingDestination` |
| `NotificationManager` | `@MainActor` Singleton + NSObject | `NotificationManager.shared` |
| `LocationTrackingService` | `@MainActor` Singleton + NSObject | `LocationTrackingService.shared` |
| `EntitlementManager` | `@MainActor` Singleton (defined inside `StoreKitManager.swift`) | `EntitlementManager.shared` |
| `BookingConfigService` | `@MainActor` Singleton | `BookingConfigService.shared` |

### State Management in Views

| Wrapper | Usage |
|---------|-------|
| `@StateObject` | Locally-owned services created by the view |
| `@EnvironmentObject` | AuthService passed down from root |
| `@ObservedObject` | Shared services passed via init |
| `@State` | Local UI state (booleans, selections, optional IDs for navigation) |
| `@Binding` | Parent-child state sharing |
| `@AppStorage` | Persisted preferences (appearance mode, etc.) |

### Supabase Join Handling

For Supabase queries that join related tables, a custom `HangerAuthorProfileOrArray` enum handles the ambiguity of single vs. array profile responses:

```swift
enum HangerAuthorProfileOrArray: Codable {
    case single(HangerAuthorProfile)
    case array([HangerAuthorProfile])

    init(from decoder: Decoder) throws {
        // Note: array is attempted FIRST, then falls back to single
        if let array = try? [HangerAuthorProfile](from: decoder) {
            self = .array(array)
        } else {
            self = .single(try HangerAuthorProfile(from: decoder))
        }
    }
}
```

A parallel enum `HangerTopicInfoOrArray` follows the same pattern for `hanger_topics` joins.

---

## 4. App Lifecycle & Entry Point

**File:** `Buzz/BuzzApp.swift`

```
@main struct BuzzApp: App
```

### Initialization
- `AppDelegate` registered for APNs and background tasks
- Google Sign-In configuration
- Stripe SDK configuration
- Demo mode setup (`UITEST_MODE` environment variable)
- NWS alert background task registration (`BGTaskScheduler`)

### State Objects (Root Level)
- `@StateObject authService: AuthService`
- `@StateObject notificationManager: NotificationManager`
- `@StateObject locationTrackingService: LocationTrackingService`
- `@StateObject updateService: AppUpdateService`
- `@AppStorage appearanceMode` for dark/light mode

### App Launch Flow

```
LaunchScreenView (hasResolvedInitialSession == false)
        │
        ├── if isAuthenticated && !shouldDelayNavigation
        │   └── MainTabView
        │
        ├── else
        │   └── WelcomeView → AuthenticationView
        │
        └── Overlays: UpdatePopupView, EmergencyFlashOverlay
```

### `.onAppear` Actions
1. Restore Google Sign-In session
2. Request notification permissions
3. Register for APNs
4. Sync device token to database
5. Update user location
6. Track app version
7. Check for app updates
8. Schedule background NWS alert checks

### `.onOpenURL` Handler
- Google Sign-In redirect only (`GIDSignIn.sharedInstance.handle(url)`)
- Note: Deep links are dispatched from `NotificationManager` tap callbacks, not from URL scheme opens

### Background Task
- `BGAppRefreshTask` with identifier `com.buzz.app.ios.nws-alert-check`
- Periodically checks for NWS weather alerts

---

## 5. Navigation Architecture

### Tab-Based Navigation

**MainTabView** dispatches to `PilotTabView` or `CustomerTabView` based on `authService.userProfile?.userType`.

#### Pilot Tabs (5 tabs)
| Tab | Label | View | Purpose |
|-----|-------|------|---------|
| 0 | "Missions" | `PilotBookingListView` | Browse available missions |
| 1 | "My Flights" | `MyFlightsView` (defined inside `MainTabView.swift`) | Flight history with `MyFlightsBookingCard` and `CompletedBookingCard` sub-views |
| 2 | "Cockpit" | `CockpitView` | Operations hub (weather, social, tools) |
| 3 | "Academy" | `AcademyView` | Training courses and certifications |
| 4 | "Account" | `ProfileView` → `PilotProfileView` | Account and settings |

#### Customer Tabs (3 tabs)
| Tab | Label | View | Purpose |
|-----|-------|------|---------|
| 0 | "Home" | `CustomerBookingView` | Browse and book missions |
| 1 | "History" | `CustomerActivityView` → `CustomerBookingDetailView` | Booking history |
| 2 | "Account" | `ProfileView` → `CustomerProfileView` | Account and settings |

Note: `CustomerBookingDetailView` is a separate view from `BookingDetailView` (pilot-specific).

### Navigation Patterns

1. **Tab Navigation:** Root-level TabView with badge counts
2. **Push Navigation:** `NavigationStack` + `NavigationLink` for drill-down
3. **Modal Sheets:** `.sheet(isPresented:)` / `.sheet(item:)` for compose/edit flows
4. **Full-Screen Covers:** `.fullScreenCover()` for auth, premium animations
5. **Deep Links:** `DeepLinkManager.pendingDestination` enum with 25+ destinations

### Deep Link Destinations

Handled in `MainTabView.handleDeepLinkDestination`:
```
.jobs, .bookingDetail(UUID), .weather, .flightRadar,
.hangerTalkPost(UUID), .hangerTalkProfile(UUID), .hangerTalkInbox,
.hangerTalkSpace(UUID), .marketplace, .profile,
.licenseManagement, .messages(conversationId)
```

Note: `ConversationsListView` is presented as a `.sheet` from both Pilot and Customer tabs when triggered by a `.messages` deep link — this bypasses the tab hierarchy.

### Navigation Flow Map

```
WelcomeView → AuthenticationView → MainTabView
    ├── PilotTabView
    │   ├── Tab 0: PilotBookingListView → BookingDetailView → MessageView
    │   ├── Tab 1: MyFlightsView → BookingDetailView
    │   ├── Tab 2: CockpitView
    │   │   ├── HangerTalkView → PostDetailView / ComposeView / InboxView
    │   │   │   └── HangerTalkInboxCategoryView (drill-down by category)
    │   │   ├── HangerSpacesBar → HangerSpaceRoomView
    │   │   ├── WeatherView / METARView / NOTAMView / ATISView
    │   │   ├── SafeFlyView → SafeFlySettingsView
    │   │   ├── MarketplaceView → ListingDetailView / CreateListingView
    │   │   │   └── MarketplaceReviewView (post-transaction)
    │   │   ├── LogsView → FlightLogFormView / FlightPlanFormView
    │   │   ├── ChecklistTabView → PreFlight / PostFlight / Operation / SiteSurvey
    │   │   │   └── BookingChecklistSelectionView → BookingSpecificChecklistView
    │   │   ├── BookingFlightPlanSelectionView → FlightPlanFormView
    │   │   ├── BeaconView → BeaconOnboardingView
    │   │   │   └── CertificateHistoryView (renewal history)
    │   │   └── IncidentLogBookingSelectionView → IncidentLogFormView
    │   ├── Tab 3: AcademyView
    │   │   ├── RegionOnboardingView (first-time region gate)
    │   │   ├── CourseContentView → SlidePresentationView
    │   │   ├── TestCenterView → ExamIntroView → ProctorInfoView → ProctoredTestView
    │   │   │   └── ProctorTestSchedulingView (payment-integrated scheduling)
    │   │   └── HangerHelpView → PostDetailView
    │   └── Tab 4: ProfileView → PilotProfileView
    │       ├── BadgesView / RatingsListView / ConnectionsView
    │       ├── PilotPostsListView / FollowListView
    │       ├── SettingsView / NotificationsView
    │       ├── HelpView (HelpCenterView, FeedbackView, ChatSupportView)
    │       ├── BugReportView (TicketReportListView, TicketReportDetailView)
    │       ├── ExpressPromotionView / BecomePilotView
    │       ├── BalanceView / StripeAccountSetupView / ReferralHistoryView
    │       └── AcademyPassManagementView
    │
    ├── CustomerTabView
    │   ├── Tab 0: CustomerBookingView → CreateBookingStep1-4 → BookingSuccessAnimation
    │   │   └── PackagePromotionView (post-booking subscription upsell)
    │   ├── Tab 1: CustomerActivityView → CustomerBookingDetailView
    │   └── Tab 2: ProfileView → CustomerProfileView
    │       └── ClientShopView (customer-only Shopify browse)
    │
    └── Cross-cutting: ConversationsListView (sheet via deep link from any tab)
```

---

## 6. Models Layer

**Location:** `Buzz/Models/` (50 files)

### Core User & Profile

| Model | File | Key Fields |
|-------|------|------------|
| `UserProfile` | `UserProfile.swift` | id, userType, firstName, lastName, callSign, email, phone, gender, profilePictureUrl, specialization, balance, stripeAccountId, communicationPreference, isExMilitary, isGovernmentEmployee, hasFaaCertification, isBuzzAffiliate, veteranServiceName/Country/Branch/Number, isVerified, isBeaconVolunteer, referralCredits, referredBy, lastLocationLat/Lng/Update, selectedRegion, preferredMeasurementSystem |
| `UserType` | `UserProfile.swift` | Enum: pilot, customer, admin |
| `MeasurementSystem` | `UserProfile.swift` | Enum: imperial, metric (with conversion utilities) |
| `CommunicationPreference` | `UserProfile.swift` | Enum: email, text, both |
| `CustomerRole` | `UserProfile.swift` | Enum: individual, company, government, nonProfit |
| `Gender` | `UserProfile.swift` | Enum: male, female, other, preferNotToSay |
| `MeasurementFormatter` | `UserProfile.swift` | Static utility enum with 6 unit conversion methods (temperature, windSpeed, distance F↔C, mph↔km/h, mi↔km) |
| `PilotStats` | `PilotStats.swift` | pilotId, totalFlightHours, completedBookings, tier, callsign |

### Booking System

| Model | File | Key Fields |
|-------|------|------------|
| `Booking` | `Booking.swift` | id, customerId, pilotId, specialization, status, paymentAmount, tipAmount, locationName, locationLat/Lng, scheduledDate, endDate, isVoluntary, hourlyRate, finalHoursWorked, estimatedFlightHours, requiredMinimumRank, numberOfPilots, assignmentType, governmentAgency, usesBeaconProgram, paymentIntentId, transferId, chargeId, customerCompleted, pilotCompleted, completedAt, expiresAt, expirationNotified, pilotRated, customerRated, isInternalTest |
| `BookingStatus` | `Booking.swift` | Enum: available, accepted, staffed, inProgress, completed, expired, cancelled |
| `BookingSpecialization` | `Booking.swift` | Enum: automotive, motionPicture, realEstate, agriculture, inspections, searchRescue, logistics, droneArt, surveillanceSecurity, mappingSurveying |
| `BookingCrewMember` | `Booking.swift` | bookingId, pilotId, role (lead/crew), rankAtAcceptance (1-4), payoutAmount, transferId, joinedAtString, pilotName, callSign, profilePictureUrl |
| `BookingCrewResponse` | `Booking.swift` | Edge function response with crew array + lead pilot info |
| `JoinCrewResponse` | `Booking.swift` | Edge function response (different serialization from standard Supabase) |
| `DisputeReason` | `Booking.swift` | Enum: incorrectCharge, serviceNotProvided, qualityIssue, safetyConcern, other |
| `BookingConfig` | `BookingConfig.swift` | supportedSpecializations, serviceAreas with `contains()` method |

### Social (HangerTalk)

| Model | File | Key Fields |
|-------|------|------------|
| `HangerTalkPost` | `HangerTalkSocial.swift` | authorId, body, imageUrls, likeCount, replyCount, repostCount, isReply, parentPostId |
| `HangerTalkPostInsert` | `HangerTalkSocial.swift` | Insert struct for creating posts |
| `HangerTalkPostResponse` | `HangerTalkSocial.swift` | Supabase join response with profiles |
| `HangerTalkPostWithAuthor` | `HangerTalkSocial.swift` | Post + author profile + interaction states (isLiked, isReposted, isBookmarked, isFollowed, authorFullName) |
| `HangerTalkFeedTab` | `HangerTalkSocial.swift` | Enum: forYou, following, liked, bookmarks |
| `HangerTalkLike/Repost/Bookmark` | `HangerTalkSocial.swift` | Interaction record structs |
| `HangerTalkMention` | `HangerTalkSocial.swift` | Post mention tracking |
| `HangerTalkNotificationType` | `HangerTalkSocial.swift` | Enum: like, reply, mention, follow, newPost, spaceLive |
| `HangerTalkNotificationInsert/Response/Item` | `HangerTalkSocial.swift` | Full notification infrastructure (3 structs) |
| `UserFollow` | `HangerTalkSocial.swift` | followerId, followingId |
| `FollowListTab` | `HangerTalkSocial.swift` | Enum: followers, following |

### Forum (HangerHelp)

| Model | File | Key Fields |
|-------|------|------------|
| `HangerTopic` | `HangerHelp.swift` | name, description, iconName, colorName, displayOrder, isActive |
| `HangerPost` | `HangerHelp.swift` | title, body, topicId, likeCount, commentCount, isPinned, imageUrls |
| `HangerPostInsert/Response/WithAuthor` | `HangerHelp.swift` | Insert, Supabase join, and display structs |
| `HangerComment` | `HangerHelp.swift` | body, depth (nested), parentCommentId, likeCount |
| `HangerCommentInsert/Response/WithAuthor` | `HangerHelp.swift` | Insert, Supabase join, and display structs |
| `HangerLike` | `HangerHelp.swift` | userId, postId/commentId (mutually exclusive via CHECK) |
| `HangerSavedPost/FollowedPost/HiddenPost` | `HangerHelp.swift` | User action structs for posts |
| `HangerSavedComment/FollowedComment` | `HangerHelp.swift` | User action structs for comments |
| `HangerAuthorProfile` | `HangerHelp.swift` | id, userType, callSign, profilePictureUrl, firstName, lastName + computed: fullName, isPilot, publicDisplayName, visibleDisplayName(to:) |
| `HangerAuthorProfileOrArray` | `HangerHelp.swift` | Enum handling Supabase join responses (decodes array first, then single) |
| `HangerTopicInfoOrArray` | `HangerHelp.swift` | Parallel enum for topic joins |
| `HangerActivityType/Item/CommentResponse/PostInfo` | `HangerHelp.swift` | Activity feed infrastructure |

### Live Audio Spaces

| Model | File | Key Fields |
|-------|------|------------|
| `HangerSpace` | `HangerSpace.swift` | hostId, title, status (scheduled/live/ended), livekitRoomName, listenerCount, speakerCount |
| `HangerSpaceParticipant` | `HangerSpace.swift` | spaceId, userId, role (host/speaker/listener) |
| `HangerSpaceSpeakerRequest` | `HangerSpace.swift` | spaceId, userId, status (pending/approved/declined) |
| `LiveKitTokenResponse` | `HangerSpace.swift` | token, wsUrl |

### Messaging

| Model | File | Key Fields |
|-------|------|------------|
| `Message` | `Message.swift` | bookingId, fromUserId, toUserId, text, isRead, reactions |
| `DirectMessage` | `DirectMessage.swift` | fromUserId, toUserId, text, isRead, metadata (JSONB), reactions, createdAt |
| `DirectMessageMetadata` | `DirectMessage.swift` | type, listingCard (for rich message previews) |
| `DirectMessageListingCard` | `DirectMessage.swift` | title, price, imageUrl, condition |
| `DirectMessageInsert` | `DirectMessage.swift` | Insert struct for creating messages |
| `DirectMessageConversation` | `DirectMessage.swift` | id, partnerId, lastMessage, hasUnreadMessages |
| `MessageReactionType` | `MessageReaction.swift` | Enum: like, dislike, love, haha, emphasize, question |
| `MessageReactionRecord` | `MessageReaction.swift` | userId, reaction type, timestamps |
| `BookingMessageReactionRow/Upsert` | `MessageReaction.swift` | Booking message reaction types |
| `DirectMessageReactionRow/Upsert` | `MessageReaction.swift` | DM reaction types |
| `MessageReactionAggregate` | `MessageReaction.swift` | Aggregated counts + `Array<MessageReactionRecord>` extension with `applyingReaction()`, `removingReaction()`, `aggregateSummaries()` |

### Training & Academy

| Model | File | Key Fields |
|-------|------|------------|
| `TrainingCourse` | `TrainingCourse.swift` | **Not Codable** (Identifiable only, constructed in AcademyService). Fields: title, description, duration, level, category, provider, instructor, instructorPictureUrl, rating, studentsCount, isEnrolled, requiresSubscriptionToEnroll, requiresUasGroundSchool, requiresFlightReviewPassed, requiresRocAPassed, externalUrl, coverImageUrl, region, active |
| `CourseRegion` | `TrainingCourse.swift` | Enum: canada, usa, uk, australia, newZealand, southAfrica, other, global |
| `RecurrentTrainingNotice` | `TrainingCourse.swift` | Struct for recurrence reminders |
| `CourseSection` | `CourseSection.swift` | courseId, name, displayOrder, description, sectionType (units/test/recurrent/exam), examType, requiresSubscription, requiresTestPassed, prerequisiteSectionId, isActive |
| `CourseUnit` | `CourseUnit.swift` | unitNumber, title, materialUrls/Names/Types, sectionId, orderIndex, prerequisites |
| `CourseMaterial` | `CourseUnit.swift` | index, url, name, type with computed: isPDF, isImage, isVideo |
| `CourseTest` | `CourseTest.swift` | testName, passingScore, duration, requiredForProgression, needsProctor, priceOfSchedule, sectionId |
| `TestQuestion` | `CourseTest.swift` | questionText, options, correctAnswerIndex, explanation, imageUrls, problemSets |
| `TestResult` | `CourseTest.swift` | pilotId, testId, score, passed, answers, attemptNumber, uploadStatus (notSubmitted/pending/approved/rejected), reviewer info |
| `CompletedUnit` | `CompletedUnit.swift` | **Not Codable** (Identifiable only). pilotId, unitId, courseId, unitNumber, unitTitle, completedAt. `CompletedUnitResponse` is Codable for Supabase join decoding |
| `SlideContent` | `SlideContent.swift` | Enum: pdf, image, video, question. `QuestionData` struct with base64 JSON decoding |
| `Badge` | `Badge.swift` | courseId, badgeType (11 types), earnedAt, expiresAt, isRecurrent, provider |
| `Badge.BadgeType` | `Badge.swift` | Enum: course, exMilitary, buzz, governmentEmployee, faa, flightReviewer, rocaExaminer, beaconVolunteer, cert, firstAid, basicFirefighter |
| `Badge.CourseProvider` | `Badge.swift` | Enum: buzz, redCross, usfa, fema, amazon, tmobile, other (Note: duplicated in `TrainingCourse.CourseProvider`) |
| `BadgeCatalog` | `Badge.swift` | Backend badge definitions with iconName, colorName, displayOrder |
| `AvailableBadge` | `Badge.swift` | For badge earning screens |
| `ExamAppointment` | `ExamAppointment.swift` | pilotId, examType (flightReview/rocA/groundSchoolTest), scheduledDate, durationMinutes, locationType (inPerson/online), locationAddress, meetingLink, status (pending/confirmed/completed/cancelled), stripePaymentIntentId, stripeChargeId, paymentAmount, zoomMeetingId, zoomMeetingPassword, startUrl, examinerId, notes |
| `ExamPriceResponse` | `ExamAppointment.swift` | Edge function response with unitAmount and formatted price |
| `ExamPrerequisitesStatus` | `ExamAppointment.swift` | Checks for ground school + unit completion |
| `ExamTypeConfig` | `ExamTypeConfig.swift` | Backend-driven exam config: examType, displayName, description, durationMinutes, allowsOnline, stripeProductId, prerequisites. Includes 3 static default configs |

### Marketplace

| Model | File | Key Fields |
|-------|------|------------|
| `MarketplaceListing` | `Marketplace.swift` | sellerId, title, description, price, category (9 types), condition (5 levels), transactionType (ship/meetup/both), imageUrls, locationName/Lat/Lng, brand, model, shippingCost, viewCount, favoriteCount, offerCount, expiresAt |
| `MarketplaceListingInsert/Update/Response/WithSeller` | `Marketplace.swift` | Insert, update, join, and display structs |
| `MarketplaceFavorite` | `Marketplace.swift` | userId, listingId |
| `MarketplaceOffer` | `Marketplace.swift` | listingId, buyerId, amount, message, status (pending/accepted/declined/withdrawn/expired) |
| `MarketplaceOfferInsert/Response` | `Marketplace.swift` | Insert and join structs |
| `MarketplaceTransaction` | `Marketplace.swift` | 11 statuses: pendingPayment, paid, shipped, delivered, releasing, completed, meetupScheduled, meetupCompleted, disputed, refunded, cancelled |
| `MarketplaceTransactionWithDetails` | `Marketplace.swift` | Display struct with resolved profiles |
| `MarketplaceReview/ReviewWithProfile` | `Marketplace.swift` | Post-transaction review structs |
| `MarketplacePaymentResponse` | `Marketplace.swift` | Edge function payment response |
| `MarketplaceSortOption` | `Marketplace.swift` | Enum: newest, priceLowToHigh, priceHighToLow |
| `ListingStatus` | `Marketplace.swift` | Enum: active, sold, reserved, expired, removed |

### Aviation Data

| Model | File | Key Fields |
|-------|------|------------|
| `FlightLog` | `FlightLog.swift` | pilotId, aircraftNumber, sheetNumber, descriptionOfFlight, date, timeOut, timeIn, totalAirtimeMinutes, comments, signatureData (base64), isLocked. `FlightLogInsert` for creation |
| `FlightPlan` | `FlightPlan.swift` | Comprehensive flight plan with regulatory authority, LAANC status, airspace class |
| `METAR` | `METAR.swift` | stationId, rawText, temperature, wind, visibility, cloudLayers, flightCategory (VFR/IFR) |
| `NOTAM` | `NOTAM.swift` | notamNumber, icaoCode, message, interpretation with categories |
| `ATIS` | `ATIS.swift` | icao, wind, visibility, skyCondition, altimeter, runways |
| `SafeFlyHour` | `SafeFly.swift` | forecast + kpIndex + safetyStatus + violations |
| `NWSAlert` | `NWSAlert.swift` | event, severity, headline, description |
| `Transponder` | `Transponder.swift` | deviceName, remoteId, isLocationTrackingEnabled, lastLocation |

### Pilot Credentials

| Model | File | Key Fields |
|-------|------|------------|
| `PilotLicense` | `PilotLicense.swift` | pilotId, licenseType (13 types incl. custom), fileUrl, fileType (pdf/image), uploadedAt, OCR fields (name, courseCompleted, completionDate, certificateNumber) |
| `LicenseApprovalRequest` | `PilotLicense.swift` | pilotId, licenseId, licenseType, fileUrl, status (pending/preApproved/approved/rejected/documentDeleted), reviewedAt, reviewedBy, reviewerNotes |
| `LicenseApprovalStatus` | `PilotLicense.swift` | Enum: pending, preApproved, approved, rejected, documentDeleted |
| `LicenseCategory` | `PilotLicense.swift` | Enum: dronePilot, radioOperator, flightReviewer, examiner, other |
| `LicenseNotification` | `PilotLicense.swift` | For license approval/rejection notifications |
| `GovernmentID` | `GovernmentID.swift` | fileUrl, verificationStatus, stripeSessionId |
| `DroneRegistration` | `DroneRegistration.swift` | manufacturer, model, serialNumber, registrationNumber |
| `FlightHourClaim` | `FlightHourClaim.swift` | claimedFlights, claimedHours, evidenceFiles, status |

### Emergency & Volunteer

| Model | File | Key Fields |
|-------|------|------------|
| `BeaconTrainingProgress` | `BeaconTrainingProgress.swift` | pilotId, trainingType (cpr/firefighting/cert), certificateUrl, uploadedAt, expiresAt, verified, verifiedAt, verifiedBy |
| `BeaconTrainingType` | `BeaconTrainingProgress.swift` | Enum with displayName, icon, description, color properties |
| `BeaconVolunteer` | `BeaconTrainingProgress.swift` | pilotId, enrolledAt, isAvailable, lastLocationLat/Lng/Update, notificationRadiusMiles, totalMissionsCompleted, totalHoursVolunteered, peopleHelped |
| `BeaconOnboardingStep` | `BeaconTrainingProgress.swift` | Enum: cprTraining, firefightingTraining, certTraining, badgeAward |

### Other Models

| Model | File | Purpose |
|-------|------|---------|
| `NotificationPreferences` | `NotificationPreferences.swift` | 19 notification type preferences (system/email/text). `NotificationDeliveryOptions` struct with `isEnabled` computed property |
| `AvailabilityBlockout` | `AvailabilityBlockout.swift` | Pilot availability scheduling with recurrence (none/daily/weekly/weekdays/weekends/monthly) |
| `Rating` | `Rating.swift` | 0-5 star ratings. Includes `RatingWithUser`, `UserRatingSummary` |
| `Referral` | `Referral.swift` | 6 types: `ReferralCode`, `ReferralStatus` (enum), `Referral`, `ReferralStats`, `ReferralHistoryItem`, `GenerateReferralCodeResponse`, `ApplyReferralCodeResponse` |
| `NewsArticle` | `NewsArticle.swift` | Industry news. Includes `DroneNewsResponse`, `NewsSource` (faa/transportCanada/global) |
| `ShopifyProduct` | `ShopifyProduct.swift` | Shopify storefront data with variants, images, pricing |
| `SiteSurvey` | `SiteSurvey.swift` | Site survey form data for PDF generation |
| `IncidentLog` | `IncidentLog.swift` | Incident reports with witness info, police/ATC reporting flags. `IncidentLogInsert` |
| `MaintenanceLog` | `MaintenanceLog.swift` | Aircraft maintenance records. `MaintenanceLogInsert` |
| `TicketReport` | `BugReport.swift` | Unified ticket system (NOT named BugReport). Types: bug/safety/dispute. `TicketReportStatus` (open/inProgress/resolved/closed), `TicketReportInsert`, includes bookingId and imageUrls for disputes |
| `ExpressPromotionApplication` | `ExpressPromotionApplication.swift` | Promotion pipeline: promotionType (lieutenant/commander), documentType (aviationDegree/ppl/groundSchoolTest), documentUrls, status (pending/inReview/verified/rejected), targetTier, rejectionReason |
| `FlightHourClaim` | `FlightHourClaim.swift` | Bulk historical flight hour claims: claimedFlights, claimedHours, notes, evidenceFiles, status, reviewer info. `FlightHourClaimInsert` |
| `TaxDocument` | `TaxDocument.swift` | pilotId, documentType (w2/form1099/taxSummary/other), year, fileUrl |
| `CockpitUsageLog` | `CockpitUsageLog.swift` | Analytics tracking: userId, componentName, sectionName. `CockpitUsageLogInsert` |
| `AppVersionTracking` | `AppVersionTracking.swift` | userId, platform, appVersion, lastSeenAt. `AppVersionTrackingUpsert` |
| `MissionDistancePreference` | `MissionDistancePreference.swift` | Static enum for UserDefaults: storageKey, defaultMiles (25), quickOptions ([5,25,50,100,150]), maxMiles (150) |

---

## 7. Services Layer

**Location:** `Buzz/Services/` (80+ files)

### Core Infrastructure

#### SupabaseClient
- **Singleton** wrapping Supabase Swift SDK client
- Initialized with `Config.supabaseURL` and `Config.supabaseAnonKey`
- All services access via `SupabaseClient.shared.client`

#### AuthService
- Session management, sign-in/up (email, phone OTP, Apple, Google)
- Profile loading with 3-retry exponential backoff
- Profile caching in `UserDefaults` for offline fallback
- Account deletion with cascading cleanup (posts, likes, follows, tokens, mentions, notifications)
- Email change via edge function token flow
- UI test mode: reads `UITEST_MODE`, `UITEST_USER_ID`, `UITEST_ROLE` environment variables

#### DemoModeManager
- Singleton with `isDemoModeEnabled` persisted to `UserDefaults`
- Every service checks this before making API calls
- Returns static demo data when enabled

#### DeepLinkManager
- Parses push notification `userInfo` payloads
- Routes to 25+ `DeepLinkDestination` enum cases
- Integrates with `NotificationManager` tap handler

#### NotificationManager
- 27 notification categories (bookings, messages, weather, social, marketplace, beacon, etc.)
- Local notifications: `UNUserNotificationCenter` with category-specific content
- Remote push: Calls `send-push-notification` edge function
- Device token management via `upsert_device_token` RPC
- Emergency alerts with `.critical` interruption level and flash overlay
- Preference checking via `NotificationPreferencesService`

#### NotificationPreferencesService
- Persists `NotificationPreferences` struct to `UserDefaults` (key: `notification_preferences`) — no Supabase table
- Methods: `loadPreferences()`, `savePreferences()`

### Social & Messaging Services

#### HangerTalkService
- **Tables:** `hanger_talk_posts`, `hanger_talk_likes`, `hanger_talk_reposts`, `hanger_talk_bookmarks`, `hanger_talk_mentions`, `user_follows`, `hanger_talk_notifications`
- Feed fetching: all posts, following-only, liked, bookmarked
- CRUD: create/update/delete posts and replies
- Interactions: toggleLike, toggleRepost, toggleBookmark, toggleFollow (optimistic UI)
- Image upload: `hanger_images` storage bucket, max 4 images, JPEG 1200px
- Search: case-insensitive `ilike` on body and `call_sign`
- **5 notification dispatch points:** like, reply, mention, follow, newPost

#### HangerHelpService
- **Tables:** `hanger_topics`, `hanger_posts`, `hanger_comments`, `hanger_likes`, `hanger_saved_*`, `hanger_followed_*`, `hanger_hidden_*`
- Hierarchical comment tree building from flat response
- Activity tracking with `UserDefaults` last-seen timestamp
- Topic-based post filtering with pinned-first ordering

#### HangerSpaceService
- Live audio room lifecycle: create, join, leave, end
- Participant role management (host, speaker, listener)
- Speaker request workflow
- LiveKit token generation via edge function

#### MessageService
- **Booking messages:** `messages` table, tied to booking context
- **Direct messages:** `direct_messages` table with optional metadata (listing cards)
- Deterministic conversation IDs via SHA-256 of sorted user UUIDs
- Emoji reactions: upsert/clear with optimistic UI
- Anti-spam: `countSentMessagesBeforeResponse()` check
- Read/unread management, soft-delete

### Booking & Payment Services

#### BookingService
- Booking creation (standard + Search & Rescue)
- Status transitions: available → accepted → staffed → inProgress → completed
- Multi-pilot crew management for automotive/S&R
- Protocol-based dependency injection: `BookingBackend`, `BookingNotificationManaging`, `NotificationPreferencesProviding`
- Depends on `BookingConfigService` for configuration values

#### BookingConfigService
- **Singleton** (`BookingConfigService.shared`) for backend-managed booking configuration
- **Table:** `booking_config` (singleton row with `id = 'default'`)
- Methods: `fetchConfig()`, `ensureConfigLoaded()` (lazy-load guard)
- Returns `BookingConfig` with `.defaultConfig` fallback on error

#### AvailabilityBlockoutService
- **Table:** `availability_blockouts`
- Methods: `fetchBlockouts(pilotId:)`, `createBlockout()`, `updateBlockout()`, `deleteBlockout()`
- Supports recurrence types (none/daily/weekly/weekdays/weekends/monthly)

#### PaymentService
- Stripe PaymentIntent creation via edge functions
- Referral credit application
- Transfer group support for Stripe Connect payouts

#### SubscriptionService
- Academy Pass subscription management (create, cancel, pause)
- Automotive/real estate tier pricing via edge functions
- Stripe subscription lifecycle

#### StoreKitManager
- Apple In-App Purchase management
- Product loading, purchase flow, transaction verification
- `Transaction.currentEntitlements` monitoring
- Async transaction listener via `Transaction.updates`

#### EntitlementManager (defined inside `StoreKitManager.swift`, not a separate file)
- Unified subscription check: Apple StoreKit first, then Stripe (via `course_subscriptions` table)
- Returns `SubscriptionSource` enum (apple, stripe)
- Prevents double-billing across platforms

### Profile & Credential Services

#### ProfileService
- Static profile cache `[UUID: UserProfile]`
- Profile CRUD with call sign uniqueness validation
- Region, measurement system, veteran status updates
- Hash-based demo profile generation

#### ProfilePictureService
- **Storage bucket:** `profile-pictures` (path `{userId}/profile.jpg`)
- **Edge functions:** `create-verification-session`, `get-selfie-from-verification`, `check-verification-status`
- Methods: `uploadProfilePicture(userId:image:)`, `deleteProfilePicture(userId:)`
- Stripe Identity selfie verification: `createSelfieVerificationSession()`, `handleSelfieVerificationAndUpload()`
- Compresses images to max 800x800 at 0.8 JPEG quality

#### BadgeService
- Badge query and display
- 11 badge types: course, exMilitary, buzz, governmentEmployee, faa, flightReviewer, rocaExaminer, beaconVolunteer, cert, firstAid, basicFirefighter

#### RatingService
- 0-5 star rating submission and retrieval
- Average calculation with profile resolution
- Notification on new review

### Flight & Log Services

| Service | Table | Key Features |
|---------|-------|--------------|
| `FlightLogService` | `flight_logs` | Immutable logs with signature data, auto sheet numbering |
| `FlightPlanService` | `flight_plans` | Flight plan CRUD |
| `FlightHourClaimService` | `flight_hour_claims` | Hour claim submissions with evidence |
| `MaintenanceLogService` | `maintenance_logs` | Immutable maintenance records |
| `IncidentLogService` | `incident_logs` | Immutable incident reports |
| `ChecklistService` | `booking_checklists` | Pre/post flight checklist management |
| `SiteSurveyService` | (no Supabase — on-device only) | FAA-compliant site survey PDF generation via `UIGraphicsPDFRenderer`, address search via `MKLocalSearch`, reverse geocoding via `CLGeocoder` |

### Weather Services

| Service | Data Source | Purpose |
|---------|------------|---------|
| `WeatherService` | NOAA NWS API (primary), Open-Meteo (fallback) | Current conditions, forecasts |
| `METARService` | Aviation weather API | METAR parsing and display |
| `NOTAMService` | `get-notams` edge function | Airspace notices |
| `ATISService` | ATIS API | Airport terminal information |
| `NWSAlertService` | NWS API | Weather alerts with background fetch |

### Marketplace & Commerce

| Service | Purpose |
|---------|---------|
| `MarketplaceService` | Listing CRUD, offers, transactions, reviews |
| `ShopifyService` | Shopify Storefront GraphQL API integration |
| `StripeConnectService` | Seller onboarding via Stripe Connect |

### Beacon (Emergency Response)

#### BeaconService
- **Tables:** `beacon_training_progress`, `beacon_volunteers`
- **Storage:** `certificates` bucket for training certificates
- **RPCs:** `sync_badges_to_beacon_training`, `get_latest_beacon_training`, `enroll_beacon_volunteer`, `find_nearby_beacon_volunteers` (Haversine distance)
- Training requirement validation: CPR + Firefighting + CERT (3 required, not 2; must be non-expired)

### Location & Tracking

#### LocationTrackingService
- `CLLocationManager` with `CheckedContinuation` for async/await
- 5-second timeout for GPS fix
- Persists to `profiles` table (last_location_lat, last_location_lng)
- Simulator fallback to `LocationHelper.defaultSimulatorLocation`

### Academy Services

#### AcademyService (~1,200 lines)
- **Tables:** `training_courses`, `course_units`, `course_sections`, `unit_completions`, `test_results`, `course_enrollments`
- **RPCs:** `check_ground_school_test_status`, `check_flight_review_status`, `check_roc_a_status`
- Methods: `fetchCourses()`, `fetchCoursesWithEnrollment(pilotId:)`, `fetchCourseSections()`, `fetchCourseUnits()`, `fetchCourseTests()`, `fetchTestQuestions()`
- Enrollment: `enrollInCourse()`, `unenrollFromCourse()`, `updateCourseProgress()`, `syncAllCourseProgress()`
- Prerequisites: `checkGroundSchoolTestStatus()`, `checkFlightReviewTestStatus()`, `checkRocATestStatus()`
- Consults `AcademyCourseAccessPolicy` for subscription requirements

#### AcademyCourseAccessPolicy
- Pure logic type (no Supabase calls) — `enum` with static methods
- `requiresSubscriptionToEnroll(courseTitle:provider:externalUrl:sectionSnapshots:)` — exempts UAS Pilot, RPAS Pilot, ROC-A, Flight Reviewer courses
- `missingEnrollmentRequirements(for:hasSubscription:hasPassedGroundSchool:hasPassedFlightReview:hasPassedRocA:)`

#### ExamService
- **Tables:** `exam_appointments`, `exam_type_config`, `test_results`, `course_units`, `unit_completions`
- **Edge functions:** `get-exam-price`, `create-exam-payment`, `create-zoom-meeting`, `send-exam-confirmation`
- Methods: `fetchExamConfigs()`, `checkPrerequisites()`, `createExamPaymentIntent()`, `createExamAppointment()`, `cancelAppointment()`, `rescheduleAppointment()`, `hasExistingAppointment()`
- Business rules: 24-hour reschedule cutoff; Ground School Test + Unit 4 completion required for paid exams

#### ExamResultUploadService
- **Storage bucket:** `course-test-results`
- **RPC:** `submit_test_result_upload`
- Methods: `getTestResultStatus()`, `uploadTestResultFiles()`, `deleteTestResultFiles()`
- Validates files up to 10 MB; supports JPG, PNG, PDF, HEIC

#### CourseSubscriptionService
- **Table:** `course_subscriptions`
- Methods: `checkSubscriptionStatus(pilotId:)`, `createSubscriptionRecord()`, `updateSubscriptionStatus()`, `hasAccessToUnit()`
- Business rule: Units 1-4 always free; Units 5+ require active subscription
- Stores `source` field ("apple" vs "stripe"); upserts on `pilot_id, course_id` conflict

### OCR & Document Processing

#### OCRService
- Uses Apple Vision framework (`VNRecognizeTextRequest`) and `PDFKit`
- Methods: `extractText(from:fileType:)`, `parseDroneRegistrationInfo()`, `parsePilotLicenseInfo(from:licenseType:)`
- Handles multiple certificate types: RPA Pilot (CAN), ROC-A (CAN), ROC-A Examiner (CAN), Restricted Radiotelephone Permit (US)
- Used as dependency by `LicenseUploadService` and `DroneRegistrationService`

### Other Services

| Service | Purpose |
|---------|---------|
| `LicenseUploadService` | License document uploads (depends on `OCRService` for parsing) |
| `IdentityVerificationService` | Stripe Identity verification sessions |
| `DroneRegistrationService` | Aircraft registration management |
| `CockpitUsageService` | Feature usage analytics logging |
| `AppVersionTrackingService` | App version tracking per user |
| `AppUpdateService` | Update availability checking |
| `RankingService` | Leaderboard calculations |
| `NewsService` | Industry news aggregation |
| `BugReportService` | Ticket report submission (bugs, safety, disputes) |
| `ReferralService` | Referral code generation and application |
| `ArcGISAirspaceService` | Airspace mapping |
| `SafeFlyService` | Flight safety analysis with configurable thresholds |
| `TransponderService` | ADS-B transponder data |
| `TopGunService` | Competitive game mode |
| `ExpressPromotionService` | Express promotion workflow |

### Service Dependency Graph

```
AuthService
  ├── SupabaseClient
  ├── NotificationManager (logout cleanup)
  └── ProfileService (indirect)

NotificationManager
  ├── SupabaseClient (device_tokens, send-push-notification)
  ├── DeepLinkManager (tap routing)
  └── Called by: BookingService, HangerTalkService, RatingService,
                 MessageService, BeaconService, MarketplaceService

HangerTalkService
  ├── SupabaseClient (7 tables)
  ├── NotificationManager (5 dispatch points)
  └── DemoModeManager

BookingService
  ├── SupabaseClient
  ├── NotificationManager
  ├── BookingConfigService (singleton)
  └── PaymentService (indirect)

WeatherService
  ├── NWSAlertService
  ├── NotificationManager
  ├── OpenMeteoUtils (static utility for WMO codes + cardinal directions)
  └── LocationTrackingService

StoreKitManager ←→ EntitlementManager (same file)
  └── SupabaseClient (course_subscriptions)

AcademyService
  ├── SupabaseClient (6 tables, several RPCs)
  ├── AcademyCourseAccessPolicy (pure logic)
  └── DemoModeManager

ExamService
  ├── SupabaseClient (exam_appointments, exam_type_config)
  └── Edge functions (get-exam-price, create-exam-payment, create-zoom-meeting)

CourseSubscriptionService
  └── SupabaseClient (course_subscriptions)

LicenseUploadService / DroneRegistrationService
  └── OCRService (Vision framework)

ProfilePictureService
  ├── SupabaseClient (profiles, Storage: profile-pictures)
  └── Edge functions (create-verification-session, Stripe Identity)

LocationHelper
  └── Static utility singleton with simulator coordinates (Ithaca, SF, LA, NYC)
```

---

## 8. Views Layer

**Location:** `Buzz/Views/` (176 files across 11 subdirectories)

### View Count by Feature Area

| Directory | Files | Purpose |
|-----------|-------|---------|
| `Cockpit/` | 61 | Flight operations, social, weather, marketplace, tools |
| `Profile/` | 44 | User account, settings, credentials, finances |
| `Academy/` | 28 | Training courses, exams, forum (incl. `SlideContent/` and `TestCenter/` subdirs) |
| `Bookings/` | 18 | Mission management, messaging |
| `Components/` | 9 | Reusable UI building blocks |
| `Auth/` | 5 | Authentication flows |
| `Shared/` | 4 | Global utilities |
| `Rankings/` | 2 | Leaderboard |
| `License/` | 2 | Credential management |
| `Navigation/` | 1 | Root tab dispatcher (also defines `MyFlightsView` inline) |
| `Welcome/` | 1 | Splash screen |

### Key Views by Feature

#### Authentication
- `AuthenticationView` - Email/phone/social login
- `SignUpView` - Registration with user type selection
- `PasswordResetFlowView` - Password recovery
- `PremiumIntroAnimationView` - Premium user onboarding animation
- `PackagePromotionView` - Post-booking subscription upsell (contains `AutomotivePackagePromotionView`)

#### Cockpit (Operations Hub)
- **Weather:** `WeatherView`, `METARView`, `NOTAMView`, `ATISView`, `HourlyForecastTableView`, `SafeFlyView`, `SafeFlySettingsView`
- **Flight Tools:** `LogsView` (hub), `FlightLogFormView`, `FlightPlanFormView`, `FlightHourClaimView`, `BookingFlightPlanSelectionView`, `ChecklistView`, `ChecklistTabView`, `PreFlightChecklistView`, `PostFlightChecklistView`, `BookingChecklistSelectionView`, `BookingSpecificChecklistView`
- **Social:** `HangerTalkView`, `HangerTalkPostCard`, `HangerTalkPostDetailView`, `HangerTalkComposeView`, `HangerTalkEditView`, `HangerTalkSearchView`, `HangerTalkInboxView`, `HangerTalkInboxCategoryView`
- **Spaces:** `HangerSpacesBar`, `HangerSpaceRoomView`, `CreateSpaceView`
- **Marketplace:** `MarketplaceView`, `ListingDetailView`, `CreateListingView`, `MyListingsView`, `MarketplaceOffersView`, `MakeOfferView`, `MarketplaceOrderView`, `MarketplaceTransactionsView`, `MarketplaceReviewView`
- **Maps/Safety:** `FlightRadarView`, `BookingMapView`, `TransponderView`, `BeaconView`, `SiteSurveyFormView`
- **Incidents:** `IncidentLogBookingSelectionView`, `IncidentLogFormView`, `MaintenanceLogFormView`
- **Beacon:** `BeaconView`, `BeaconOnboardingView`, `CertificateHistoryView`
- **Other:** `EventsView`, `GamesView`, `TopGunView`, `RacerView`, `ShopView`, `IndustryNewsView`

#### Bookings
- **Pilot Side:** `PilotBookingListView`
- **Customer Side:** `CustomerBookingView`, `CustomerActivityView`
- **Booking Flow:** `CreateBookingStep1View` → `Step1IndustryView` → `Step2View`/`Step2DetailsView` → `Step3PaymentView` → `Step4ConfirmView` → `BookingSuccessAnimationView`
- **Shared:** `BookingDetailView`, `BookingMapView`, `ConversationsListView`, `MessageView`, `ExtendBookingView`, `SearchRescueCompletionView`

#### Academy
- **Courses:** `AcademyView`, `CourseContentView`, `UnitDetailView`, `SlidePresentationView`, `RegionOnboardingView` (first-time region selection gate), `CourseSubscriptionView`
- **Slide Types:** `ImageSlideView`, `VideoSlideView`, `PDFSlideView`, `QuestionSlideView` (in `SlideContent/` subdir)
- **Exams:** `TestCenterView`, `ExamIntroView`, `ExamSchedulingView`, `ExamPaymentView`, `ProctorInfoView` (pre-exam proctor entry), `ProctorTestSchedulingView` (payment-integrated), `ProctoredMultipleChoiceTestView`, `MultipleChoiceTestView`, `QuestionNavigatorView`, `TestResultUploadView` (in `TestCenter/` subdir)
- **Forum:** `HangerHelpView`, `HangerHelpPostDetailView`, `HangerHelpNewPostView`, `HangerHelpEditPostView`, `HangerHelpEditCommentView`, `HangerHelpTopicDetailView`

#### Profile
- **Own Profile:** `PilotProfileView`, `CustomerProfileView`, `PublicProfileView`
- **Personal Info:** `PersonalInfoView`, `NameEditView`, `CallSignEditView`, `EmailEditView`, `PhoneEditView`, `GenderEditView`
- **Security:** `LoginSecurityView`, `ChangePasswordView`, `DeleteAccountView`
- **Credentials:** `BadgesView`, `BadgePreviewCard`, `CertificateBadgeUploadView`, `CertificateViewerView`, `CertificateHistoryView`, `GovernmentIDView`, `VeteranVerificationView`, `DroneRegistrationView`
- **Finances:** `BalanceView`, `RevenueDetailsView`, `SavedPaymentsView`, `StripeAccountSetupView`, `TaxDocumentView`, `ReferralHistoryView`
- **Social:** `ConnectionsView`, `FollowListView`, `DirectMessageView`, `PilotPostsListView`, `RatingsListView`
- **Subscriptions:** `AcademyPassManagementView`, `FlightPackageView`, `FlightPackagesView`, `RealEstatePackageView`
- **Settings:** `SettingsView`, `NotificationsView`, `MissionDistanceSettingsView`, `RegionSettingsView`, `UnitSettingsView`
- **Support:** `HelpView` (contains `HelpCenterView`, `FeedbackView`, `ChatSupportView`, `MailComposeView`), `BugReportView` (contains `TicketReportListView`, `TicketReportDetailView`)
- **Other:** `BecomePilotView`, `ExpressPromotionView` (contains `CommanderPromotionCard`), `ClientShopView` (customer-only Shopify)

### UI Patterns

#### Avatar Pattern
```swift
AsyncImage(url: URL(string: avatarUrl)) { phase in
    switch phase {
    case .success(let image):
        image.resizable().scaledToFill()
    default:
        Circle().fill(Color.gray.opacity(0.3))
    }
}
.frame(width: 40, height: 40)
.clipShape(Circle())
```

#### FAB (Floating Action Button)
```swift
ZStack(alignment: .bottomTrailing) {
    mainContent
    Button { ... } label: { Image(systemName: "plus") }
        .padding(.trailing, 20)
        .padding(.bottom, 20)
}
```

#### Card Layout
```swift
VStack(alignment: .leading, spacing: 12) {
    Label("Title", systemImage: "icon.name")
        .font(.headline)
    // Content
}
.padding()
.background(Color(.secondarySystemGroupedBackground))
.cornerRadius(12)
```

#### Loading Overlay
```swift
.overlay {
    if isLoading {
        Color.black.opacity(0.2).ignoresSafeArea()
        ProgressView()
    }
}
```

#### Image Loading
```swift
AsyncImage(url: url) { phase in
    switch phase {
    case .empty: ProgressView()
    case .success(let image): image.resizable().scaledToFill()
    case .failure: Image(systemName: "photo")
    @unknown default: EmptyView()
    }
}
```

### Accessibility
All views include:
- `.accessibilityLabel()` on interactive elements
- `.accessibilityHint()` for additional context
- `.accessibilityElement(children:)` for grouping
- `.accessibilityAddTraits()` for buttons, images
- `.accessibilityHidden()` for decorative elements

---

## 9. Supabase Backend

### Configuration
- **Supabase URL:** From `Config.supabaseURL`
- **Anon Key:** From `Config.supabaseAnonKey` (respects RLS)
- **Service Role Key:** Used by edge functions (bypasses RLS)

### Query Patterns

```swift
// SELECT with join
let response: [Type] = try await supabase
    .from("table_name")
    .select("*, profiles(id, call_sign, profile_picture_url)")
    .eq("status", value: "active")
    .order("created_at", ascending: false)
    .limit(50)
    .execute()
    .value

// INSERT
let newRecord: Type = try await supabase
    .from("table_name")
    .insert(insertData)
    .select()
    .single()
    .execute()
    .value

// UPDATE
try await supabase
    .from("table_name")
    .update(["field": value])
    .eq("id", value: id)
    .execute()

// DELETE
try await supabase
    .from("table_name")
    .delete()
    .eq("id", value: id)
    .execute()

// RPC
let result = try await supabase
    .rpc("function_name", params: ["p_user_id": userId])
    .execute()
    .value

// Edge Function
let response = try await supabase.functions.invoke(
    "function-name",
    options: FunctionInvokeOptions(body: requestBody)
)

// Storage Upload
try await supabase.storage
    .from("bucket_name")
    .upload(path: "folder/\(userId)/\(filename)", data: data)
```

### Realtime Subscriptions
Tables added to `supabase_realtime` publication:
- `hanger_spaces`
- `hanger_space_participants`
- `hanger_space_speaker_requests`

---

## 10. Edge Functions

**Location:** `supabase/functions/` (50+ Deno TypeScript functions)

### Payment & Financial (25 functions)

| Function | Purpose |
|----------|---------|
| `create-payment-intent` | Stripe PaymentIntent with transfer group and credit support |
| `create-exam-payment` | Exam appointment payment |
| `create-test-exam-payment` | Ground school test payment |
| `create-marketplace-payment` | Marketplace item purchase |
| `create-setup-intent` | Save payment method |
| `list-payment-methods` | List saved payment methods |
| `get-payment-intent` | Fetch payment status |
| `create-subscription` | Academy Pass subscription |
| `cancel-subscription` | Cancel subscription |
| `pause-subscription` | Pause subscription |
| `get-subscription` | Fetch subscription details |
| `get-subscription-plans` | List available plans |
| `create-transfer` | Stripe Connect transfer to pilot |
| `create-connected-account` | Pilot Stripe Connect onboarding |
| `delete-connected-account` | Disconnect Stripe account |
| `create-account-link` | Stripe Connect onboarding link |
| `check-account-status` | Check Stripe account status |
| `get-pilot-balance` | Query Stripe balance |
| `withdraw-balance` | Initiate pilot payout |
| `release-marketplace-funds` | Release marketplace escrow |
| `apply-booking-credits` | Apply referral credits |
| `apply-referral-code` | Apply referral code at signup |
| `generate-referral-code` | Generate unique referral code |
| `get-referral-stats` | Referral program statistics |
| `create-financial-connections-session` | ACH bank verification |
| `get-charge-id` | Get charge from payment intent |
| `attach-external-account` | Attach bank account |

### Booking (5 functions)
| Function | Purpose |
|----------|---------|
| `get-booking-crew` | Get crew members for booking |
| `join-automotive-booking` | Crew joins automotive booking |
| `get-automotive-booking-prices` | 3-tier automotive pricing |
| `get-real-estate-booking-prices` | 2-tier real estate pricing |
| `get-booking-config` | Specialization and service area config |

### Identity & Verification (5 functions)
| Function | Purpose |
|----------|---------|
| `create-verification-session` | Start Stripe Identity verification |
| `check-verification-status` | Check verification status |
| `get-selfie-from-verification` | Get selfie from verification |
| `update-license-approval` | Admin license approve/reject |
| `update-express-promotion` | Express promotion status update |

### Authentication (3 functions)
| Function | Purpose |
|----------|---------|
| `send-email-change-token` | Generate 6-digit email change token |
| `verify-email-change-token` | Verify and complete email change |
| `send-tc-affiliation-email` | Transport Canada affiliation email |

### Communication (3 functions)
| Function | Purpose |
|----------|---------|
| `send-push-notification` | APNs push via JWT (all device tokens) |
| `generate-livekit-token` | LiveKit token for audio rooms |
| `create-zoom-meeting` | Zoom meeting for online exams |

### Data (3 functions)
| Function | Purpose |
|----------|---------|
| `get-notams` | Fetch NOTAMs from external API |
| `fetch-drone-news` | FAA/TC/DroneLIFE news with 30-min cache |
| `send-exam-confirmation` | Exam booking confirmation |

### Scheduled Jobs (3 functions)
| Function | Purpose |
|----------|---------|
| `check-expiring-bookings` | Flag expiring bookings |
| `check-video-uploads` | Send video upload reminders |
| `cleanup-stale-spaces` | Clean up ended audio rooms |

### Exam (1 function — `create-exam-payment` already listed in Payment section)
| Function | Purpose |
|----------|---------|
| `get-exam-price` | Fetch exam price from Stripe product |

### Required Secrets
```
STRIPE_SECRET_KEY
SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY
APNS_KEY_ID, APNS_TEAM_ID, APNS_PRIVATE_KEY, APNS_BUNDLE_ID, APNS_PRODUCTION
LIVEKIT_API_KEY, LIVEKIT_API_SECRET, LIVEKIT_WS_URL
ALLOWED_ORIGIN
```

---

## 11. Database Schema

**Total Migrations:** 113+ files in `supabase/migrations/`

### Core Tables

#### profiles
```sql
id UUID PRIMARY KEY REFERENCES auth.users
email, first_name, last_name, full_name, avatar_url, call_sign
user_type -- pilot, customer, admin
verification_status, government_id_verified_at
is_beacon_volunteer, is_verified
referral_credits NUMERIC, referred_by UUID
last_location_lat, last_location_lng, last_location_update TIMESTAMPTZ
selected_region, measurement_system
role -- admin, pilot, customer, flight_reviewer, etc.
```

#### bookings
```sql
id UUID PRIMARY KEY
customer_id, pilot_id UUID REFERENCES profiles
specialization -- 10 enum values
status -- available, accepted, staffed, in_progress, completed, expired, cancelled
price, original_amount, final_amount, credits_applied NUMERIC
is_voluntary BOOLEAN, hourly_rate, final_hours_worked
start_date, end_date, completed_at TIMESTAMPTZ
location_lat, location_lng, location_address
notes, cancellation_reason TEXT
```

#### booking_crew
```sql
id UUID PRIMARY KEY
booking_id, pilot_id UUID REFERENCES
role -- lead, crew
rank_at_acceptance INT (1-4)
payout_amount NUMERIC -- $350/$450/$550/$650 for automotive
transfer_id, joined_at
```

### Social Tables

#### hanger_talk_posts
```sql
id UUID PRIMARY KEY
author_id UUID REFERENCES profiles
body TEXT, image_urls TEXT[]
like_count, reply_count, repost_count INT -- auto-updated by triggers
is_reply BOOLEAN, parent_post_id UUID SELF-REF
created_at, updated_at TIMESTAMPTZ
```

#### Supporting social tables
- `hanger_talk_likes` (user_id, post_id) UNIQUE
- `hanger_talk_reposts` (user_id, post_id) UNIQUE
- `hanger_talk_bookmarks` (user_id, post_id) UNIQUE
- `hanger_talk_mentions` (post_id, mentioned_user_id) UNIQUE
- `hanger_talk_notifications` (recipient_id, actor_id, type, post_id, is_read)
- `user_follows` (follower_id, following_id) UNIQUE, no self-follow

### Audio Rooms

#### hanger_spaces
```sql
id UUID PRIMARY KEY
host_id UUID REFERENCES profiles
title, description TEXT
status -- scheduled, live, ended
livekit_room_name TEXT UNIQUE
listener_count, speaker_count INT -- trigger-updated
started_at, ended_at, scheduled_at TIMESTAMPTZ
```

#### hanger_space_participants
```sql
id UUID PRIMARY KEY
space_id, user_id UUID REFERENCES (UNIQUE)
role -- host, speaker, listener
joined_at, left_at TIMESTAMPTZ
```

### Messaging

#### direct_messages
```sql
id UUID PRIMARY KEY
from_user_id, to_user_id UUID REFERENCES profiles
booking_id UUID NULLABLE
message_body TEXT, is_read BOOLEAN
metadata JSONB -- {type, listingCard: {title, price, imageUrl, condition}}
created_at TIMESTAMPTZ
```

#### messages (Booking chat)
```sql
id UUID PRIMARY KEY
booking_id, from_user_id, to_user_id UUID REFERENCES
message_body TEXT, is_read BOOLEAN
```

#### Reaction tables
- `booking_message_reactions` (booking_message_id, user_id, reaction)
- `direct_message_reactions` (direct_message_id, user_id, reaction)
- Reactions: like, dislike, love, haha, emphasize, question

### Training & Academy

#### training_courses
```sql
id UUID PRIMARY KEY
provider, title, category, description
requires_uas_ground_school, requires_flight_review_passed, requires_roc_a_passed BOOLEAN
is_active, display_order INT
```

#### course_sections
```sql
id UUID PRIMARY KEY
course_id UUID REFERENCES
name, display_order, section_type -- units, test, recurrent, exam
exam_type -- flight_review, roc_a
requires_subscription, requires_test_passed BOOLEAN
prerequisite_section_id UUID SELF-REF
```

#### course_subscriptions (Academy Pass)
```sql
id UUID PRIMARY KEY
pilot_id UUID, stripe_subscription_id TEXT
status -- active, trialing, paused, cancelled, past_due
current_period_end TIMESTAMPTZ
```

#### exam_appointments
```sql
id UUID PRIMARY KEY
pilot_id UUID, exam_type -- flight_review, roc_a, ground_school_test
scheduled_date, duration_minutes, location_type -- in_person, online
status -- pending, confirmed, completed, cancelled
stripe_payment_intent_id, stripe_charge_id, payment_amount
zoom_meeting_id, zoom_meeting_password
start_url TEXT -- Zoom host URL; SELECT revoked from authenticated role
examiner_id UUID, notes TEXT
```

### Marketplace

#### marketplace_listings (inferred structure)
```sql
id UUID PRIMARY KEY
seller_id UUID REFERENCES profiles
title, description TEXT, price NUMERIC
category -- 9 types
condition -- new, like_new, good, fair, parts_only
transaction_type -- ship, meetup, both
image_urls TEXT[], location TEXT
status -- active, sold, reserved, expired, removed
```

### Credentials

#### pilot_licenses
```sql
id UUID PRIMARY KEY
pilot_id UUID REFERENCES
license_type, file_url, file_type
uploaded_at TIMESTAMPTZ
```

#### license_approval_requests
```sql
id UUID PRIMARY KEY
pilot_id, license_id UUID REFERENCES
license_type, file_url
status -- pending, approved, rejected
submitted_at, reviewed_at, reviewed_by, reviewer_notes
-- Trigger: award_permit_badge_for_license_approval()
```

### Logs (Immutable)

#### flight_logs
```sql
id UUID PRIMARY KEY
pilot_id UUID, aircraft_number, sheet_number INT
description_of_flight, date TIMESTAMPTZ, time_out TIMESTAMPTZ, time_in TIMESTAMPTZ
total_airtime_minutes INT, comments TEXT
signature_data TEXT (base64 PNG)
is_locked BOOLEAN DEFAULT true
-- RLS: INSERT only, no UPDATE/DELETE
```

#### maintenance_logs, incident_logs
- Same immutability pattern as flight_logs
- Incident logs include: booking_id, witness info, police/ATC reporting flags

### Emergency & Volunteer

#### beacon_volunteers
```sql
id UUID PRIMARY KEY
pilot_id UUID UNIQUE REFERENCES
enrolled_at TIMESTAMPTZ, is_available BOOLEAN
last_location_lat, last_location_lng, last_location_update
notification_radius_miles INT
total_missions_completed, total_hours_volunteered, people_helped INT
-- Trigger: award_beacon_volunteer_badge()
```

#### beacon_training_progress
```sql
id UUID PRIMARY KEY
pilot_id UUID, training_type -- cpr, firefighting, cert (3 types)
certificate_url TEXT, uploaded_at TIMESTAMPTZ
expires_at TIMESTAMPTZ -- added for expiration tracking
verified BOOLEAN, verified_at TIMESTAMPTZ, verified_by UUID
-- No UNIQUE constraint (allows certificate history per type)
```

### Hangar Help Forum Tables

| Table | Purpose |
|-------|---------|
| `hangar_topics` | Forum categories: name, description, iconName, colorName, displayOrder, isActive. Seeded with 6 topics |
| `hangar_posts` | Forum posts: topicId, authorId, title, body, likeCount, commentCount, isPinned, imageUrls |
| `hangar_comments` | Threaded comments: postId, parentCommentId, authorId, body, likeCount, depth |
| `hangar_likes` | Likes on posts/comments (userId, postId/commentId mutually exclusive via CHECK) |
| `hangar_saved_posts` | User bookmarks of forum posts |
| `hangar_followed_posts` | User follows on forum posts for notifications |
| `hangar_hidden_posts` | User-hidden forum posts |
| `hangar_saved_comments` | User bookmarks of forum comments |
| `hangar_followed_comments` | User follows on forum comments |

### Marketplace Tables

| Table | Purpose |
|-------|---------|
| `marketplace_listings` | Listings: sellerId, title, description, price, category, condition, transactionType, imageUrls, locationName/Lat/Lng, brand, model, shippingCost, viewCount, favoriteCount, offerCount, status, expiresAt |
| `marketplace_favorites` | User-favorited listings (userId, listingId) |
| `marketplace_offers` | Buyer offers: listingId, buyerId, amount, message, status. UPDATE restricted to `status` column only via trigger |
| `marketplace_transactions` | Full transaction lifecycle: listingId, buyerId, sellerId, offerId, transactionType, status (10 values), amount, platformFee, sellerPayout, paymentIntentId, chargeId, transferId, tracking/meetup fields. INSERT/UPDATE policies set to `WITH CHECK (false)` — only service-role edge functions may modify |
| `marketplace_reviews` | Post-transaction reviews: transactionId, fromUserId, toUserId, rating (1-5), comment. INSERT enforces reviewer is participant |

### Utility Tables

| Table | Purpose |
|-------|---------|
| `device_tokens` | APNs device token storage (user_id, token, platform, is_active) |
| `notification_preferences` | Per-type notification toggles (19 types x system/email/text) |
| `hanger_talk_notification_preferences` | HangerTalk-specific notification preferences |
| `referral_codes` | 8-char alphanumeric referral codes |
| `referrals` | Referral tracking with credit amounts |
| `ticket_reports` | Unified ticket system: type (bug/safety/dispute), title, description, imageUrls, status, adminResponse, bookingId, reason. Note: `booking_disputes` was deleted and migrated into this table |
| `email_change_tokens` | Email change verification: userId, oldEmail, newEmail, 6-digit token, verified, expiresAt (30-min expiration) |
| `news_cache` | 30-min TTL cache for drone news by source |
| `booking_checklists` | Pre/post flight checklist booleans |
| `booking_config` | Singleton config (id='default'): supported specializations, service areas (JSONB), messages |
| `video_upload_reminders` | Dedup table for reminder scheduling |
| `badges` | Earned badges with expiration/recurrence |
| `badges_catalog` | Badge type definitions |
| `exam_type_config` | Exam metadata and pricing |
| `cockpit_usage_logs` | Feature analytics: userId, componentName, sectionName |
| `app_version_tracking` | Per-user version tracking: userId, platform, appVersion, lastSeenAt |
| `flight_hour_claims` | Bulk hour claims: pilotId, claimedFlights, claimedHours, notes, evidenceFiles, status, reviewer info |
| `license_notifications` | License approval event notifications: recipientId, type (pre_approved/approved/rejected), licenseId, title, body, isRead |

---

## 12. Row Level Security

### RLS Patterns

| Pattern | Tables | Policy |
|---------|--------|--------|
| **Public Read + Auth Write** | hanger_talk_posts, likes, reposts, follows, mentions | Anyone reads; authenticated users create/delete own |
| **Self-Only** | profiles, device_tokens, notification_preferences | Users manage only their own records |
| **Conversation Participants** | messages, direct_messages, reactions | Only from/to users access |
| **Booking Participants** | booking_crew, booking_checklists | Pilot + customer of the booking |
| **Immutable** | flight_logs, maintenance_logs, incident_logs | INSERT only, no UPDATE/DELETE |
| **Role-Based** | ticket_reports (unified: bugs, safety, disputes) | Users create; admins manage |
| **Service Role Bypass** | All tables | Edge functions use service role key |

### Critical Security Policies
- Log tables (flight, maintenance, incident): **INSERT only by pilot, no updates or deletes**
- `marketplace_transactions`: INSERT/UPDATE set to `WITH CHECK (false)` — only service-role edge functions may modify
- `marketplace_offers`: UPDATE restricted to `status` column only via trigger; accept/decline = seller only, withdraw = buyer only
- `marketplace_listings`: Sellers can see own non-active listings (`status = 'active' OR seller_id = auth.uid()`)
- `exam_appointments`: Column-level REVOKE of `SELECT (start_url)` from `authenticated` role (Zoom host URL protection)
- Email change tokens: 30-minute expiration, user-scoped
- Referral codes: Public lookup for validation, personal codes private
- License approval: Only admins can update approval status
- Storage: Folder-scoped uploads (`{userId}/filename`)

---

## 13. Database Functions & Triggers

### Count Tracking Triggers
| Trigger | Table | Updates |
|---------|-------|---------|
| `hanger_talk_like_count_trigger` | `hanger_talk_likes` | `posts.like_count` |
| `hanger_talk_reply_count_trigger` | `hanger_talk_posts` (is_reply) | `posts.reply_count` |
| `hanger_talk_repost_count_trigger` | `hanger_talk_reposts` | `posts.repost_count` |
| `hanger_space_participant_count_trigger` | `hanger_space_participants` | `spaces.listener_count, speaker_count` (handles INSERT, DELETE, and UPDATE/role changes) |
| `hangar_post_like_count_trigger` | `hangar_likes` | `hangar_posts.like_count` (Hangar Help) |
| `hangar_comment_like_count_trigger` | `hangar_likes` | `hangar_comments.like_count` (Hangar Help) |
| `hangar_post_comment_count_trigger` | `hangar_comments` | `hangar_posts.comment_count` (Hangar Help) |
| `trigger_update_listing_favorite_count` | `marketplace_favorites` | `marketplace_listings.favorite_count` |
| `trigger_update_listing_offer_count` | `marketplace_offers` | `marketplace_listings.offer_count` |

### Badge Award Triggers
| Trigger | Fires On | Awards |
|---------|----------|--------|
| `trigger_award_permit_badge_approval` | `license_approval_requests` UPDATE to 'approved' | flight_reviewer or roc_a_examiner badge |
| `trigger_award_beacon_training_badge` | `beacon_training_progress` INSERT/UPDATE | first_aid, basic_firefighter, or cert badge |
| `trigger_credit_referrer_on_verification` | `government_ids` INSERT/UPDATE | $25 referral credit |

### Validation & Protection Triggers
| Trigger | Fires On | Purpose |
|---------|----------|---------|
| `trigger_validate_course_enrollment` | `course_enrollments` INSERT | Ground school, flight review, ROC-A prerequisites; Academy Pass subscription |
| `trigger_protect_exam_payment_fields` | `exam_appointments` UPDATE | Prevents pilots from modifying payment fields and pilot_id |
| `trigger_prevent_last_minute_reschedule` | `exam_appointments` UPDATE | Enforces 24-hour reschedule cutoff |
| `trigger_marketplace_offers_restrict_update` | `marketplace_offers` UPDATE | Prevents changing any column except `status` |

### Auto-Updated Timestamps
Triggers that auto-set `updated_at` on INSERT/UPDATE:
- `booking_config`, `booking_checklists`, `ticket_reports`, `exam_appointments`, `course_sections`
- `marketplace_listings`, `marketplace_offers`, `marketplace_transactions`
- `booking_message_reactions`, `direct_message_reactions`

### Utility Functions

| Function | Returns | Purpose |
|----------|---------|---------|
| `get_rank_payout(rank_tier)` | NUMERIC | Fixed payout by automotive rank ($350-$650) |
| `get_search_rescue_payout(hours, rate)` | NUMERIC | hours x rate calculation |
| `calculate_search_rescue_total(booking_id, hours)` | TABLE | Total amount, pilot count, per-pilot amount |
| `join_search_rescue_booking(booking_id, pilot_id)` | JSON | Crew insertion with validation |
| `leave_automotive_booking(booking_id, pilot_id)` | JSONB | Remove pilot from crew; promote next highest-ranked to lead |
| `withdraw_from_booking(booking_id, pilot_id)` | JSONB | Non-crew single-pilot withdrawal; reverts booking to 'available' |
| `check_beacon_training_complete(pilot_id)` | BOOLEAN | Requires CPR + Firefighting + CERT (3 types, all non-expired) |
| `enroll_beacon_volunteer(pilot_id)` | BOOLEAN | Validate training, insert volunteer, update profile |
| `find_nearby_beacon_volunteers(lat, lng, radius)` | TABLE | Haversine distance query |
| `get_latest_beacon_training(pilot_id)` | SETOF | Latest certificate per training_type (DISTINCT ON) |
| `sync_badges_to_beacon_training(pilot_id)` | VOID | Backfill training progress from badges |
| `pilot_has_active_academy_pass(pilot_id)` | BOOLEAN | Check active/trialing subscriptions |
| `course_is_subscription_exempt(course_id)` | BOOLEAN | Check if course is free |
| `submit_test_result_upload(...)` | UUID | Upsert test_result with file URLs and 'pending' status |
| `approve_test_result(result_id, reviewer_id, score, notes)` | BOOLEAN | Admin-only (EXECUTE revoked from `authenticated`) |
| `reject_test_result(result_id, reviewer_id, notes)` | BOOLEAN | Admin-only (EXECUTE revoked from `authenticated`) |
| `marketplace_confirm_meetup(transaction_id)` | VOID | Dual-confirm meetup; transitions to `meetup_completed` when both confirm |
| `upsert_device_token(user_id, token, platform)` | UUID | Insert or update device token |
| `get_user_device_tokens(user_id)` | TABLE | Active tokens for user |
| `cleanup_expired_email_tokens()` | VOID | Delete unverified tokens > 30 min |
| `get_pilots_needing_video_upload_reminder()` | TABLE | Pilots needing 24-72h reminders |
| `record_video_upload_reminder(booking_id, pilot_id, type)` | UUID | Inserts dedup reminder record |

---

## 14. Storage Buckets

| Bucket | Content | Path Pattern | Access |
|--------|---------|-------------|--------|
| `hanger_talk_images` | HangerTalk social feed images | `{user_id}/{uuid}.jpg` | Auth upload own folder; public read |
| `hanger_images` | Hangar Help forum post images | `{user_id}/{uuid}` | Auth upload own; public read; 10MB limit |
| `certificates` | Beacon training certs | `beacon-certificates/{user_id}/{filename}` | Auth upload own; public read; 5MB limit |
| `profile-pictures` | User avatars | `{user_id}/profile.jpg` | Auth upload own; public read |
| `booking_media_files` | Booking videos/photos | `{booking_id}/{filename}` | Participant access |
| `course-test-results` | Exam result uploads | `{pilot_id}/{filename}` | Auth upload own |
| `marketplace-images` | Marketplace listing images | `{user_id}/{uuid}` | Public bucket |
| `bug-report-images` | Ticket report attachments | `{user_id}/{uuid}` | Auth upload own; 10MB limit; JPEG/PNG/HEIC/HEIF |
| `flight-hour-claims` | Flight hour claim evidence | `{pilot_id}/{filename}` | Auth upload own |

---

## 15. Third-Party Integrations

| Service | Purpose | Integration Point |
|---------|---------|-------------------|
| **Supabase** | Backend (DB, Auth, Storage, Functions, Realtime) | SupabaseClient singleton |
| **Stripe** | Payment processing (8 SPM sub-packages: Stripe, StripeApplePay, StripeCardScan, StripeConnect, StripeFinancialConnections, StripeIdentity, StripePaymentSheet, StripePaymentsUI) | Edge functions (server-side), publishable key (client) |
| **Stripe Connect** | Pilot payouts | Edge functions for account management |
| **Stripe Identity** | ID verification | Edge functions + ProfilePictureService selfie flow |
| **Apple Sign-In** | Authentication | AuthService |
| **Google Sign-In** | Authentication | AuthService + GIDSignIn + GoogleSignInSwift (SwiftUI button) |
| **StoreKit** | In-app purchases (Academy Pass) | StoreKitManager |
| **LiveKit** | Real-time audio rooms | Edge function for tokens; client-sdk-swift for audio |
| **Shopify** | Merchandise store | ShopifyService (Storefront GraphQL API) |
| **ArcGIS** | Airspace mapping | ArcGISAirspaceService |
| **NOAA NWS** | Weather data | WeatherService (api.weather.gov) |
| **Open-Meteo** | Weather fallback (global) | WeatherService (api.open-meteo.com) |
| **APNs** | Push notifications | NotificationManager via edge function |
| **Zoom** | Online exam meetings | Edge function for meeting creation |
| **CoreLocation** | GPS location | LocationTrackingService |
| **PencilKit** | Digital signatures | SignatureCanvasView (PKCanvasView, PKDrawing) |
| **PDFKit** | Document viewing/generation | FileViewer (PDFViewRepresentable), SiteSurveyService |
| **Vision** | On-device OCR | OCRService (VNRecognizeTextRequest) |
| **CryptoKit** | File cache keys | FileViewer (SHA256 hashing) |
| **BackgroundTasks** | NWS alert polling | BuzzApp.swift (BGAppRefreshTask) |

**Dependency Management:** All external dependencies managed via **Swift Package Manager** (SPM) in Xcode project. No CocoaPods or Carthage.

---

## 16. Business Logic & Workflows

### Booking Lifecycle
```
Customer creates booking (specialization, location, payment)
    → status: AVAILABLE
    → Pilot accepts
    → status: ACCEPTED
    → (Automotive/S&R: additional crew joins)
    → status: STAFFED (crew full)
    → Pilot starts mission
    → status: IN_PROGRESS
    → Pilot completes mission
    → status: COMPLETED
    → Stripe transfer to pilot(s)
    → Rating exchange
```

### Automotive Multi-Crew
1. First pilot accepts (lead), booking → `accepted`
2. Up to 3 crew join via `join-automotive-booking`
3. Rank determines fixed payout: Sublieutenant=$350, Lieutenant=$450, Commander=$550, Captain=$650
4. On completion, `create-transfer` initiates per-pilot payouts

### Search & Rescue
1. Booking created with `is_voluntary` flag and `hourly_rate`
2. All pilots join as `crew` (no lead designation)
3. Client enters `final_hours_worked` on completion
4. Payout = `final_hours_worked × hourly_rate` (equal split)

### Referral System
1. User A calls `generate-referral-code` → unique 8-char code
2. User B signs up with code → `referred_by` set to User A
3. User B completes government ID verification
4. Trigger `credit_referrer_on_verification` awards $25 to User A's `referral_credits`
5. User A applies credits to bookings via `apply-booking-credits`

### Academy Pass Subscription
1. User subscribes via StoreKit (Apple) or Stripe (web)
2. `EntitlementManager` checks both sources (Apple first, then Supabase `course_subscriptions`)
3. Enrollment trigger validates: `pilot_has_active_academy_pass()` OR `course_is_subscription_exempt()`
4. Exempt: external URL courses, Buzz-provider courses, free exam sections

### License Approval
1. Pilot uploads license → `pilot_licenses` table
2. Approval request created → `license_approval_requests` (status: pending)
3. Admin reviews via `update-license-approval` edge function
4. On approval: trigger awards `flight_reviewer` or `roc_a_examiner` badge
5. `license_notification` inserted for pilot

### Beacon Volunteer Program
1. Pilot uploads CPR + Firefighting certificates → `beacon_training_progress`
2. `check_beacon_training_complete()` validates both present
3. `enroll_beacon_volunteer()` creates volunteer record, updates profile
4. Trigger awards `beacon_volunteer` badge
5. `find_nearby_beacon_volunteers()` discovers available volunteers (Haversine)
6. Emergency bookings notify nearby volunteers with critical-level push

### Exam Workflow
1. Pilot selects exam type → `ExamIntroView`
2. Schedules appointment (in-person or online) → `ExamSchedulingView`
3. Creates Stripe payment → `create-exam-payment` edge function
4. Appointment created → `exam_appointments` (status: pending)
5. Payment confirmed → status: confirmed
6. Online: Zoom meeting created → `create-zoom-meeting`
7. Examiner completes → status: completed
8. Passed: badge awarded via trigger

---

## 17. Shared Components & Utilities

### Global Utilities (`Buzz/Views/Shared/HangerSharedComponents.swift`)

#### `hangerTimeAgo(_ date: Date) -> String`
Relative time formatting: "Just Now" → "2m" → "3h" → "5d" → "2w" → "3mo" → "1y"

#### `MentionText`
Read-only `@callSign` mention rendering with blue highlight.

#### `TappableMentionText`
Interactive mentions using `buzzmention://` URL scheme for profile navigation. Note: `buzzmention://` is handled internally via SwiftUI `OpenURLAction`, NOT registered in Info.plist.

#### `HangerImageCarousel`
Swipeable image gallery: single image (direct display), multiple (TabView with counter badge).

### Shared Views (`Buzz/Views/Shared/`)

| Component | Purpose |
|-----------|---------|
| `LiveRingView` | Animated pulsing circle with gradient for "LIVE" indicators |
| `MessageReactionUI` | `MessageReactionBadges` (display) + `MessageReactionPickerOverlay` (picker) + `MessageBubbleFramePreferenceKey` (PreferenceKey for overlay positioning) + `captureMessageBubbleFrame()` View extension |
| `HelpCenterArticleComponents` | In-app help mini-framework: `HelpCenterCategory` enum (5 categories with title/icon/color), `HelpCenterArticle` struct, rendering views |

### Reusable Components (`Buzz/Views/Components/`)

| Component | Purpose |
|-----------|---------|
| `CustomButton` | Styled button (primary/secondary/destructive) with loading state |
| `LoadingView` | Centered spinner with message |
| `EmptyStateView` | Placeholder with icon, title, message, optional action |
| `ErrorView` | Error display component |
| `RatingView` | Interactive star rating (0-5) + `StarRatingView` (read-only) + `CustomTipSheet` + `TipPercentageButton` (5%/10%/15% presets) |
| `SignatureCanvasView` | Digital signature capture via PencilKit (`PKCanvasView`, base64 PNG) |
| `FileViewer` | Document preview with local caching (SHA-256 keyed, 30-day expiry, ETag/Last-Modified conditional validation) + `PDFViewRepresentable` + `ZoomableImageView` (pinch-to-zoom) + `DownloadDelegate` (progress tracking) |
| `UpdatePopupView` | App update notification overlay |
| `SubscriptionStatusView` | Subscription status display + `SubscriptionManagementView` (links to App Store or `academy.buzzbuzin.com/account` depending on source) |

### Utilities (`Buzz/Utilities/`)

| Utility | Purpose |
|---------|---------|
| `MentionParser` | Regex-based @mention parsing (extract, query, segments) |
| `CallSignValidator` | Call sign format validation |
| `StoreKitExtensions` | `Product.SubscriptionPeriod` and `Transaction` display extensions |

### ViewModels (`Buzz/ViewModels/`)

| ViewModel | Purpose |
|-----------|---------|
| `SlideshowViewModel` | Converts `[CourseMaterial]` to typed `SlideContent` enums. Sequential completion gating (must complete each slide before advancing). Proactive next-image preloading. Exposes `progressPercentage` (position) and `completionPercentage` (completion) separately. Calls `onComplete` only when all slides completed |

---

## 18. Testing Infrastructure

### Test Structure
- **Unit Tests:** `BuzzTests/` — 54 flat Swift files (no subdirectory structure), using **Swift Testing** framework (`@Test`, `#expect`), NOT XCTest
- **UI Tests:** `BuzzUITests/` — currently a stub (single empty `@Test func example()`)
- **Location Testing:** `BuzzTests/README.md` contains a guide for using `LocationTestHelper.swift` to set simulator GPS coordinates

### Demo Mode for Testing
- `DemoModeManager.shared.isDemoModeEnabled` bypasses all Supabase calls
- Services return static demo data with simulated delays
- UI tests set `UITEST_MODE`, `UITEST_USER_ID`, `UITEST_ROLE` environment variables

### Protocol-Based Testability
`BookingService` uses dependency injection:
- `BookingBackend` protocol for database operations
- `BookingNotificationManaging` protocol for notifications
- `NotificationPreferencesProviding` protocol for preferences
- Enables mock implementations for isolated testing

---

## 19. Configuration & Environment

### Config.swift
```swift
struct Config {
    static let supabaseURL = "..."
    static let supabaseAnonKey = "..."
    static let googleClientID = "..."
    static let useStripeTestMode = false  // IMPORTANT: false = production live payments
    static var stripePublishableKey: String { useStripeTestMode ? testKey : liveKey }
    static let shopifyStoreURL = "..."
    static let shopifyStorefrontAccessToken = "..."  // Note: not "shopifyStorefrontToken"
    static let appleMerchantID = "merchant.com.buzz.app.ios"
    static let appStoreBundleID = "com.buzz.app.ios"
    static let stripeOnboardingReturnURL = "..."   // Return after completing onboarding
    static let stripeOnboardingRefreshURL = "..."  // Re-enter onboarding
}
```

### Info.plist Permissions
- Face ID (identity verification)
- Camera (government ID capture for Stripe Identity — declared in build settings, not Info.plist XML)
- Location Services (weather, maps, beacon)
- Notifications (push, local)
- Calendar (exam scheduling)
- Microphone (Hanger Spaces audio)
- Background Modes: audio, fetch, remote-notification
- `ITSAppUsesNonExemptEncryption = false` (App Store export compliance)

### URL Schemes
- `buzz://` - Deep linking (registered in Info.plist)
- `buzzmention://` - @mention profile navigation (handled internally via SwiftUI `OpenURLAction`, NOT registered in Info.plist)

### Background Tasks
- `com.buzz.app.ios.nws-alert-check` - NWS weather alert polling

### Build Configuration
- Simulator: `iPhone 17 Pro, OS=26.2`
- Scheme: `Buzz`
- Swift Package Manager for all external dependencies

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        iOS App (SwiftUI)                        │
├─────────────────────────────────────────────────────────────────┤
│  Views Layer (180+ views)                                       │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐          │
│  │ Cockpit  │ │ Bookings │ │ Academy  │ │ Profile  │ ...      │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘          │
│       │             │            │             │                 │
├───────┼─────────────┼────────────┼─────────────┼─────────────────┤
│  Services Layer (80+ @MainActor ObservableObject services)      │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐          │
│  │ Auth     │ │ Booking  │ │ Hanger   │ │ Weather  │ ...      │
│  │ Service  │ │ Service  │ │ Talk Svc │ │ Service  │          │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘          │
│       │             │            │             │                 │
├───────┼─────────────┼────────────┼─────────────┼─────────────────┤
│  Models Layer (54 Codable structs)                              │
│  UserProfile, Booking, HangerTalkPost, TrainingCourse, ...      │
├───────┼─────────────┼────────────┼─────────────┼─────────────────┤
│  Managers (Singletons)                                          │
│  SupabaseClient │ NotificationManager │ DemoModeManager │ ...   │
└───────┼─────────────┼────────────┼─────────────┼─────────────────┘
        │             │            │             │
        ▼             ▼            ▼             ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Supabase Backend                            │
├──────────────┬───────────────┬──────────────┬───────────────────┤
│  PostgreSQL  │ Edge Functions│  Storage     │  Realtime         │
│  (108 migr.) │ (50+ Deno)   │ (4 buckets)  │ (3 tables)        │
│              │               │              │                   │
│  30+ tables  │ Stripe, APNs │ Images,      │ hanger_spaces,    │
│  20+ triggers│ LiveKit, Zoom │ Certificates │ participants,     │
│  15+ RPCs    │ NOAA, News   │              │ speaker_requests  │
└──────┬───────┴───────┬───────┴──────────────┴───────────────────┘
       │               │
       ▼               ▼
┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│   Stripe     │ │   LiveKit    │ │   Shopify    │
│ (Payments,   │ │ (Audio       │ │ (Storefront  │
│  Connect,    │ │  Rooms)      │ │  API)        │
│  Identity)   │ │              │ │              │
└──────────────┘ └──────────────┘ └──────────────┘
```
