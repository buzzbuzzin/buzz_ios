# Dispute-Ticket Integration Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Unify the standalone booking dispute system into the existing `ticket_reports` backend so disputes, bug reports, and safety reports share one table, one service, and one set of views.

**Architecture:** Extend `ticket_reports` with two nullable columns (`booking_id`, `reason`), add `type = 'dispute'`, migrate existing data from `booking_disputes`, then drop the old table. Adapt `TicketReportService` and shared views to handle the dispute type. Remove all standalone dispute code.

**Tech Stack:** SwiftUI, Supabase (PostgREST + RLS), PostgreSQL

**Spec:** `docs/superpowers/specs/2026-03-13-dispute-ticket-integration-design.md`

---

## Chunk 1: Database + Models

### Task 1: Create the database migration

**Files:**
- Create: `supabase/migrations/20260313_integrate_disputes_into_tickets.sql`

- [ ] **Step 1: Write the migration file**

```sql
-- ============================================================================
-- Integrate Booking Disputes into Ticket Reports
-- Migration: 20260313_integrate_disputes_into_tickets.sql
-- Description: Adds booking_id and reason columns to ticket_reports,
--              migrates data from booking_disputes, drops old table,
--              and updates RLS policies.
-- ============================================================================

-- 1. Add new columns
ALTER TABLE ticket_reports ADD COLUMN booking_id UUID REFERENCES bookings(id) ON DELETE CASCADE;
ALTER TABLE ticket_reports ADD COLUMN reason TEXT;

-- 2. Update type constraint to allow 'dispute'
ALTER TABLE ticket_reports DROP CONSTRAINT IF EXISTS ticket_reports_type_check;
ALTER TABLE ticket_reports ADD CONSTRAINT ticket_reports_type_check CHECK (type IN ('bug', 'safety', 'dispute'));

-- 3. Migrate existing disputes
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

-- 4. Drop old table
DROP TABLE booking_disputes;

-- 5. Update RLS: replace INSERT policy to enforce booking ownership for disputes
DROP POLICY IF EXISTS "Users can create ticket reports" ON ticket_reports;

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

-- 6. Index for looking up disputes by booking
CREATE INDEX idx_ticket_reports_booking_id ON ticket_reports(booking_id) WHERE booking_id IS NOT NULL;
```

- [ ] **Step 2: Commit**

```bash
git add supabase/migrations/20260313_integrate_disputes_into_tickets.sql
git commit -m "feat: add migration to integrate disputes into ticket_reports"
```

---

### Task 2: Add `displayName` to `DisputeReason` and delete old dispute types

**Files:**
- Modify: `Buzz/Models/Booking.swift:443-484`

- [ ] **Step 1: Add `displayName` to `DisputeReason` and delete `DisputeStatus` + `BookingDispute`**

In `Buzz/Models/Booking.swift`, replace lines 443-484 (the entire `// MARK: - Booking Disputes` section) with:

```swift
// MARK: - Booking Disputes

enum DisputeReason: String, Codable {
    case incorrectCharge = "incorrect_charge"
    case serviceNotProvided = "service_not_provided"
    case qualityIssue = "quality_issue"
    case safetyConcern = "safety_concern"
    case other

    var displayName: String {
        switch self {
        case .incorrectCharge: return "Incorrect Charge"
        case .serviceNotProvided: return "Service Not Provided"
        case .qualityIssue: return "Quality Issue"
        case .safetyConcern: return "Safety Concern"
        case .other: return "Other"
        }
    }
}
```

This deletes `DisputeStatus` enum (lines 445-450) and `BookingDispute` struct (lines 460-484), and adds `displayName` to `DisputeReason`.

- [ ] **Step 2: Commit**

```bash
git add Buzz/Models/Booking.swift
git commit -m "feat: add displayName to DisputeReason, remove DisputeStatus and BookingDispute"
```

---

### Task 3: Extend `TicketReportType`, `TicketReport`, and `TicketReportInsert` for disputes

**Files:**
- Modify: `Buzz/Models/BugReport.swift:11-201`

- [ ] **Step 1: Add `.dispute` case to `TicketReportType`**

In `Buzz/Models/BugReport.swift`, add `case dispute` after `case safety` (line 13). Then add the `.dispute` case to every `switch` in the enum:

