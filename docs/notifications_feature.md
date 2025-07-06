# Notification System Feature Documentation

## Overview

A comprehensive notification system that enables multi-channel communication across the platform, supporting platform announcements, user-to-user messaging, workflow notifications, and role-based broadcasting.

## Core Components

### 1. Database Schema (`notifications.sql`)

#### Tables:
- **notifications**: Core notification storage with RLS policies
- **notification_templates**: Reusable templates with variable support
- **notification_preferences**: User-specific notification settings
- **notification_deliveries**: Multi-channel delivery status tracking
- **user_search_index**: Vector-based full-text search for user discovery

#### Supported Types:
- `system` - Platform-wide announcements
- `direct_message` - User-to-user communication
- `action_required` - Workflow or task notifications
- `reminder` - Scheduled reminders
- `alert` - Important alerts
- `achievement` - Gamification/milestone notifications
- `role_based` - Role-specific broadcasts

#### Priority Levels:
- `low`, `medium`, `high`, `urgent`

#### Delivery Channels:
- `in_app`, `email`, `sms`, `push`

### 2. Vector Search Functionality (`notification_functions.sql`)

- **Function**: `search_users_vector()`
- **Features**:
  - Spanish language full-text search
  - Weighted search (name > email > role > headquarter)
  - Role and permission filtering
  - Similarity ranking
- **Usage**:
  ```sql
  SELECT * FROM search_users_vector(
    p_query := 'Juan Manager',
    p_role_code := 'local_manager',
    p_min_role_level := 30
  );
  ```

### 3. Automatic Triggers (`notification_triggers.sql`)

#### Implemented Triggers:
- **User Creation**: Welcome notification + manager alerts
- **Workflow Actions**: Assignment and completion notifications
- **Workshop Events**: Reminders and updates
- **Search Index Updates**: Automatic user index maintenance

### 4. API Endpoints (`routes/notifications.ts`)

| Method | Endpoint | Description | Min Role Level |
|--------|----------|-------------|----------------|
| GET | `/akademy-app/users/search` | Vector search for users | 1 |
| POST | `/akademy-app/notifications/send` | Send direct notification | 1 |
| POST | `/akademy-app/notifications/send-role` | Role-based broadcast | 50 |
| GET | `/akademy-app/notifications` | Get paginated notifications | 1 |
| GET | `/akademy-app/notifications/unread-count` | Get unread count | 1 |
| POST | `/akademy-app/notifications/mark-read` | Mark as read | 1 |
| POST | `/akademy-app/notifications/:id/archive` | Archive notification | 1 |
| GET | `/akademy-app/notifications/preferences` | Get preferences | 1 |
| PUT | `/akademy-app/notifications/preferences` | Update preferences | 1 |

### 5. Pre-configured Templates (`notification_templates_seed.sql`)

#### Available Templates:
- `user_activated` - New user welcome
- `manager_user_activated` - Manager alert for new users
- `workflow_action_assigned` - Task assignment
- `workflow_completed` - Workflow completion
- `workflow_action_overdue` - Overdue alerts
- `workshop_reminder_facilitator` - Workshop reminders
- `workshop_cancelled` - Cancellation notices
- `milestone_reached` - Achievement notifications
- `system_maintenance` - Maintenance alerts
- `password_reset` - Password reset confirmations
- `direct_message` - User messaging template

## Implementation Examples

### Sending a Direct Notification
```javascript
// API Request
POST /akademy-app/notifications/send
{
  "recipient_id": "user-uuid",
  "title": "Task Completed",
  "body": "Your document has been approved",
  "type": "action_required",
  "priority": "high",
  "action_url": "/documents/123"
}
```

### Role-Based Broadcasting
```javascript
// Send to all managers and above
POST /akademy-app/notifications/send-role
{
  "role_codes": ["local_manager", "konsejo_member"],
  "min_role_level": 50,
  "title": "New Policy Update",
  "body": "Please review the updated guidelines",
  "type": "role_based",
  "priority": "medium"
}
```

### Using Templates
```sql
SELECT create_notification_from_template(
  p_template_code := 'user_activated',
  p_recipient_id := 'user-uuid',
  p_variables := jsonb_build_object(
    'user_name', 'María García',
    'email', 'maria@example.com',
    'password', 'temp12345'
  )
);
```

### Searching Users
```javascript
// Find users by name with role filter
GET /akademy-app/users/search?q=juan&role_code=student&limit=10
```

## Security Features

1. **Row-Level Security (RLS)**: Users can only access their own notifications
2. **Role-Based Access Control**: Different endpoints require different permission levels
3. **Audit Trail**: All notifications tracked with timestamps and sender info
4. **Data Isolation**: Multi-tenant support through RLS policies

## Performance Optimizations

1. **Indexed Columns**: All search and filter columns are indexed
2. **Automatic Archival**: Old notifications auto-archive after 30 days
3. **Batch Operations**: Bulk notification functions for efficiency
4. **GIN Indexes**: Full-text search optimization
5. **Pagination**: All list endpoints support limit/offset

## User Preferences

Users can configure:
- Global enable/disable
- Quiet hours (timezone-aware)
- Channel preferences by notification type
- Blocked senders and categories
- Priority threshold filtering

## Extensibility

### Adding New Notification Types:
1. Update `notification_type` enum
2. Create new templates
3. Add trigger functions if needed

### Adding New Channels:
1. Update `notification_channel` enum
2. Implement delivery logic in Edge Functions
3. Add channel-specific metadata handling

### Custom Triggers:
Create PostgreSQL trigger functions for any table/event that should generate notifications

## Maintenance

### Cleanup Expired Notifications:
```sql
SELECT cleanup_expired_notifications();
```

### Monitor Failed Deliveries:
```sql
SELECT * FROM notification_deliveries
WHERE status = 'failed'
ORDER BY created_at DESC;
```

## Best Practices

1. **Use Templates**: Ensures consistent messaging
2. **Set Expiry Dates**: For time-sensitive notifications
3. **Respect User Preferences**: Check settings before sending
4. **Batch Similar Notifications**: Avoid notification spam
5. **Use Appropriate Priority**: Reserve 'urgent' for critical items
6. **Include Action URLs**: Help users navigate to relevant content
7. **Test Variable Replacement**: Ensure templates render correctly

## Integration with Existing Features

- **User Creation**: Automatic welcome notifications
- **Workflow System**: Action assignments and completions
- **Workshop Management**: Reminders and updates
- **Role Management**: Role-based broadcasting

## Files Created

1. `/schemas/notifications.sql` - Core database schema
2. `/schemas/notification_functions.sql` - Database functions
3. `/schemas/notification_triggers.sql` - Automatic triggers
4. `/schemas/notification_templates_seed.sql` - Template data
5. `/functions/akademy-app/routes/notifications.ts` - API endpoints
6. `/docs/NOTIFICATION_SYSTEM_GUIDE.md` - Detailed guide

## Configuration

Added to `config.toml`:
```toml
"./schemas/notifications.sql",
"./schemas/notification_functions.sql",
"./schemas/notification_triggers.sql",
"./schemas/notification_templates_seed.sql",
```

The notification system is now fully integrated and ready for use across the platform.