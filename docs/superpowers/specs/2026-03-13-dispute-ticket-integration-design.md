# Dispute-Ticket Integration Design

Integrate the standalone booking dispute system into the unified `ticket_reports` backend, so disputes are handled identically to bug reports and safety reports.

## Context

Currently disputes live in a separate `booking_disputes` table with their own model (`BookingDispute`), service methods (4 methods in `BookingService`), and 3 standalone views. Bug reports and safety reports share a unified `ticket_reports` table with a `type` discriminator, a single `TicketReportService`, and a shared set of views. This design unifies disputes into that same system.

## Decisions

- **Approach:** Extend `ticket_reports` with two nullable columns (`booking_id`, `reason`) rather than a join table or JSON metadata. Two nullable columns is consistent with how `Booking` handles optional fields throughout the codebase.
- **Entry points:** Both from `BookingDetailView`/`CustomerBookingView` (pre-filled booking context) AND from the Help section (browse/manage all disputes).
- **Form UX:** Disputes use a reason picker (auto-generates title) instead of the free-text title field used by bug/safety reports. Description and photo upload remain the same.
- **Data migration:** Migrate existing `booking_disputes` rows into `ticket_reports`, then drop the old table. Clean break.
- **Status mapping:** `open` → `open`, `under_review` → `in_progress`, `resolved` → `resolved`, `dismissed` → `closed`.

## 1. Database Migration

Single migration file: `supabase/migrations/20260313_integrate_disputes_into_tickets.sql`

### Schema changes to `ticket_reports`

```sql
ALTER TABLE ticket_reports ADD COLUMN booking_id UUID REFERENCES bookings(id) ON DELETE CASCADE;
ALTER TABLE ticket_reports ADD COLUMN reason TEXT;
```

Update the type CHECK constraint to allow `'dispute'`:

```sql
ALTER TABLE ticket_reports DROP CONSTRAINT IF EXISTS ticket_reports_type_check;
ALTER TABLE ticket_reports ADD CONSTRAINT ticket_reports_type_check CHECK (type IN ('bug', 'safety', 'dispute'));
```

### Data migration from `booking_disputes`

```sql
INSERT INTO ticket_reports (id, user_id, type, title, description, status, admin_response, image_urls, booking_id, reason, created_at, updated_at)
SELECT
    id,
    initiated_by,
    'dispute',
    CASE reason
        WHEN 'incorrect_charge' THEN 'Incorrect Charge'
        WHEN 'service_not_provided' THEN 'Service Not Provided'
        WHEN 'quality_issue' THEN 'Quality Issue'
        WHEN 'safety_concern' THEN 'Safety Concern'
        WHEN 'other' THEN 'Other'
        ELSE initcap(replace(reason, '_', ' '))
    END,
    COALESCE(description, ''),
    CASE status
        WHEN 'open' THEN 'open'
        WHEN 'under_review' THEN 'in_progress'
        WHEN 'resolved' THEN 'resolved'
        WHEN 'dismissed' THEN 'closed'
        ELSE 'open'
    END,
    resolution,
    '{}',
    booking_id,
    reason,
    created_at,
    COALESCE(resolved_at, created_at)
FROM booking_disputes;
```

### Drop old table

```sql
DROP TABLE booking_disputes;
```

### RLS updates

Replace the existing INSERT policy to enforce booking ownership for dispute tickets. The existing policy (`WITH CHECK (auth.uid() = user_id)`) would allow any user to insert a dispute for any booking, bypassing the ownership check, since PostgreSQL OR's together all permissive policies.

```sql
-- Drop existing INSERT policy
DROP POLICY IF EXISTS "Users can create ticket reports" ON ticket_reports;

-- Recreated: non-dispute tickets require user_id match; dispute tickets also require booking ownership
CREATE POLICY "Users can create ticket reports"
ON ticket_reports FOR INSERT
WITH CHECK (
    auth.uid() = user_id
    AND (
        type != 'dispute'
        OR (
            booking_id IS NOT NULL
            AND EXISTS (
                SELECT 1 FROM bookings
                WHERE bookings.id = ticket_reports.booking_id
                AND (bookings.customer_id = auth.uid() OR bookings.pilot_id = auth.uid())
            )
        )
    )
);
```

