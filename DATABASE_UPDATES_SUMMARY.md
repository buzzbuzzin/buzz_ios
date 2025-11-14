# Database Updates Summary

## Overview
Updated `database_complete.sql` to include all soft delete functionality and message management features from the migration files.

## Changes Made to `database_complete.sql`

### 1. Table Schema Updates

#### Messages Table (Line ~759)
**Added columns:**
- `deleted_at TIMESTAMP WITH TIME ZONE` - Records when a message was soft-deleted
- `deleted_by UUID REFERENCES profiles(id)` - Records which user deleted the message

#### Direct Messages Table (Line ~801)
**Added columns:**
- `deleted_at TIMESTAMP WITH TIME ZONE` - Records when a message was soft-deleted
- `deleted_by UUID REFERENCES profiles(id)` - Records which user deleted the message

### 2. Indexes (Lines ~1070-1081)

**Messages indexes:**
- Added `idx_messages_deleted_at` - Improves query performance for filtering deleted messages

**Direct Messages indexes:**
- Added `idx_direct_messages_deleted_at` - Improves query performance for filtering deleted messages

### 3. Functions (Lines 218-249)

**Added two PostgreSQL functions:**

#### `delete_old_soft_deleted_messages()`
- Permanently deletes messages soft-deleted more than 7 days ago
- Operates on both `messages` and `direct_messages` tables
- Can be called manually or scheduled via pg_cron

#### `filter_deleted_messages()`
- Alternative trigger-based approach for auto-deletion
- Can be attached to a trigger to clean up old messages on access

**Scheduling note:**
```sql
-- To enable automatic cleanup (requires pg_cron extension):
CREATE EXTENSION IF NOT EXISTS pg_cron;
SELECT cron.schedule('delete-old-messages', '0 2 * * *', 'SELECT delete_old_soft_deleted_messages()');
```

### 4. RLS Policies Updated

#### Messages Table (Line ~780)
**Policy: "Users can view messages for their bookings"**
- **Old logic:** `auth.uid() = from_user_id OR auth.uid() = to_user_id`
- **New logic:** 
  ```sql
  (auth.uid() = from_user_id OR auth.uid() = to_user_id)
  AND (deleted_at IS NULL OR deleted_by != auth.uid())
  ```
- **Effect:** Users cannot see messages they've deleted, but can still see messages deleted by others

**Policy: "Users can update their own messages"**
- **Old logic:** `auth.uid() = from_user_id`
- **New logic:** `auth.uid() = from_user_id OR auth.uid() = to_user_id`
- **Effect:** Both sender and receiver can update messages (needed for marking as read/unread and soft delete)

#### Direct Messages Table (Line ~821)
**Policy: "Users can view their direct messages"**
- **Old logic:** `auth.uid() = from_user_id OR auth.uid() = to_user_id`
- **New logic:**
  ```sql
  (auth.uid() = from_user_id OR auth.uid() = to_user_id)
  AND (deleted_at IS NULL OR deleted_by != auth.uid())
  ```
- **Effect:** Users cannot see direct messages they've deleted, but can still see messages deleted by others

**Policy: "Users can update their direct messages"**
- **Old logic:** `auth.uid() = from_user_id`
- **New logic:** `auth.uid() = from_user_id OR auth.uid() = to_user_id`
- **Effect:** Both sender and receiver can update direct messages (needed for marking as read/unread and soft delete)

## Migration Files

### `add_soft_delete_to_messages.sql`
- Contains ALTER TABLE statements to add columns to existing tables
- Includes all functions and policy updates
- Safe to run on existing databases (uses IF NOT EXISTS)

### `create_direct_messages_table.sql`
- Updated to include soft delete columns in initial table creation
- Includes soft delete indexes

## Behavior

### Soft Delete Process
1. User taps delete icon → confirmation dialog appears
2. User confirms → `deleted_at` set to current timestamp, `deleted_by` set to user ID
3. Message disappears from user's view immediately
4. Message remains in database for 7 days (for security/recovery)
5. After 7 days → message is permanently deleted

### Query Behavior
- **User who deleted:** Cannot see the message (filtered by RLS)
- **Other party:** Can still see the message until they delete it
- **Admin/Security:** Can query deleted messages within 7-day window if needed

### Mark as Unread
- Updates `is_read` field to `false`
- Blue dot indicator appears next to conversation
- Requires UPDATE permission on the message

## Testing the Changes

### To Apply Migration to Existing Database
```sql
-- Run in Supabase SQL Editor
\i add_soft_delete_to_messages.sql
```

### To Create New Database
```sql
-- Run in Supabase SQL Editor
\i database_complete.sql
```

### To Schedule Automatic Cleanup
```sql
-- Enable pg_cron extension (if available)
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Schedule daily cleanup at 2 AM
SELECT cron.schedule(
    'delete-old-messages',
    '0 2 * * *',
    'SELECT delete_old_soft_deleted_messages()'
);
```

### To Manually Clean Up Old Messages
```sql
SELECT delete_old_soft_deleted_messages();
```

## Related Files Updated
- `MessageService.swift` - Added soft delete and mark unread methods
- `ConversationsListView.swift` - Added delete confirmation and handlers
- `DirectMessage.swift` - Model already supports nullable fields
- `Message.swift` - Model already supports nullable fields

## Security Considerations
1. Messages are kept for 7 days to allow for:
   - Dispute resolution
   - Security investigations
   - Accidental deletion recovery
2. RLS policies prevent users from seeing their deleted messages
3. Only the user who deleted can't see the message (other party still can)
4. Permanent deletion happens automatically after 7 days

## Performance Notes
- Indexes on `deleted_at` ensure efficient filtering
- Soft delete is a simple UPDATE operation (fast)
- Auto-deletion runs during off-peak hours (2 AM)
- RLS filtering happens at database level (secure and efficient)

