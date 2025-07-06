-- Functions for the new home dashboard feature
-- Role-based dashboard statistics

-- Main function to get dashboard stats based on agreement
CREATE OR REPLACE FUNCTION get_home_dashboard_stats(p_agreement_id uuid)
    RETURNS jsonb
    LANGUAGE plpgsql
    SECURITY INVOKER
    SET search_path = ''
AS
$$
DECLARE
    v_result jsonb;
    v_tier integer;
    v_role_level integer;
    v_hq_id uuid;
    v_season_id uuid;
BEGIN
    -- Get agreement details and role level
    SELECT 
        r.level,
        a.headquarter_id,
        a.season_id
    INTO v_role_level, v_hq_id, v_season_id
    FROM public.agreements a
    JOIN public.roles r ON a.role_id = r.id
    WHERE a.id = p_agreement_id;

    -- Return empty if agreement not found
    IF v_role_level IS NULL THEN
        RETURN '{}'::jsonb;
    END IF;

    -- Determine user tier based on role level
    -- Tier 3: Leadership (level 51+)
    -- Tier 2: Operational Staff (level 20-50)
    -- Tier 1: Students (level < 20)
    IF v_role_level >= 51 THEN
        v_tier := 3;
    ELSIF v_role_level >= 20 THEN
        v_tier := 2;
    ELSE
        v_tier := 1;
    END IF;

    -- Build response based on tier
    v_result := jsonb_build_object('tier', v_tier);

    -- Add tier-specific metrics
    IF v_tier = 3 THEN
        -- Leadership tier gets organization-wide metrics
        v_result := v_result || jsonb_build_object(
            'metrics', public.get_organization_overview(),
            'recent_agreements', (
                SELECT jsonb_agg(
                    jsonb_build_object(
                        'id', a.id,
                        'status', a.status,
                        'role_name', r.name,
                        'headquarter_name', h.name,
                        'created_at', a.created_at
                    )
                )
                FROM (
                    SELECT a.*, row_number() OVER (ORDER BY a.created_at DESC) as rn
                    FROM public.agreements a
                    WHERE a.created_at >= CURRENT_DATE - INTERVAL '7 days'
                ) a
                JOIN public.roles r ON a.role_id = r.id
                JOIN public.headquarters h ON a.headquarter_id = h.id
                WHERE a.rn <= 10
            )
        );
    ELSIF v_tier = 2 THEN
        -- Operational staff gets HQ-specific metrics
        v_result := v_result || jsonb_build_object(
            'metrics', public.get_headquarter_quick_stats(v_hq_id),
            'headquarter_info', (
                SELECT jsonb_build_object(
                    'id', h.id,
                    'name', h.name,
                    'address', h.address,
                    'country', c.name
                )
                FROM public.headquarters h
                LEFT JOIN public.countries c ON h.country_id = c.id
                WHERE h.id = v_hq_id
            )
        );
    ELSE
        -- Students get their agreement summary
        v_result := v_result || jsonb_build_object(
            'agreement', public.get_my_agreement_summary(p_agreement_id)
        );
    END IF;

    -- Add recent activities for all tiers
    v_result := v_result || jsonb_build_object(
        'recent_activities', public.get_recent_activities(p_agreement_id, v_role_level, 10)
    );

    RETURN v_result;
END;
$$;

-- Get agreement summary for a specific agreement
CREATE OR REPLACE FUNCTION get_my_agreement_summary(p_agreement_id uuid)
    RETURNS jsonb
    LANGUAGE plpgsql
    SECURITY INVOKER
    SET search_path = ''
AS
$$
DECLARE
    v_result jsonb;
BEGIN
    SELECT jsonb_build_object(
        'id', a.id,
        'status', a.status,
        'role', r.code,
        'role_name', r.name,
        'role_level', r.level,
        'headquarter_id', h.id,
        'headquarter_name', h.name,
        'season_id', s.id,
        'season_name', s.name,
        'name', a.name,
        'last_name', a.last_name,
        'email', a.email,
        'phone', a.phone,
        'activation_date', a.activation_date,
        'created_at', a.created_at
    )
    INTO v_result
    FROM public.agreements a
    JOIN public.roles r ON a.role_id = r.id
    JOIN public.headquarters h ON a.headquarter_id = h.id
    JOIN public.seasons s ON a.season_id = s.id
    WHERE a.id = p_agreement_id;

    RETURN COALESCE(v_result, '{}'::jsonb);
END;
$$;

-- Get recent activities based on agreement and role level
CREATE OR REPLACE FUNCTION get_recent_activities(p_agreement_id uuid, p_role_level integer, p_limit integer DEFAULT 10)
    RETURNS jsonb
    LANGUAGE plpgsql
    SECURITY INVOKER
    SET search_path = ''
AS
$$
DECLARE
    v_activities jsonb;
    v_hq_id uuid;
