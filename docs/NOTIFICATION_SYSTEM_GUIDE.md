# Comprehensive Notification System Guide

## Overview

The notification system is a flexible, multi-channel communication platform that supports:
- Platform-wide announcements
- User-to-user messaging
- Workflow and action-based notifications
- Role-based broadcasting
- Achievement and milestone notifications
- System alerts and reminders

## Architecture Components

### 1. Database Schema

#### Core Tables:
- **notifications**: Main notification storage
- **notification_templates**: Reusable notification templates
- **notification_preferences**: User preferences for notifications
- **notification_deliveries**: Tracks delivery status across channels
- **user_search_index**: Vector-based user search with full-text search

#### Key Features:
- Row-level security (RLS) for data protection
- Automatic expiration of old notifications
- Archive functionality for long-term storage
- Full-text search using PostgreSQL's tsvector

### 2. Notification Types

```typescript
type NotificationType = 
  | 'system'          // Platform-wide announcements
  | 'direct_message'  // User-to-user communication
  | 'action_required' // Workflow or task notifications
  | 'reminder'        // Scheduled reminders
  | 'alert'          // Important alerts
  | 'achievement'    // Gamification/milestone notifications
  | 'role_based'     // Notifications based on user roles
```

### 3. Priority Levels

```typescript
type NotificationPriority = 'low' | 'medium' | 'high' | 'urgent'
```

### 4. Delivery Channels

```typescript
type NotificationChannel = 'in_app' | 'email' | 'sms' | 'push'
```

## User Search with Vectors

The system includes a powerful user search feature using PostgreSQL's full-text search:

```sql
-- Search users by name, email, role
SELECT * FROM search_users_vector(
  p_query := 'Juan Manager',
  p_role_code := 'local_manager',
  p_min_role_level := 30,
  p_limit := 10
);
```

### Features:
- Spanish language support
- Weighted search (name > email > role > headquarter)
- Role and level filtering
- Similarity ranking

## Triggering Notifications

### 1. Automatic Triggers

The system automatically creates notifications for:

#### User Creation
```sql
-- When agreement status changes to 'active'
-- Creates welcome notification for user
-- Notifies local managers
```

#### Workflow Actions
```sql
-- When action is assigned
-- When action is completed
-- When action is overdue
```

#### Workshop Events
```sql
-- Reminders before workshops
-- Cancellation notifications
-- Attendance confirmations
```

### 2. Manual Triggering via API

#### Send Direct Notification
```bash
POST /akademy-app/notifications/send
{
  "recipient_id": "user-uuid",
  "title": "Important Update",
  "body": "Your request has been approved",
  "type": "direct_message",
  "priority": "high",
  "action_url": "/requests/123"
}
```

#### Send Role-Based Notification
```bash
POST /akademy-app/notifications/send-role
{
  "role_codes": ["student", "collaborator"],
  "min_role_level": 10,
  "title": "New Workshop Available",
  "body": "Check out our latest workshop on leadership",
  "type": "role_based",
  "priority": "medium"
}
```

### 3. Template-Based Notifications

```sql
-- Use predefined templates with variables
SELECT create_notification_from_template(
  p_template_code := 'user_activated',
  p_recipient_id := 'user-uuid',
  p_variables := jsonb_build_object(
    'user_name', 'Juan Pérez',
    'email', 'juan@example.com',
    'password', 'temp123'
  )
);
```

## API Endpoints

### Search Users
```bash
GET /akademy-app/users/search?q=juan&role_code=student&limit=10
```

### Get Notifications
```bash
GET /akademy-app/notifications?limit=20&is_read=false&type=action_required
```

### Get Unread Count
```bash
GET /akademy-app/notifications/unread-count
```

### Mark as Read
```bash
POST /akademy-app/notifications/mark-read
{
  "notification_ids": ["id1", "id2", "id3"]
}
```

### Archive Notification
```bash
POST /akademy-app/notifications/{id}/archive
```

### Manage Preferences
```bash
GET /akademy-app/notifications/preferences
PUT /akademy-app/notifications/preferences
{
  "enabled": true,
  "quiet_hours_start": "22:00",
  "quiet_hours_end": "08:00",
  "channel_preferences": {
    "system": ["in_app", "email"],
    "direct_message": ["in_app"],
    "alert": ["in_app", "email", "sms"]
  }
}
```

