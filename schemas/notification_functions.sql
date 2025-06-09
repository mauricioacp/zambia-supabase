-- Notification System Functions

-- Function to search users using vector similarity
CREATE OR REPLACE FUNCTION search_users_vector(
	p_query TEXT,
	p_role_code TEXT DEFAULT NULL,
	p_min_role_level INTEGER DEFAULT NULL,
	p_limit INTEGER DEFAULT 10,
	p_offset INTEGER DEFAULT 0
)
RETURNS TABLE (
	user_id UUID,
	full_name TEXT,
	email TEXT,
	role_code TEXT,
	role_name TEXT,
	role_level INTEGER,
	headquarter_name TEXT,
	similarity REAL
)
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
BEGIN
	RETURN QUERY
	SELECT 
		usi.user_id,
		usi.full_name,
		usi.email,
		usi.role_code,
		usi.role_name,
		usi.role_level,
		usi.headquarter_name,
		ts_rank(usi.search_vector, plainto_tsquery('spanish', p_query)) AS similarity
	FROM public.user_search_index usi
	WHERE 
		usi.is_active = TRUE
		AND (p_role_code IS NULL OR usi.role_code = p_role_code)
		AND (p_min_role_level IS NULL OR usi.role_level >= p_min_role_level)
		AND (p_query IS NULL OR usi.search_vector @@ plainto_tsquery('spanish', p_query))
	ORDER BY similarity DESC, usi.full_name
	LIMIT p_limit
	OFFSET p_offset;
END;
$$;