BEGIN
    -- Get agreement's HQ ID
    SELECT headquarter_id
    INTO v_hq_id
    FROM public.agreements
    WHERE id = p_agreement_id;

    -- Role level 51+ sees all activities
    IF p_role_level >= 51 THEN
        SELECT jsonb_agg(activity)
        INTO v_activities
        FROM (
            SELECT jsonb_build_object(
                'id', e.id,
                'type', 'event',
                'title', et.name,
                'description', e.description,
                'timestamp', e.created_at,
                'headquarter', h.name
            ) as activity
            FROM public.events e
            JOIN public.event_types et ON e.event_type_id = et.id
            LEFT JOIN public.headquarters h ON e.headquarter_id = h.id
            ORDER BY e.created_at DESC
            LIMIT p_limit
        ) t;
    -- Role level 20-50 sees HQ-specific activities
    ELSIF p_role_level >= 20 THEN
        SELECT jsonb_agg(activity)
        INTO v_activities
        FROM (
            SELECT jsonb_build_object(
                'id', e.id,
                'type', 'event',
                'title', et.name,
                'description', e.description,
                'timestamp', e.created_at
            ) as activity
            FROM public.events e
            JOIN public.event_types et ON e.event_type_id = et.id
            WHERE e.headquarter_id = v_hq_id
            ORDER BY e.created_at DESC
            LIMIT p_limit
        ) t;
    -- Students see their own activities
    ELSE
        SELECT jsonb_agg(activity)
        INTO v_activities
        FROM (
            -- Workshop attendance
            SELECT jsonb_build_object(
                'id', sa.id,
                'type', 'attendance',
                'title', 'Workshop Attendance',
                'description', 'Attended workshop on ' || sw.start_datetime::text,
                'timestamp', sa.created_at
            ) as activity
            FROM public.student_attendance sa
            JOIN public.scheduled_workshops sw ON sa.scheduled_workshop_id = sw.id
            JOIN public.students s ON sa.student_id = s.user_id
            JOIN public.agreements a ON s.user_id = a.user_id
            WHERE a.id = p_agreement_id
            ORDER BY sa.created_at DESC
            LIMIT p_limit
        ) t;
    END IF;

    RETURN COALESCE(v_activities, '[]'::jsonb);
END;
$$;

-- Get quick stats for a specific headquarter
CREATE OR REPLACE FUNCTION get_headquarter_quick_stats(p_headquarter_id uuid)
    RETURNS jsonb
    LANGUAGE plpgsql
    SECURITY INVOKER
    SET search_path = ''
AS
$$
DECLARE
    v_stats jsonb;
BEGIN
    SELECT jsonb_build_object(
        'active_agreements_count', (
            SELECT COUNT(*)
            FROM public.agreements
            WHERE headquarter_id = p_headquarter_id
              AND status IN ('active', 'signed')
        ),
        'facilitators_count', (
            SELECT COUNT(DISTINCT a.id)
            FROM public.agreements a
            JOIN public.roles r ON a.role_id = r.id
            WHERE a.headquarter_id = p_headquarter_id
              AND r.code = 'facilitator'
              AND a.status IN ('active', 'signed')
        ),
        'companions_count', (
            SELECT COUNT(DISTINCT a.id)
            FROM public.agreements a
            JOIN public.roles r ON a.role_id = r.id
            WHERE a.headquarter_id = p_headquarter_id
              AND r.code = 'companion'
              AND a.status IN ('active', 'signed')
        ),
        'students', jsonb_build_object(
            'active', (
                SELECT COUNT(*)
                FROM public.students s
                JOIN public.agreements a ON s.user_id = a.user_id
                WHERE a.headquarter_id = p_headquarter_id
                  AND s.status = 'active'
            ),
            'inactive', (
                SELECT COUNT(*)
                FROM public.students s
                JOIN public.agreements a ON s.user_id = a.user_id
                WHERE a.headquarter_id = p_headquarter_id
                  AND s.status = 'inactive'
            ),
            'prospects', (
                SELECT COUNT(*)
                FROM public.agreements a
                JOIN public.roles r ON a.role_id = r.id
                WHERE a.headquarter_id = p_headquarter_id
                  AND r.code = 'student'
                  AND a.status = 'prospect'
            )
        ),
        'upcoming_workshops', (
            SELECT COUNT(*)
            FROM public.scheduled_workshops
            WHERE headquarter_id = p_headquarter_id
              AND start_datetime >= CURRENT_DATE
              AND start_datetime <= CURRENT_DATE + INTERVAL '7 days'
        )
    ) INTO v_stats;

    RETURN v_stats;
END;
$$;

-- Get organization-wide overview (for leadership roles)
CREATE OR REPLACE FUNCTION get_organization_overview()
    RETURNS jsonb
    LANGUAGE plpgsql
    SECURITY INVOKER
    SET search_path = ''
AS
$$
DECLARE
    v_overview jsonb;
BEGIN
    SELECT jsonb_build_object(
        'total_headquarters', (
            SELECT COUNT(*)
            FROM public.headquarters
            WHERE status = 'active'
        ),
        'total_active_agreements', (
            SELECT COUNT(*)
            FROM public.agreements
            WHERE status IN ('active', 'signed')
        ),
        'total_students', (
            SELECT COUNT(*)
            FROM public.students
            WHERE status = 'active'
        ),
        'agreements_by_status', (
            SELECT jsonb_object_agg(status, count)
            FROM (
                SELECT status, COUNT(*) as count
                FROM public.agreements
                GROUP BY status
            ) t
        ),
        'students_by_headquarter', (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'headquarter', h.name,
                    'count', student_count
                )
            )
            FROM (
                SELECT a.headquarter_id, COUNT(DISTINCT s.id) as student_count
                FROM public.students s
                JOIN public.agreements a ON s.user_id = a.user_id
                WHERE s.status = 'active'
                GROUP BY a.headquarter_id
                ORDER BY student_count DESC
                LIMIT 10
            ) t
            JOIN public.headquarters h ON t.headquarter_id = h.id
        ),
        'system_health', jsonb_build_object(
            'status', CASE
                WHEN (SELECT COUNT(*) FROM public.agreements WHERE created_at >= CURRENT_DATE - INTERVAL '1 day') > 0
                THEN 'healthy'
                ELSE 'warning'
            END,
            'message', 'System operational'
        )
    ) INTO v_overview;

    RETURN v_overview;
END;
$$;

-- Grant permissions (updated for agreement-based functions)
GRANT EXECUTE ON FUNCTION public.get_home_dashboard_stats(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_agreement_summary(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_recent_activities(uuid, integer, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_headquarter_quick_stats(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_organization_overview() TO authenticated;