| Property | Value |
|----------|-------|
| `listTitle` | `"Booking Disputes"` |
| `createTitle` | `"File a Dispute"` |
| `detailTitle` | `"Dispute Details"` |
| `submitButtonTitle` | `"Submit Dispute"` |
| `emptyStateTitle` | `"No Disputes"` |
| `emptyStateMessage` | `"You haven't filed any disputes"` |
| `icon` | `"exclamationmark.bubble.fill"` |
| `titlePlaceholder` | `""` |
| `descriptionPlaceholder` | `"Please describe the issue in detail..."` |
| `successAlertTitle` | `"Dispute Filed"` |
| `successAlertMessage` | `"Your dispute has been submitted and is under review."` |
| `loadingMessage` | `"Loading disputes..."` |

- [ ] **Step 2: Add `bookingId` and `reason` to `TicketReport`**

In the `TicketReport` struct, add two optional properties after `updatedAt`:

```swift
var bookingId: UUID?
var reason: String?
```

Add CodingKeys:

```swift
case bookingId = "booking_id"
case reason
```

In `init(from decoder:)`, add after `updatedAt` decoding:

```swift
bookingId = try container.decodeIfPresent(UUID.self, forKey: .bookingId)
reason = try container.decodeIfPresent(String.self, forKey: .reason)
```

In the memberwise `init`, add parameters `bookingId: UUID? = nil, reason: String? = nil` and assign them.

- [ ] **Step 3: Add `bookingId` and `reason` to `TicketReportInsert`**

Add optional properties:

```swift
var bookingId: UUID?
var reason: String?
```

Add CodingKeys:

```swift
case bookingId = "booking_id"
case reason
```

- [ ] **Step 4: Commit**

```bash
git add Buzz/Models/BugReport.swift
git commit -m "feat: extend ticket models with dispute type, bookingId, and reason"
```

---

## Chunk 2: Service Changes

### Task 4: Add `submitDispute()` to `TicketReportService`

**Files:**
- Modify: `Buzz/Services/BugReportService.swift:56-78`

- [ ] **Step 1: Add `submitDispute` method**

Add the following method to `TicketReportService` after the existing `submitReport` method (after line 78):

```swift
func submitDispute(bookingId: UUID, reason: DisputeReason, description: String?, images: [UIImage] = []) async throws -> TicketReport {
    if DemoModeManager.shared.isDemoModeEnabled {
        try? await Task.sleep(nanoseconds: 500_000_000)
        throw NSError(domain: "TicketReportService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Disputes are not available in demo mode"])
    }

    guard let userId = try? await supabase.auth.session.user.id else {
        throw NSError(domain: "TicketReportService", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
    }

    let imageUrls = try await uploadReportImages(userId: userId, images: images)
    let insert = TicketReportInsert(
        userId: userId,
        type: .dispute,
        title: reason.displayName,
        description: description ?? "",
        imageUrls: imageUrls,
        bookingId: bookingId,
        reason: reason.rawValue
    )

    let report: TicketReport = try await supabase
        .from("ticket_reports")
        .insert(insert)
        .select()
        .single()
        .execute()
        .value

    reports.insert(report, at: 0)
    return report
}
```

- [ ] **Step 2: Commit**

```bash
git add Buzz/Services/BugReportService.swift
git commit -m "feat: add submitDispute method to TicketReportService"
```

---

### Task 5: Remove dispute methods from `BookingService`

**Files:**
- Modify: `Buzz/Services/BookingService.swift:50` (remove `disputes` property)
- Modify: `Buzz/Services/BookingService.swift:2381-2545` (remove 4 dispute methods)

- [ ] **Step 1: Remove `@Published var disputes` property**

In `Buzz/Services/BookingService.swift` line 50, delete:

```swift
@Published var disputes: [BookingDispute] = []
```

- [ ] **Step 2: Remove all dispute methods**

Delete the entire `// MARK: - Booking Disputes` section (lines 2381-2545), which contains:
- `createDispute(bookingId:reason:description:)`
- `fetchDisputesForBooking(bookingId:)`
- `fetchMyDisputes()`
- `resolveDispute(disputeId:resolution:)`