## Flexibility and Extensibility

### 1. Custom Notification Types
Add new notification types by:
- Updating the `notification_type` enum
- Creating new templates
- Adding trigger functions

### 2. Custom Delivery Channels
Extend delivery channels by:
- Updating the `notification_channel` enum
- Implementing delivery logic in Edge Functions
- Adding channel-specific metadata

### 3. Dynamic Templates
Templates support variables for dynamic content:
```sql
'Welcome {{user_name}}! Your account at {{hq_name}} is ready.'
```

### 4. Conditional Routing
Route notifications based on:
- User roles and levels
- Headquarters
- Custom metadata
- Time zones and preferences

### 5. Batch Processing
Send bulk notifications efficiently:
```sql
SELECT send_role_based_notification(
  p_role_codes := ARRAY['student', 'collaborator'],
  p_title := 'System Update',
  p_body := 'New features available'
);
```

## Integration Examples

### 1. After User Creation
```typescript
// In create-user.ts
const notification = await supabase.rpc('create_notification_from_template', {
  p_template_code: 'user_activated',
  p_recipient_id: userData.user.id,
  p_variables: {
    user_name: `${agreement.name} ${agreement.last_name}`,
    email: agreement.email,
    password: generatedPassword
  }
});
```

### 2. Workflow Integration
```sql
-- Automatic notification on action assignment
CREATE TRIGGER notify_on_action_assign
  AFTER INSERT OR UPDATE ON workflow_actions
  FOR EACH ROW EXECUTE FUNCTION notify_workflow_action_assigned();
```

### 3. Scheduled Notifications
```sql
-- Create future notifications with expiry
INSERT INTO notifications (
  recipient_id,
  title,
  body,
  created_at,
  expires_at
) VALUES (
  'user-id',
  'Workshop Tomorrow',
  'Don\'t forget your workshop at 10 AM',
  NOW() + INTERVAL '23 hours', -- Send tomorrow
  NOW() + INTERVAL '2 days'     -- Expire after workshop
);
```

## Performance Considerations

1. **Indexing**: All key columns are indexed for fast queries
2. **Archival**: Old notifications auto-archive after 30 days
3. **Batch Operations**: Use bulk functions for mass notifications
4. **Vector Search**: Full-text search is optimized with GIN indexes
5. **Pagination**: All list endpoints support pagination

## Security Features

1. **RLS Policies**: Users can only see their own notifications
2. **Role-Based Access**: Different endpoints require different permission levels
3. **Audit Trail**: All notifications are tracked with timestamps
4. **Data Isolation**: Multi-tenant support through RLS

## Best Practices

1. **Use Templates**: For consistent messaging and easier maintenance
2. **Set Expiry**: For time-sensitive notifications
3. **Respect Preferences**: Check user preferences before sending
4. **Batch Similar Notifications**: Avoid spamming users
5. **Use Appropriate Priority**: Reserve 'urgent' for critical items
6. **Include Action URLs**: Help users navigate to relevant content
7. **Test Templates**: Ensure variables are properly replaced

## Monitoring and Maintenance

### Clean Up Expired Notifications
```sql
SELECT cleanup_expired_notifications();
```

### Check Delivery Status
```sql
SELECT * FROM notification_deliveries
WHERE status = 'failed'
ORDER BY created_at DESC;
```

### Analytics Queries
```sql
-- Most active notification types
SELECT type, COUNT(*) 
FROM notifications 
GROUP BY type;

-- User engagement
SELECT 
  recipient_id,
  COUNT(*) as total,
  COUNT(*) FILTER (WHERE is_read) as read_count
FROM notifications
GROUP BY recipient_id;
```

## Future Enhancements

1. **Push Notifications**: Mobile app integration
2. **Email Templates**: HTML email support
3. **Scheduling Engine**: Advanced scheduling with cron-like syntax
4. **Analytics Dashboard**: Notification metrics and insights
5. **Webhook Integration**: Third-party service notifications
6. **Multi-language Support**: Localized notification content