## 2. Model Changes

### `Buzz/Models/BugReport.swift`

**`TicketReportType`** — add `.dispute` case:

```swift
case dispute
```

With display strings:
- `listTitle`: "Booking Disputes"
- `createTitle`: "File a Dispute"
- `detailTitle`: "Dispute Details"
- `submitButtonTitle`: "Submit Dispute"
- `emptyStateTitle`: "No Disputes"
- `emptyStateMessage`: "You haven't filed any disputes"
- `icon`: "exclamationmark.bubble.fill"
- `titlePlaceholder`: "" (unused — title auto-generated from reason)
- `descriptionPlaceholder`: "Please describe the issue in detail..."
- `successAlertTitle`: "Dispute Filed"
- `successAlertMessage`: "Your dispute has been submitted and is under review."
- `loadingMessage`: "Loading disputes..."

**`TicketReport`** — add optional fields:

```swift
var bookingId: UUID?   // CodingKey: "booking_id"
var reason: String?    // CodingKey: "reason"
```

Update `init(from:)` to decode both as optional via `decodeIfPresent`.

**`TicketReportInsert`** — add optional fields:

```swift
var bookingId: UUID?   // CodingKey: "booking_id"
var reason: String?    // CodingKey: "reason"
```

### `Buzz/Models/Booking.swift`

- **Keep** `DisputeReason` enum (used by the reason picker in the create form)
- **Add `displayName` computed property** to `DisputeReason` for auto-generating dispute titles:
  - `.incorrectCharge` → "Incorrect Charge"
  - `.serviceNotProvided` → "Service Not Provided"
  - `.qualityIssue` → "Quality Issue"
  - `.safetyConcern` → "Safety Concern"
  - `.other` → "Other"
- **Delete** `DisputeStatus` enum
- **Delete** `BookingDispute` struct

## 3. Service Changes

### `Buzz/Services/BugReportService.swift`

Add method to `TicketReportService`:

```swift
func submitDispute(bookingId: UUID, reason: DisputeReason, description: String?, images: [UIImage] = []) async throws -> TicketReport
```

Implementation:
1. Get authenticated user ID
2. Upload images via existing `uploadReportImages()`
3. Auto-generate title from `reason.displayName` (where `displayName` is computed from `DisputeReason` — e.g., `.incorrectCharge` → "Incorrect Charge")
4. Insert into `ticket_reports` with `type: .dispute`, `bookingId`, `reason: reason.rawValue`, generated title, description (defaulting to empty string if nil)
5. Return the created `TicketReport`
6. Demo mode handling: return a demo `TicketReport` or throw, consistent with existing `submitReport()`

### `Buzz/Services/BookingService.swift`

Delete:
- `@Published var disputes: [BookingDispute]`
- `createDispute()`
- `fetchDisputesForBooking()`
- `fetchMyDisputes()`
- `resolveDispute()`

## 4. View Changes

### Delete files

- `Buzz/Views/Bookings/CreateDisputeView.swift`
- `Buzz/Views/Bookings/DisputeDetailView.swift`
- `Buzz/Views/Bookings/DisputeListView.swift`

### `Buzz/Views/Profile/BugReportView.swift`

**`CreateTicketReportView`:**
- Add optional `bookingId: UUID?` parameter (nil for bug/safety, required for disputes)
- Add `@State private var selectedReason: DisputeReason = .incorrectCharge`
- When `reportType == .dispute`: show `DisputeReason` picker instead of the title text field
- On submit for disputes: call `reportService.submitDispute(bookingId:reason:description:images:)`
- On submit for bug/safety: call existing `reportService.submitReport()` (unchanged)
- **Fix submit button disabled state:** The existing `isDisabled` check requires `title` to be non-empty. For disputes (where title is auto-generated), skip the title emptiness check — only require description to be non-empty.