- [ ] **Step 3: Commit**

```bash
git add Buzz/Services/BookingService.swift
git commit -m "refactor: remove standalone dispute methods from BookingService"
```

---

## Chunk 3: View Changes

### Task 6: Adapt `CreateTicketReportView` for disputes

**Files:**
- Modify: `Buzz/Views/Profile/BugReportView.swift:246-415`

- [ ] **Step 1: Add `bookingId` and `selectedReason` state**

In `CreateTicketReportView` (line 246), add after the `reportType` property:

```swift
var bookingId: UUID? = nil
@State private var selectedReason: DisputeReason = .incorrectCharge
```

- [ ] **Step 2: Replace title field with reason picker when dispute**

In the body, replace the Title Field section (lines 262-273) with a conditional:

```swift
// Title / Reason Field
if reportType == .dispute {
    VStack(alignment: .leading, spacing: 8) {
        Text("Reason")
            .font(.subheadline)
            .foregroundColor(.secondary)

        Picker("Select a reason", selection: $selectedReason) {
            Text("Incorrect Charge").tag(DisputeReason.incorrectCharge)
            Text("Service Not Provided").tag(DisputeReason.serviceNotProvided)
            Text("Quality Issue").tag(DisputeReason.qualityIssue)
            Text("Safety Concern").tag(DisputeReason.safetyConcern)
            Text("Other").tag(DisputeReason.other)
        }
        .pickerStyle(.menu)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
} else {
    VStack(alignment: .leading, spacing: 8) {
        Text("Title")
            .font(.subheadline)
            .foregroundColor(.secondary)

        TextField(reportType.titlePlaceholder, text: $title)
            .textContentType(.none)
            .textFieldStyle(PlainTextFieldStyle())
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
    }
}
```

- [ ] **Step 3: Fix submit button disabled state**

Change the `isDisabled` condition (line 348) from:

```swift
isDisabled: isSubmitting || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
```

to:

```swift
isDisabled: isSubmitting || (reportType != .dispute && title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) || description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
```

- [ ] **Step 4: Update `submitReport` function to handle disputes**

Replace the `submitReport()` function (lines 390-414) with:

```swift
private func submitReport() {
    guard !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        return
    }

    if reportType != .dispute {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
    }

    isSubmitting = true

    Task {
        do {
            if reportType == .dispute, let bookingId = bookingId {
                _ = try await reportService.submitDispute(
                    bookingId: bookingId,
                    reason: selectedReason,
                    description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                    images: selectedImages
                )
            } else {
                _ = try await reportService.submitReport(
                    title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                    description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                    type: reportType,
                    images: selectedImages
                )
            }
            isSubmitting = false
            showSuccessAlert = true
        } catch {
            isSubmitting = false
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }
}
```

- [ ] **Step 5: Commit**

```bash
git add Buzz/Views/Profile/BugReportView.swift
git commit -m "feat: adapt CreateTicketReportView to handle dispute type with reason picker"
```

---

### Task 7: Adapt `TicketReportDetailView` to show dispute reason

**Files:**
- Modify: `Buzz/Views/Profile/BugReportView.swift:123-242`

- [ ] **Step 1: Add reason section to detail view**

In `TicketReportDetailView`, after the Title section (after line 150, after the Divider), add a conditional reason section:

```swift
// Reason (for disputes)
if let reason = report.reason, !reason.isEmpty {
    Divider()
        .padding(.horizontal)

    VStack(alignment: .leading, spacing: 8) {
        Label("Reason", systemImage: "questionmark.circle.fill")
            .font(.headline)
        Text(DisputeReason(rawValue: reason)?.displayName ?? reason.capitalized)
            .font(.body)
            .foregroundColor(.secondary)
    }
    .padding(.horizontal)
}
```

- [ ] **Step 2: Commit**

```bash
git add Buzz/Views/Profile/BugReportView.swift
git commit -m "feat: show dispute reason in TicketReportDetailView"
```

---

### Task 8: Hide FAB for dispute list when accessed from HelpView

**Files:**
- Modify: `Buzz/Views/Profile/BugReportView.swift:13-62`

- [ ] **Step 1: Conditionally hide the FAB**

In `TicketReportListView`, wrap the FAB button (lines 42-52) in a conditional:

```swift
if reportType != .dispute {
    // FAB
    Button(action: { showCreateSheet = true }) {
        Image(systemName: "plus")
            .font(.title2)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .frame(width: 56, height: 56)
            .background(Color.blue)
            .clipShape(Circle())
            .shadow(radius: 4)
    }
    .padding(20)
}
```

- [ ] **Step 2: Commit**

```bash
git add Buzz/Views/Profile/BugReportView.swift
git commit -m "feat: hide FAB for dispute list (disputes created from booking detail)"
```

---

### Task 9: Update `BookingDetailView` to use `CreateTicketReportView`

**Files:**
- Modify: `Buzz/Views/Bookings/BookingDetailView.swift:41,1029-1031`

- [ ] **Step 1: Add `TicketReportService` StateObject**

Add after the existing `@State` declarations (around line 41):

```swift
@StateObject private var reportService = TicketReportService()
```

- [ ] **Step 2: Update the sheet presentation**

Replace the dispute sheet (lines 1029-1031):

```swift
.sheet(isPresented: $showCreateDisputeSheet) {
    CreateDisputeView(bookingId: currentBooking.id)
}
```

with:

```swift
.sheet(isPresented: $showCreateDisputeSheet) {
    CreateTicketReportView(reportService: reportService, reportType: .dispute, bookingId: currentBooking.id)
}
```

- [ ] **Step 3: Commit**

```bash
git add Buzz/Views/Bookings/BookingDetailView.swift
git commit -m "refactor: use CreateTicketReportView for disputes in BookingDetailView"
```

---

### Task 10: Update `CustomerBookingView` to use `CreateTicketReportView`

**Files:**
- Modify: `Buzz/Views/Bookings/CustomerBookingView.swift:1322,1857-1859`

- [ ] **Step 1: Add `TicketReportService` StateObject**

Add after the existing `@State` declarations (around line 1322):

```swift
@StateObject private var reportService = TicketReportService()
```

- [ ] **Step 2: Update the sheet presentation**

Replace the dispute sheet (lines 1857-1859):

```swift
.sheet(isPresented: $showCreateDisputeSheet) {
    CreateDisputeView(bookingId: currentBooking.id)
}
```

with:

```swift
.sheet(isPresented: $showCreateDisputeSheet) {
    CreateTicketReportView(reportService: reportService, reportType: .dispute, bookingId: currentBooking.id)
}
```

- [ ] **Step 3: Commit**

```bash
git add Buzz/Views/Bookings/CustomerBookingView.swift
git commit -m "refactor: use CreateTicketReportView for disputes in CustomerBookingView"
```

---

### Task 11: Update `CustomerActivityView` to use `TicketReport` instead of `BookingDispute`

**Files:**
- Modify: `Buzz/Views/Bookings/CustomerActivityView.swift:41,61,80-84,89-95`

- [ ] **Step 1: Add `TicketReportService` and update `loadBookings`**

Add a `@StateObject` at the top of `CustomerActivityView`:

```swift
@StateObject private var reportService = TicketReportService()
```

Replace the `loadBookings()` function (lines 80-84):

```swift
private func loadBookings() async {
    guard let currentUser = authService.currentUser else { return }
    try? await bookingService.fetchMyBookings(userId: currentUser.id, isPilot: false)
    await reportService.fetchMyReports(type: .dispute)
}
```

- [ ] **Step 2: Update `CompletedBookingCard` references**

Change the calls passing `disputes: bookingService.disputes` (line 41) to:

```swift
CompletedBookingCard(booking: booking, disputes: reportService.reports)
```

Line 61 already passes `disputes: []` — leave it as-is but update the type (handled in next step).

- [ ] **Step 3: Update `CompletedBookingCard` struct**

Change the `disputes` parameter type (line 91) from:

```swift
var disputes: [BookingDispute] = []
```

to:

```swift
var disputes: [TicketReport] = []
```

Update `hasDispute` (lines 93-95) from:

```swift
private var hasDispute: Bool {
    disputes.contains { $0.bookingId == booking.id }
}
```

to:

```swift
private var hasDispute: Bool {
    disputes.contains { $0.bookingId == booking.id }
}
```

