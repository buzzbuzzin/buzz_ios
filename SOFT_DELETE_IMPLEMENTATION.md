# Soft Delete and Message Management Implementation

## Overview
This document describes the implementation of soft delete and unread message management for both direct messages and booking messages in the Buzz app.

## Features Implemented

### 1. Delete Confirmation Dialog
- **Location**: `ConversationsListView.swift`
- **Behavior**: When user taps the delete icon, a confirmation dialog appears
- **Message**: "By deleting this conversation, it will be removed from your device. For security reasons, messages will be kept on our servers for up to 7 days before permanent deletion."
- **Actions**: Cancel or Delete

### 2. Soft Delete Functionality
- **Implementation**: Messages are not immediately deleted from the database
- **Mechanism**: 
  - `deleted_at` timestamp is set to current time
  - `deleted_by` field is set to the user who deleted it
  - Messages are hidden from the user's view but remain in database
  - After 7 days, messages are permanently deleted

### 3. Unread Message Management
- **Blue Dot Indicator**: Already implemented - shows blue dot to the left of profile picture for unread conversations
- **Mark as Unread**: Users can swipe right and tap the unread icon to mark messages as unread
- **Behavior**: Updates `is_read` field to `false` for relevant messages

### 4. Fixed Button Tap Issue
- **Problem**: Tapping delete or unread buttons would navigate to chat instead of performing action
- **Solution**: Added `.buttonStyle(.plain)` to both buttons to prevent NavigationLink from intercepting taps

## Database Changes

### Tables Modified
1. **messages** table:
   - Added `deleted_at TIMESTAMP WITH TIME ZONE`
   - Added `deleted_by UUID REFERENCES profiles(id)`
   - Added index on `deleted_at`

2. **direct_messages** table:
   - Added `deleted_at TIMESTAMP WITH TIME ZONE`
   - Added `deleted_by UUID REFERENCES profiles(id)`
   - Added index on `deleted_at`

### Migration Files
1. **add_soft_delete_to_messages.sql**: Migration to add soft delete columns and auto-deletion function
2. **database_complete.sql**: Updated with new columns and indexes
3. **create_direct_messages_table.sql**: Updated with new columns and indexes

### Auto-Deletion Mechanism
- SQL function `delete_old_soft_deleted_messages()` created
- Deletes messages where `deleted_at` is older than 7 days
- Can be scheduled using pg_cron (see migration file for details)

### RLS Policy Updates
- Updated to filter out soft-deleted messages from queries
- Users only see messages that aren't deleted by them
- Messages deleted by other party remain visible

## Service Methods Added

### MessageService.swift
1. **softDeleteDirectMessages(fromUserId:toUserId:)**
   - Soft deletes all direct messages in a conversation
   - Sets `deleted_at` and `deleted_by` fields

2. **softDeleteBookingMessages(bookingId:userId:)**
   - Soft deletes all booking messages for a booking
   - Sets `deleted_at` and `deleted_by` fields

3. **markDirectMessagesAsUnread(fromUserId:toUserId:)**
   - Marks direct messages from another user as unread
   - Sets `is_read` to false

4. **markBookingMessagesAsUnread(bookingId:userId:)**
   - Marks booking messages as unread for current user
   - Sets `is_read` to false

## UI Changes

### Swipe Gesture Buttons
- **Spacing**: 
  - Button width: 42px
  - Gap to content: 15px
  - Edge padding: 8px
  - Total swipe distance: 65px

- **Icons**:
  - Unread: `message.badge` (SF Symbol)
  - Delete: `trash.fill` (SF Symbol)
  - Icon size: 18pt
  - Buttons have rounded rectangular backgrounds

- **Button Style**: `.plain` to prevent NavigationLink interference

### ConversationsListView
- Delete and unread actions now properly execute
- Conversations removed from UI immediately after deletion
- UI refreshes after marking as unread to show blue dot

## Testing Notes
- Both demo mode and production mode are supported
- In demo mode, changes are applied to local arrays only
- In production mode, changes are persisted to Supabase backend

## Future Improvements
1. Schedule pg_cron job for automatic cleanup of old deleted messages
2. Add ability to "undo" delete within a short time window
3. Add batch operations for deleting multiple conversations
4. Add settings to customize deletion retention period

