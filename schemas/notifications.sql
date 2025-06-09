-- Notification System Tables and Functions
-- This system supports platform notifications, user-to-user communication, and action-based notifications

-- Notification types enum
CREATE TYPE notification_type AS ENUM (
	'system',          -- Platform-wide announcements
	'direct_message',  -- User to user communication
	'action_required', -- Workflow or task notifications
	'reminder',        -- Scheduled reminders
	'alert',          -- Important alerts
	'achievement',    -- Gamification/milestone notifications
	'role_based'      -- Notifications based on user roles
);

-- Notification priority enum
CREATE TYPE notification_priority AS ENUM ('low', 'medium', 'high', 'urgent');

-- Notification delivery channel enum
CREATE TYPE notification_channel AS ENUM ('in_app', 'email', 'sms', 'push');

-- Main notifications table
CREATE TABLE IF NOT EXISTS notifications (
	id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
	type notification_type NOT NULL,
	priority notification_priority DEFAULT 'medium',
	
	-- Sender information
	sender_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
	sender_type TEXT DEFAULT 'user', -- 'user', 'system', 'workflow', etc.
	
	-- Recipient information
	recipient_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
	recipient_role_code TEXT, -- For role-based notifications
	recipient_role_level INTEGER, -- For level-based filtering
	
	-- Content
	title TEXT NOT NULL,
	body TEXT NOT NULL,
	data JSONB DEFAULT '{}', -- Additional structured data
	
	-- Metadata
	category TEXT, -- For grouping notifications
	tags TEXT[] DEFAULT '{}', -- For filtering
	expires_at TIMESTAMPTZ, -- Auto-delete after this time
	
	-- Tracking
	is_read BOOLEAN DEFAULT FALSE,
	read_at TIMESTAMPTZ,
	is_archived BOOLEAN DEFAULT FALSE,
	archived_at TIMESTAMPTZ,
	
	-- Related entities
	related_entity_type TEXT, -- 'agreement', 'workflow', 'workshop', etc.
	related_entity_id UUID,
	action_url TEXT, -- Where to navigate when clicked
	
	-- Timestamps
	created_at TIMESTAMPTZ DEFAULT NOW(),
	updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Notification templates for reusable content
CREATE TABLE IF NOT EXISTS notification_templates (
	id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
	code TEXT UNIQUE NOT NULL,
	type notification_type NOT NULL,
	name TEXT NOT NULL,
	description TEXT,
	
	-- Template content with variables like {{user_name}}, {{action_name}}
	title_template TEXT NOT NULL,
	body_template TEXT NOT NULL,
	
	-- Default values
	default_priority notification_priority DEFAULT 'medium',
	default_channels notification_channel[] DEFAULT '{in_app}',
	
	-- Configuration
	variables JSONB DEFAULT '{}', -- Expected variables and their descriptions
	metadata JSONB DEFAULT '{}',
	
	is_active BOOLEAN DEFAULT TRUE,
	created_at TIMESTAMPTZ DEFAULT NOW(),
	updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- User notification preferences
CREATE TABLE IF NOT EXISTS notification_preferences (
	id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
	user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
	
	-- Global settings
	enabled BOOLEAN DEFAULT TRUE,
	quiet_hours_start TIME,
	quiet_hours_end TIME,
	timezone TEXT DEFAULT 'UTC',
	
	-- Channel preferences by notification type
	channel_preferences JSONB DEFAULT '{}', -- {type: [channels]}
	
	-- Filtering preferences
	blocked_senders UUID[] DEFAULT '{}',
	blocked_categories TEXT[] DEFAULT '{}',
	priority_threshold notification_priority DEFAULT 'low',
	
	created_at TIMESTAMPTZ DEFAULT NOW(),
	updated_at TIMESTAMPTZ DEFAULT NOW(),
	UNIQUE(user_id)
);

-- Notification delivery status tracking
CREATE TABLE IF NOT EXISTS notification_deliveries (
	id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
	notification_id UUID NOT NULL REFERENCES notifications(id) ON DELETE CASCADE,
	channel notification_channel NOT NULL,
	
	-- Delivery status
	status TEXT NOT NULL DEFAULT 'pending', -- pending, sent, delivered, failed, bounced
	sent_at TIMESTAMPTZ,
	delivered_at TIMESTAMPTZ,
	failed_at TIMESTAMPTZ,
	error_message TEXT,
	
	-- Delivery metadata
	metadata JSONB DEFAULT '{}', -- Channel-specific data (message IDs, etc.)
	
	created_at TIMESTAMPTZ DEFAULT NOW(),
	UNIQUE(notification_id, channel)
);

-- User search index with vector support
CREATE TABLE IF NOT EXISTS user_search_index (
	user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
	
	-- Basic search fields
	full_name TEXT NOT NULL,
	email TEXT NOT NULL,
	role_code TEXT NOT NULL,
	role_name TEXT NOT NULL,
	role_level INTEGER NOT NULL,
	headquarter_name TEXT,
	
	-- Full-text search vector
	search_vector tsvector GENERATED ALWAYS AS (
		setweight(to_tsvector('spanish', coalesce(full_name, '')), 'A') ||
		setweight(to_tsvector('spanish', coalesce(email, '')), 'B') ||
		setweight(to_tsvector('spanish', coalesce(role_name, '')), 'C') ||
		setweight(to_tsvector('spanish', coalesce(headquarter_name, '')), 'D')
	) STORED,
	
	-- Metadata
	is_active BOOLEAN DEFAULT TRUE,
	last_seen TIMESTAMPTZ,
	created_at TIMESTAMPTZ DEFAULT NOW(),
	updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX idx_notifications_recipient ON notifications(recipient_id) WHERE NOT is_archived;
CREATE INDEX idx_notifications_unread ON notifications(recipient_id) WHERE NOT is_read AND NOT is_archived;
CREATE INDEX idx_notifications_type ON notifications(type);
CREATE INDEX idx_notifications_priority ON notifications(priority);
CREATE INDEX idx_notifications_created ON notifications(created_at DESC);
CREATE INDEX idx_notifications_expires ON notifications(expires_at) WHERE expires_at IS NOT NULL;
CREATE INDEX idx_notifications_related ON notifications(related_entity_type, related_entity_id);

CREATE INDEX idx_notification_templates_code ON notification_templates(code) WHERE is_active;

CREATE INDEX idx_user_search_vector ON user_search_index USING GIN(search_vector);
CREATE INDEX idx_user_search_role ON user_search_index(role_code, role_level);

-- Enable RLS
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_deliveries ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_search_index ENABLE ROW LEVEL SECURITY;

-- RLS Policies

-- Notifications policies
CREATE POLICY "Users can view their own notifications"
	ON notifications FOR SELECT
	TO authenticated
	USING (recipient_id = auth.uid());

CREATE POLICY "Users can update their own notifications"
	ON notifications FOR UPDATE
	TO authenticated
	USING (recipient_id = auth.uid())
	WITH CHECK (recipient_id = auth.uid());

CREATE POLICY "System can create notifications"
	ON notifications FOR INSERT
	TO authenticated
	WITH CHECK (
		-- Users can send direct messages
		(type = 'direct_message' AND sender_id = auth.uid())
		OR
		-- System/admin operations
		public.fn_get_current_role_level() >= 80
	);

-- Notification preferences policies
CREATE POLICY "Users can manage their preferences"
	ON notification_preferences FOR ALL
	TO authenticated
	USING (user_id = auth.uid())
	WITH CHECK (user_id = auth.uid());

-- User search index policies
CREATE POLICY "Authenticated users can search users"
	ON user_search_index FOR SELECT
	TO authenticated
	USING (is_active = TRUE);

-- Templates policies (admins only)
CREATE POLICY "Admins can manage notification templates"
	ON notification_templates FOR ALL
	TO authenticated
	USING (public.fn_is_konsejo_member_or_higher())
	WITH CHECK (public.fn_is_konsejo_member_or_higher());

CREATE POLICY "Users can view active templates"
	ON notification_templates FOR SELECT
	TO authenticated
	USING (is_active = TRUE);

-- Triggers
CREATE TRIGGER handle_updated_at_notifications
	BEFORE UPDATE ON notifications
	FOR EACH ROW EXECUTE PROCEDURE moddatetime(updated_at);

CREATE TRIGGER handle_updated_at_notification_templates
	BEFORE UPDATE ON notification_templates
	FOR EACH ROW EXECUTE PROCEDURE moddatetime(updated_at);

CREATE TRIGGER handle_updated_at_notification_preferences
	BEFORE UPDATE ON notification_preferences
	FOR EACH ROW EXECUTE PROCEDURE moddatetime(updated_at);

CREATE TRIGGER handle_updated_at_user_search_index
	BEFORE UPDATE ON user_search_index
	FOR EACH ROW EXECUTE PROCEDURE moddatetime(updated_at);