# Call Sign Validation Changes

This document summarizes all the changes made to implement call sign validation according to the requirements.

## Requirements Implemented

1. ✅ **Letters Only**: Call signs can only contain letters (A-Z). Numbers and special characters (underscore, dash, pound sign, etc.) are not allowed.

2. ✅ **Case Insensitive**: Call signs are treated as case-insensitive. "skyforge", "Skyforge", and "sKyforge" are all treated as the same. By default, all call signs are stored and displayed in uppercase.

3. ✅ **Reserved Word Protection**: The call sign "Maverick" (case-insensitive) is reserved and cannot be used by any pilot.

4. ✅ **Uniqueness Enforcement**: Call signs must be unique across all pilots. The backend validates this during signup and update operations, ensuring no duplicate call signs can be created.

## Changes Made

### 1. Database Migration (`callsign_validation_migration.sql`)

**Location**: `/Users/xinyufang/Documents/Buzz/callsign_validation_migration.sql`

**What it does**:
- Drops the existing case-sensitive unique constraint on `call_sign`
- Normalizes all existing call signs to uppercase
- Creates a case-insensitive unique index on `UPPER(call_sign)`
- Adds a check constraint to ensure only letters are allowed (no numbers or special characters)
- Creates a database trigger function that:
  - Normalizes call signs to uppercase on insert/update
  - Validates that only letters are used
  - Prevents the reserved word "MAVERICK" from being used
- Adds documentation comment to the column

**To apply**: Run this SQL file in your Supabase SQL Editor.

### 2. ProfileService Updates

**Location**: `Buzz/Services/ProfileService.swift`

**Changes**:
- `updateProfile()`: Now normalizes call sign to uppercase before saving
- `checkCallSignAvailability()`: Now performs case-insensitive checks by normalizing to uppercase before querying

### 3. AuthService Updates

**Location**: `Buzz/Services/AuthService.swift`

**Changes**:
- `createProfile()`: Now normalizes call sign to uppercase before saving to the database

### 4. SignUpView Updates

**Location**: `Buzz/Views/Auth/SignUpView.swift`

**Changes**:
- Added real-time input filtering to only allow letters
- Auto-uppercases input as user types
- Added validation that checks:
  - Only letters are allowed
  - Reserved word "Maverick" is not used
  - Call sign is unique (with async availability check)
- Shows validation errors with red border on the input field
- Displays "Checking availability..." message while checking uniqueness
- Prevents form submission if validation fails
- Double-checks availability before actual signup

### 5. CallSignEditView Updates

**Location**: `Buzz/Views/Profile/CallSignEditView.swift`

**Changes**:
- Added same real-time validation as SignUpView
- Filters input to only allow letters
- Auto-uppercases input
- Validates reserved words and uniqueness
- Only checks uniqueness if the call sign has changed from the current one
- Shows validation errors with red border
- Prevents update button from being clicked if validation fails

### 6. AuthenticationView Updates

**Location**: `Buzz/Views/Auth/AuthenticationView.swift`

**Changes**:
- Updated `UserTypeSelectionSheet` to filter input to only allow letters
- Auto-uppercases input in the call sign field

## How It Works

### Frontend Validation Flow

1. **Input Filtering**: As the user types, the text field automatically:
   - Filters out any non-letter characters
   - Converts all letters to uppercase
   - Validates format, reserved words, and uniqueness in real-time

2. **Real-time Validation**: 
   - Format validation (letters only) happens immediately
   - Reserved word check happens immediately
   - Uniqueness check is performed asynchronously after a short delay

3. **Pre-submission Validation**: Before signup/update:
   - All validations are re-checked
   - Availability is double-checked to prevent race conditions
   - User receives clear error messages if validation fails

### Backend Validation Flow

1. **Database Trigger**: On every insert or update of `call_sign`:
   - Automatically normalizes to uppercase
   - Validates letters-only format
   - Prevents reserved words like "MAVERICK"
   - Raises an exception if validation fails

2. **Database Constraints**:
   - Unique index on `UPPER(call_sign)` ensures case-insensitive uniqueness
   - Check constraint ensures only uppercase letters are stored

### Case Insensitivity Implementation

- All call signs are stored in uppercase in the database
- Queries compare using uppercase normalization
- Frontend displays and inputs are also in uppercase
- This ensures "skyforge", "SkyForge", and "SKYFORGE" are all treated identically

## Testing Checklist

- [ ] Run the database migration in Supabase SQL Editor
- [ ] Test signup with valid call sign (letters only)
- [ ] Test signup with numbers (should be filtered out)
- [ ] Test signup with special characters (should be filtered out)
- [ ] Test signup with "Maverick" (should be rejected)
- [ ] Test signup with lowercase call sign (should be converted to uppercase)
- [ ] Test signup with duplicate call sign (should be rejected)
- [ ] Test editing call sign with same validations
- [ ] Verify existing call signs in database are converted to uppercase
- [ ] Verify case-insensitive uniqueness (e.g., "SkyForge" and "skyforge" cannot both exist)

## Notes

- The database migration is idempotent and safe to run multiple times
- Existing call signs will be automatically converted to uppercase when the migration runs
- The trigger function ensures backend validation even if frontend validation is bypassed
- All validation is done both client-side (for better UX) and server-side (for security)