**`TicketReportDetailView`:**
- When report has a non-nil `reason`: show a "Reason" labeled section displaying the human-readable reason via `DisputeReason(rawValue: reason)?.displayName`, falling back to `reason.capitalized` for unknown values
- Everything else (status badge, description, screenshots, admin response, timeline) works as-is

### `Buzz/Views/Bookings/BookingDetailView.swift`

- Add `@StateObject private var reportService = TicketReportService()`
- Change `.sheet(isPresented: $showCreateDisputeSheet)` to present `CreateTicketReportView(reportService: reportService, reportType: .dispute, bookingId: currentBooking.id)` instead of `CreateDisputeView(bookingId:)`

### `Buzz/Views/Bookings/CustomerBookingView.swift`

- Same changes as `BookingDetailView` above

### `Buzz/Views/Bookings/CustomerActivityView.swift`

- Change `CompletedBookingCard` parameter from `disputes: [BookingDispute]` to `disputes: [TicketReport]`
- Update `hasDispute` check: filter by `report.bookingId == booking.id` instead of `dispute.bookingId == booking.id`
- Replace `bookingService.fetchMyDisputes()` call in `loadBookings()` with `reportService.fetchMyReports(type: .dispute)`
- Add `@StateObject private var reportService = TicketReportService()` and pass `reportService.reports` as the disputes parameter

### `Buzz/Views/Profile/HelpView.swift`

- Add a third navigation row: "File a booking dispute" with icon `exclamationmark.bubble.fill` → `TicketReportListView(reportType: .dispute)`

### `Buzz/Views/Profile/BugReportView.swift` — `TicketReportListView` FAB behavior

- When `reportType == .dispute` and no `bookingId` is available (i.e., entered from HelpView), hide the FAB button. Users can only browse existing disputes from this entry point. Creating new disputes requires going through a specific booking's detail view.
- The FAB remains visible for `.bug` and `.safety` types (unchanged behavior).

## 5. Files Changed Summary

| File | Action |
|------|--------|
| `supabase/migrations/20260313_integrate_disputes_into_tickets.sql` | Create |
| `Buzz/Models/BugReport.swift` | Edit — add `.dispute` type, add `bookingId`/`reason` fields |
| `Buzz/Models/Booking.swift` | Edit — delete `DisputeStatus`, `BookingDispute`; keep `DisputeReason` |
| `Buzz/Services/BugReportService.swift` | Edit — add `submitDispute()` method |
| `Buzz/Services/BookingService.swift` | Edit — remove 4 dispute methods + `disputes` property |
| `Buzz/Views/Profile/BugReportView.swift` | Edit — adapt create/detail views for dispute type |
| `Buzz/Views/Profile/HelpView.swift` | Edit — add dispute entry point |
| `Buzz/Views/Bookings/BookingDetailView.swift` | Edit — use `CreateTicketReportView` |
| `Buzz/Views/Bookings/CustomerBookingView.swift` | Edit — use `CreateTicketReportView` |
| `Buzz/Views/Bookings/CustomerActivityView.swift` | Edit — update `CompletedBookingCard` to use `TicketReport` |
| `Buzz/Views/Bookings/CreateDisputeView.swift` | Delete |
| `Buzz/Views/Bookings/DisputeDetailView.swift` | Delete |
| `Buzz/Views/Bookings/DisputeListView.swift` | Delete |

## 6. Test Impact

- `BuzzTests/BookingServiceExtendedTests.swift` — remove dispute test methods: `testCreateDispute_demoMode_returnsDemoDispute`, `testFetchDisputesForBooking_demoMode_returnsEmptyArray`, `testFetchMyDisputes_demoMode_setsEmptyDisputes`, `testResolveDispute_demoMode_returnsWithoutError`
- `BuzzTests/BookingModelTests.swift` — remove `BookingDispute` tests
- `BuzzTests/TestHelpers.swift` — remove `sampleDispute()` factory method that returns `BookingDispute`
- `BuzzTests/MarketplaceModelTests.swift` — check for any `BookingDispute` references and remove
- Update or add tests for `TicketReportService.submitDispute()` if test coverage exists for `submitReport()`