-- Function to create a notification from template
CREATE OR REPLACE FUNCTION create_notification_from_template(
	p_template_code TEXT,
	p_recipient_id UUID,
	p_variables JSONB DEFAULT '{}',
	p_sender_id UUID DEFAULT NULL,
	p_priority notification_priority DEFAULT NULL,
	p_related_entity_type TEXT DEFAULT NULL,
	p_related_entity_id UUID DEFAULT NULL,
	p_action_url TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
	v_template public.notification_templates%ROWTYPE;
	v_title TEXT;
	v_body TEXT;
	v_notification_id UUID;
	v_key TEXT;
	v_value TEXT;
BEGIN
	-- Get template
	SELECT * INTO v_template
	FROM public.notification_templates
	WHERE code = p_template_code AND is_active = TRUE;
	
	IF NOT FOUND THEN
		RAISE EXCEPTION 'Template not found: %', p_template_code;
	END IF;
	
	-- Process template variables
	v_title := v_template.title_template;
	v_body := v_template.body_template;
	
	-- Replace variables in title and body
	FOR v_key, v_value IN SELECT * FROM jsonb_each_text(p_variables)
	LOOP
		v_title := REPLACE(v_title, '{{' || v_key || '}}', v_value);
		v_body := REPLACE(v_body, '{{' || v_key || '}}', v_value);
	END LOOP;
	
	-- Create notification
	INSERT INTO public.notifications (
		type,
		priority,
		sender_id,
		recipient_id,
		title,
		body,
		data,
		related_entity_type,
		related_entity_id,
		action_url
	) VALUES (
		v_template.type,
		COALESCE(p_priority, v_template.default_priority),
		p_sender_id,
		p_recipient_id,
		v_title,
		v_body,
		jsonb_build_object(
			'template_code', p_template_code,
			'variables', p_variables
		),
		p_related_entity_type,
		p_related_entity_id,
		p_action_url
	) RETURNING id INTO v_notification_id;
	
	-- Create delivery records for default channels
	INSERT INTO public.notification_deliveries (notification_id, channel)
	SELECT v_notification_id, unnest(v_template.default_channels);
	
	RETURN v_notification_id;
END;
$$;

-- Function to send notification to multiple users by role
CREATE OR REPLACE FUNCTION send_role_based_notification(
	p_role_codes TEXT[],
	p_title TEXT,
	p_body TEXT,
	p_min_role_level INTEGER DEFAULT NULL,
	p_type notification_type DEFAULT 'role_based',
	p_priority notification_priority DEFAULT 'medium',
	p_data JSONB DEFAULT '{}'
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
	v_count INTEGER := 0;
BEGIN
	-- Insert notifications for all matching users
	INSERT INTO public.notifications (
		type,
		priority,
		sender_id,
		sender_type,
		recipient_id,
		recipient_role_code,
		recipient_role_level,
		title,
		body,
		data
	)
	SELECT 
		p_type,
		p_priority,
		auth.uid(),
		'system',
		u.id,
		(u.raw_user_meta_data->>'role')::TEXT,
		(u.raw_user_meta_data->>'role_level')::INTEGER,
		p_title,
		p_body,
		p_data
	FROM auth.users u
	WHERE 
		(u.raw_user_meta_data->>'role')::TEXT = ANY(p_role_codes)
		AND (p_min_role_level IS NULL OR (u.raw_user_meta_data->>'role_level')::INTEGER >= p_min_role_level)
		AND u.deleted_at IS NULL;
	
	GET DIAGNOSTICS v_count = ROW_COUNT;
	RETURN v_count;
END;
$$;

-- Function to get unread notification count
CREATE OR REPLACE FUNCTION get_unread_notification_count(p_user_id UUID DEFAULT NULL)
RETURNS BIGINT
LANGUAGE sql
SECURITY INVOKER
SET search_path = ''
AS $$
	SELECT COUNT(*)
	FROM public.notifications
	WHERE 
		recipient_id = COALESCE(p_user_id, auth.uid())
		AND NOT is_read 
		AND NOT is_archived
		AND (expires_at IS NULL OR expires_at > NOW());
$$;

-- Function to mark notifications as read
CREATE OR REPLACE FUNCTION mark_notifications_read(p_notification_ids UUID[])
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
	v_count INTEGER;
BEGIN
	UPDATE public.notifications
	SET 
		is_read = TRUE,
		read_at = NOW()
	WHERE 
		id = ANY(p_notification_ids)
		AND recipient_id = auth.uid()
		AND NOT is_read;
	
	GET DIAGNOSTICS v_count = ROW_COUNT;
	RETURN v_count;
END;
$$;

-- Function to get notifications with pagination
CREATE OR REPLACE FUNCTION get_user_notifications(
	p_limit INTEGER DEFAULT 20,
	p_offset INTEGER DEFAULT 0,
	p_type notification_type DEFAULT NULL,
	p_priority notification_priority DEFAULT NULL,
	p_is_read BOOLEAN DEFAULT NULL,
	p_category TEXT DEFAULT NULL
)
RETURNS TABLE (
	id UUID,
	type notification_type,
	priority notification_priority,
	sender_id UUID,
	sender_name TEXT,
	title TEXT,
	body TEXT,
	data JSONB,
	is_read BOOLEAN,
	read_at TIMESTAMPTZ,
	created_at TIMESTAMPTZ,
	action_url TEXT,
	total_count BIGINT
)
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
BEGIN
	RETURN QUERY
	WITH filtered_notifications AS (
		SELECT 
			n.*,
			COUNT(*) OVER() AS total_count
		FROM public.notifications n
		WHERE 
			n.recipient_id = auth.uid()
			AND NOT n.is_archived
			AND (n.expires_at IS NULL OR n.expires_at > NOW())
			AND (p_type IS NULL OR n.type = p_type)
			AND (p_priority IS NULL OR n.priority = p_priority)
			AND (p_is_read IS NULL OR n.is_read = p_is_read)
			AND (p_category IS NULL OR n.category = p_category)
		ORDER BY n.created_at DESC
		LIMIT p_limit
		OFFSET p_offset
	)
	SELECT 
		fn.id,
		fn.type,
		fn.priority,
		fn.sender_id,
		CASE 
			WHEN fn.sender_type = 'system' THEN 'System'
			WHEN u.id IS NOT NULL THEN 
				COALESCE(u.raw_user_meta_data->>'first_name', '') || ' ' || 
				COALESCE(u.raw_user_meta_data->>'last_name', '')
			ELSE 'Unknown'
		END AS sender_name,
		fn.title,
		fn.body,
		fn.data,
		fn.is_read,
		fn.read_at,
		fn.created_at,
		fn.action_url,
		fn.total_count
	FROM filtered_notifications fn
	LEFT JOIN auth.users u ON fn.sender_id = u.id;
END;
$$;

-- Function to update user search index (triggered on user changes)
CREATE OR REPLACE FUNCTION update_user_search_index()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
	v_agreement_data RECORD;
BEGIN
	-- For user updates, refresh the search index
	IF TG_OP = 'UPDATE' OR TG_OP = 'INSERT' THEN
		-- Get user's agreement data
		SELECT 
			a.name || ' ' || a.last_name AS full_name,
			a.email,
			r.code AS role_code,
			r.name AS role_name,
			r.level AS role_level,
			h.name AS headquarter_name
		INTO v_agreement_data
		FROM public.agreements a
		JOIN public.roles r ON a.role_id = r.id
		LEFT JOIN public.headquarters h ON a.headquarter_id = h.id
		WHERE a.user_id = NEW.id
		AND a.status = 'active'
		LIMIT 1;
		
		IF FOUND THEN
			INSERT INTO public.user_search_index (
				user_id,
				full_name,
				email,
				role_code,
				role_name,
				role_level,
				headquarter_name,
				is_active
			) VALUES (
				NEW.id,
				v_agreement_data.full_name,
				v_agreement_data.email,
				v_agreement_data.role_code,
				v_agreement_data.role_name,
				v_agreement_data.role_level,
				v_agreement_data.headquarter_name,
				NEW.deleted_at IS NULL
			)
			ON CONFLICT (user_id) DO UPDATE SET
				full_name = EXCLUDED.full_name,
				email = EXCLUDED.email,
				role_code = EXCLUDED.role_code,
				role_name = EXCLUDED.role_name,
				role_level = EXCLUDED.role_level,
				headquarter_name = EXCLUDED.headquarter_name,
				is_active = EXCLUDED.is_active,
				updated_at = NOW();
		END IF;
	ELSIF TG_OP = 'DELETE' THEN
		-- Mark as inactive instead of deleting
		UPDATE public.user_search_index
		SET is_active = FALSE
		WHERE user_id = OLD.id;
	END IF;
	
	RETURN NEW;
END;
$$;

-- Function to clean up expired notifications
CREATE OR REPLACE FUNCTION cleanup_expired_notifications()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
	v_count INTEGER;
BEGIN
	DELETE FROM public.notifications
	WHERE expires_at < NOW()
	OR (is_archived AND archived_at < NOW() - INTERVAL '30 days');
	
	GET DIAGNOSTICS v_count = ROW_COUNT;
	RETURN v_count;
END;
$$;