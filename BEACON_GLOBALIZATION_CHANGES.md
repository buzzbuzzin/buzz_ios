# Beacon Globalization Changes

## Summary
Updated the Beacon feature to use globally-applicable terminology instead of US-specific organization names, and reorganized the dashboard view so active volunteers see their dashboard first.

## Changes Made

### 1. Terminology Updates

#### Training Type Display Names (BeaconTrainingProgress.swift)
- **CPR Training** → **First Aid/CPR Training** (more comprehensive, globally applicable)
- **CERT Training** → **Disaster Response Training** (generic term instead of US-specific CERT program)
- Updated descriptions to be more globally inclusive

#### Badge Display Names (Badge.swift)
- **CERT** → **Disaster Response**
- **First Aid** → **First Aid/CPR**

#### Training Descriptions
- Updated CPR description: "Learn life-saving first aid and CPR techniques..."
- Updated CERT description: "Disaster response and community emergency preparedness training"

#### Certificate Upload View (CertificateBadgeUploadView.swift)
- Removed specific organization reference (e.g., "like Red Cross")
- Now says: "from an accredited provider" (generic, works globally)

#### Error Messages (BeaconService.swift)
- Updated to use new terminology: "First Aid/CPR, Firefighting, and Disaster Response"

### 2. Dashboard Reorganization

#### BeaconView.swift - Major Restructure
**Before:**
- All users (volunteers and non-volunteers) saw the same info page
- Active volunteers had a "View Dashboard" button to access their dashboard
- "About Beacon Program" section was always visible on the main page

**After:**
- **Active volunteers**: Directly see their dashboard (BeaconVolunteerDashboardView)
- **Non-volunteers**: See the info/signup page (BeaconInfoView)
- **About Beacon Program**: Now accessible from the dashboard via a button (as a recap/reference)

#### New Views Created

1. **BeaconInfoView**
   - Shows the signup/info view for non-volunteers
   - Contains all the original Beacon program information
   - Has the "Start Onboarding" button

2. **BeaconAboutProgramView**
   - Displays the "About Beacon Program" information
   - Accessible from the dashboard for active volunteers
   - Provides a recap of program features, how it works, and mission types

#### BeaconVolunteerDashboardView Updates
- Added `@Binding var showAboutProgram: Bool` parameter
- Added "About Beacon Program" button (positioned below availability toggle)
- Button displays with info icon and shows the BeaconAboutProgramView sheet

### 3. User Experience Flow

#### For Non-Volunteers:
1. See BeaconView → BeaconInfoView (with all program info)
2. Click "Start Onboarding" → Complete training uploads
3. Activate volunteer status

#### For Active Volunteers:
1. See BeaconView → BeaconVolunteerDashboardView (their dashboard)
2. See availability toggle, stats, and missions first
3. Can tap "About Beacon Program" button to review program information

## Technical Details

### Database Schema
- No database changes needed
- Uses generic values: `'cpr'`, `'firefighting'`, `'cert'`
- Display names are handled in the Swift code layer

### Provider Enums
- Kept organization names in provider enums (Badge.swift, TrainingCourse.swift)
- These represent actual training providers, not user-facing terminology
- Examples: `.redCross`, `.fema`, `.usfa` remain as options

## Benefits

1. **Global Applicability**: Terms work for pilots worldwide, not just in the US
2. **Improved UX**: Active volunteers see their dashboard immediately
3. **Better Information Architecture**: "About" section is accessible but not cluttering the dashboard
4. **Clearer Onboarding**: Training names are more descriptive and universally understood

## Files Modified

1. `/Buzz/Models/BeaconTrainingProgress.swift`
2. `/Buzz/Models/Badge.swift`
3. `/Buzz/Views/Profile/CertificateBadgeUploadView.swift`
4. `/Buzz/Services/BeaconService.swift`
5. `/Buzz/Views/Cockpit/BeaconView.swift` (major restructure)

## Testing Recommendations

1. Test onboarding flow with new terminology
2. Verify dashboard appears for active volunteers
3. Test "About Beacon Program" button on dashboard
4. Verify non-volunteers still see signup page
5. Check that all badge names display correctly
6. Test certificate upload with new descriptions