(The logic is the same since `TicketReport` now has `bookingId`. No change needed to the body of this computed property.)

- [ ] **Step 4: Commit**

```bash
git add Buzz/Views/Bookings/CustomerActivityView.swift
git commit -m "refactor: use TicketReport instead of BookingDispute in CustomerActivityView"
```

---

### Task 12: Add dispute entry point in HelpView

**Files:**
- Modify: `Buzz/Views/Profile/HelpView.swift:40-41`

- [ ] **Step 1: Add dispute navigation row**

After the safety report row (after line 40), add:

```swift
// File a booking dispute
NavigationLink(destination: TicketReportListView(reportType: .dispute)) {
    HelpCard(
        icon: "exclamationmark.bubble.fill",
        title: "File a booking dispute",
        description: "View and manage disputes on your bookings"
    )
}
```

- [ ] **Step 2: Commit**

```bash
git add Buzz/Views/Profile/HelpView.swift
git commit -m "feat: add booking dispute entry point in HelpView"
```

---

## Chunk 4: Cleanup + Tests

### Task 13: Delete standalone dispute view files

**Files:**
- Delete: `Buzz/Views/Bookings/CreateDisputeView.swift`
- Delete: `Buzz/Views/Bookings/DisputeDetailView.swift`
- Delete: `Buzz/Views/Bookings/DisputeListView.swift`

- [ ] **Step 1: Delete the three files**

```bash
git rm Buzz/Views/Bookings/CreateDisputeView.swift
git rm Buzz/Views/Bookings/DisputeDetailView.swift
git rm Buzz/Views/Bookings/DisputeListView.swift
```

- [ ] **Step 2: Remove files from the Xcode project if needed**

Check if these files are referenced in the `.pbxproj`. If the project uses automatic file discovery (no explicit file references), skip this. Otherwise remove the references.

- [ ] **Step 3: Commit**

```bash
git commit -m "refactor: delete standalone dispute views (replaced by ticket system)"
```

---

### Task 14: Clean up test files

**Files:**
- Modify: `BuzzTests/BookingServiceExtendedTests.swift:637-705`
- Modify: `BuzzTests/BookingModelTests.swift:201-282`
- Modify: `BuzzTests/TestHelpers.swift:194-217`

- [ ] **Step 1: Remove dispute test methods from `BookingServiceExtendedTests.swift`**

Delete lines 637-705 (the four methods):
- `testCreateDispute_demoMode_returnsDemoDispute`
- `testFetchDisputesForBooking_demoMode_returnsEmptyArray`
- `testFetchMyDisputes_demoMode_setsEmptyDisputes`
- `testResolveDispute_demoMode_returnsWithoutError`

- [ ] **Step 2: Remove dispute tests from `BookingModelTests.swift`**

Delete lines 150-173 (`DisputeStatus` tests — enum is deleted):
- `testDisputeStatusRawValues`
- `testDisputeStatusDecodesFromJSON`

Keep lines 175-200 (`DisputeReason` tests — enum is retained).

Delete lines 201-282 (`BookingDispute` model tests):
- `testBookingDisputeCodableRoundtrip`
- `testBookingDisputeCodingKeys_snakeCaseMapping`
- `testBookingDisputeResolvedFields`

- [ ] **Step 3: Remove `sampleDispute` from `TestHelpers.swift`**

Delete lines 194-217 (the `sampleDispute` factory method).

- [ ] **Step 4: Commit**

```bash
git add BuzzTests/BookingServiceExtendedTests.swift BuzzTests/BookingModelTests.swift BuzzTests/TestHelpers.swift
git commit -m "test: remove obsolete BookingDispute test code"
```

---

### Task 15: Build verification

- [ ] **Step 1: Build the project**

```bash
xcodebuild -scheme Buzz -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' build 2>&1 | tail -20
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 2: Run existing tests**

```bash
xcodebuild -scheme Buzz -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' test 2>&1 | tail -30
```

Expected: All tests pass. If any test references `BookingDispute`, `DisputeStatus`, `sampleDispute`, or `bookingService.disputes`, fix the remaining reference and re-run.

- [ ] **Step 3: Commit any fixes if needed**

```bash
git add -A && git commit -m "fix: resolve remaining compile errors from dispute integration"
```
