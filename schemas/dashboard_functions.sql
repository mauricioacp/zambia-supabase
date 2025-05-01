-- Functions for dashboard statistics

-- Function to get global dashboard statistics (accessible only by roles >= 80)
CREATE OR REPLACE FUNCTION get_global_dashboard_stats()
    RETURNS jsonb
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = ''
AS $$
DECLARE
    current_role_level integer;
    total_headquarters bigint;
    total_collaborators bigint;
    total_students bigint;
    total_active_seasons bigint;
    total_agreements bigint;
    agreements_prospect bigint;
    agreements_active bigint;
    agreements_inactive bigint;
    agreements_graduated bigint;
    agreements_this_year bigint;
    stats jsonb;
    total_workshops bigint;
    total_events bigint;
    avg_days_prospect_to_active numeric;
BEGIN
    current_role_level := public.fn_get_current_role_level();
    -- Standardized: Only Konsejo Member+ (80+) can access global dashboard stats
    IF current_role_level < 80 THEN
        RAISE EXCEPTION 'Insufficient privileges to access global dashboard statistics. Required level: 80 (Konsejo Member+), Your level: %', current_role_level;
    END IF;

    -- Count headquarters, collaborators, students
    SELECT COUNT(*) INTO total_headquarters FROM public.headquarters WHERE status = 'active';
    SELECT COUNT(*) INTO total_collaborators FROM public.collaborators WHERE status = 'active';
    SELECT COUNT(*) INTO total_students FROM public.students WHERE status = 'active';
    SELECT COUNT(*) INTO total_active_seasons FROM public.seasons WHERE status = 'active';

    -- Count agreements by status
    SELECT
        COUNT(*) AS total,
        COUNT(*) FILTER (WHERE status = 'prospect') AS prospect,
        COUNT(*) FILTER (WHERE status = 'active') AS active,
        COUNT(*) FILTER (WHERE status = 'inactive') AS inactive,
        COUNT(*) FILTER (WHERE status = 'graduated') AS graduated,
        COUNT(*) FILTER (WHERE created_at >= date_trunc('year', current_date)) AS this_year
    INTO
        total_agreements,
        agreements_prospect,
        agreements_active,
        agreements_inactive,
        agreements_graduated,
        agreements_this_year
    FROM agreements;

    -- Count scheduled_workshops and events associated with active seasons
    SELECT COUNT(w.*) INTO total_workshops
    FROM scheduled_workshops w
             JOIN seasons s ON w.season_id = s.id
    WHERE s.status = 'active';

    SELECT COUNT(e.*) INTO total_events
    FROM events e
             JOIN seasons s ON e.season_id = s.id
    WHERE s.status = 'active'; -- Only count events in currently active seasons

    -- Calculate average time from prospect to active status
    SELECT AVG(EXTRACT(EPOCH FROM (activation_date - created_at)) / 86400.0) -- 86400 seconds in a day
    INTO avg_days_prospect_to_active
    FROM agreements
    WHERE status IN ('active', 'graduated')
      AND activation_date IS NOT NULL
      AND created_at IS NOT NULL
      AND activation_date > created_at;

    -- Construct the JSON response
    stats := jsonb_build_object(
            'total_headquarters', total_headquarters,
            'total_collaborators', total_collaborators,
            'total_students', total_students,
            'total_agreements_all_time', total_agreements,
            'total_agreements_prospect', agreements_prospect,
            'total_agreements_active', agreements_active,
            'total_agreements_inactive', agreements_inactive,
            'total_agreements_graduated', agreements_graduated,
            'total_agreements_this_year', agreements_this_year,
            'percentage_agreements_active', CASE WHEN total_agreements > 0 THEN ROUND((agreements_active::numeric / total_agreements) * 100, 2) ELSE 0 END,
            'percentage_agreements_prospect', CASE WHEN total_agreements > 0 THEN ROUND((agreements_prospect::numeric / total_agreements) * 100, 2) ELSE 0 END,
            'percentage_agreements_graduated', CASE WHEN total_agreements > 0 THEN ROUND((agreements_graduated::numeric / total_agreements) * 100, 2) ELSE 0 END,
            'total_active_seasons', total_active_seasons,
            'total_workshops_active_seasons', total_workshops,
            'total_events_active_seasons', total_events,
            'avg_days_prospect_to_active', COALESCE(ROUND(avg_days_prospect_to_active, 2), 0)
             );

    RETURN stats;
END;
$$;

-- Grant execute permission to authenticated users
-- The permission check is done inside the function
GRANT EXECUTE ON FUNCTION get_global_dashboard_stats() TO authenticated;

-- Function to get dashboard statistics for a specific headquarters
-- Accessible by users belonging to that HQ or roles >= 70
CREATE OR REPLACE FUNCTION get_headquarter_dashboard_stats(target_hq_id uuid)
    RETURNS jsonb -- Changed return type to jsonb for flexibility
    LANGUAGE plpgsql
    SECURITY DEFINER -- Allows bypassing RLS for counting, but we check permission first
    SET search_path = ''
AS $$
DECLARE
    current_role_level integer;
    current_user_hq_id uuid;
    is_authorized boolean := false;
    stats jsonb;
    -- Counts
    hq_active_students_count bigint;
    hq_active_collaborators_count bigint;
    hq_manager_assistants_count bigint; -- Role Level >= 50
    hq_agreements_total bigint;
    hq_agreements_prospect bigint;
    hq_agreements_active bigint;
    hq_agreements_inactive bigint;
    hq_agreements_graduated bigint;
    hq_agreements_this_year bigint;
    hq_agreements_last_3_months bigint;
    -- Distributions
    student_age_distribution jsonb;
    collaborator_age_distribution jsonb;
    student_gender_distribution jsonb;
    collaborator_gender_distribution jsonb;
    -- Workshop & Event metrics
    workshops_count bigint;
    events_count bigint;
    avg_student_attendance_rate numeric;
    avg_days_prospect_to_active numeric;
    -- HQ info
    hq_name text;
BEGIN
    -- Get current user's role level and HQ ID
    current_role_level := public.fn_get_current_role_level();
    current_user_hq_id := public.fn_get_current_hq_id(); -- Use single HQ ID function

    -- Permission Check:
    -- Allow if user is Konsejo Member+ (>=80) OR (Manager+ (>=50) AND target_hq_id is their HQ)
    IF current_role_level >= 80 THEN
        is_authorized := true;
    ELSIF current_role_level >= 50 AND target_hq_id = current_user_hq_id THEN
        is_authorized := true;
    END IF;

    IF NOT is_authorized THEN
        RAISE EXCEPTION 'Insufficient privileges (level % requires >= 80 or >= 50 for own HQ) to access dashboard for headquarter ID %.', current_role_level, target_hq_id;
    END IF;

    -- Fetch HQ Name
    SELECT name INTO hq_name FROM headquarters WHERE id = target_hq_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Headquarter with ID % not found.', target_hq_id;
    END IF;

    -- Calculate stats for the target headquarter (SECURITY DEFINER bypasses RLS here)

    -- Student and Collaborator Counts
    SELECT COUNT(*) INTO hq_active_students_count
    FROM students WHERE headquarter_id = target_hq_id AND status = 'active';

    SELECT COUNT(*) INTO hq_active_collaborators_count
    FROM collaborators WHERE headquarter_id = target_hq_id AND status = 'active';

    -- Student gender distribution
    SELECT jsonb_object_agg(gender, count) INTO student_gender_distribution
    FROM (
             SELECT COALESCE(gender, 'unknown') as gender, COUNT(*) as count
             FROM agreements a
                      JOIN students s ON a.user_id = s.user_id
             WHERE s.headquarter_id = target_hq_id AND s.status = 'active'
             GROUP BY gender
         ) genders;

    -- Student age distribution
    SELECT jsonb_object_agg(age_group, count) INTO student_age_distribution
    FROM (
             SELECT
                 CASE
                     WHEN age < 18 THEN '<18'
                     WHEN age BETWEEN 18 AND 24 THEN '18-24'
                     WHEN age BETWEEN 25 AND 34 THEN '25-34'
                     WHEN age BETWEEN 35 AND 44 THEN '35-44'
                     WHEN age BETWEEN 45 AND 54 THEN '45-54'
                     WHEN age >= 55 THEN '55+'
                     ELSE 'Unknown'
                     END as age_group,
                 COUNT(*) as count
             FROM (
                      SELECT date_part('year', age(birth_date)) as age
                      FROM agreements a
                               JOIN students s ON a.user_id = s.user_id
                      WHERE s.headquarter_id = target_hq_id AND s.status = 'active' AND birth_date IS NOT NULL
                  ) ages
             GROUP BY age_group
         ) grouped_ages;

    -- Collaborator gender distribution
    SELECT jsonb_object_agg(gender, count) INTO collaborator_gender_distribution
    FROM (
             SELECT COALESCE(gender, 'Unknown') as gender, COUNT(*) as count
             FROM agreements a
                      JOIN collaborators c ON a.user_id = c.user_id
             WHERE c.headquarter_id = target_hq_id AND c.status = 'active'
             GROUP BY gender
         ) genders;

    -- Collaborator age distribution
    SELECT jsonb_object_agg(age_group, count) INTO collaborator_age_distribution
    FROM (
             SELECT
                 CASE
                     WHEN age < 18 THEN '<18'
                     WHEN age BETWEEN 18 AND 24 THEN '18-24'
                     WHEN age BETWEEN 25 AND 34 THEN '25-34'
                     WHEN age BETWEEN 35 AND 44 THEN '35-44'
                     WHEN age BETWEEN 45 AND 54 THEN '45-54'
                     WHEN age >= 55 THEN '55+'
                     ELSE 'Unknown'
                     END as age_group,
                 COUNT(*) as count
             FROM (
                      SELECT date_part('year', age(birth_date)) as age
                      FROM agreements a
                               JOIN collaborators c ON a.user_id = c.user_id
                      WHERE c.headquarter_id = target_hq_id AND c.status = 'active' AND birth_date IS NOT NULL
                  ) ages
             GROUP BY age_group
         ) grouped_ages;

    -- Count Manager Assistants+ (role level >= 50)
    SELECT COUNT(c.*) INTO hq_manager_assistants_count
    FROM collaborators c
             JOIN roles r ON c.role_id = r.id
    WHERE c.headquarter_id = target_hq_id AND c.status = 'active' AND r.level >= 50;

    -- Agreement Counts
    SELECT
        COUNT(*) AS total,
        COUNT(*) FILTER (WHERE status = 'prospect') AS prospect,
        COUNT(*) FILTER (WHERE status = 'active') AS active,
        COUNT(*) FILTER (WHERE status = 'inactive') AS inactive,
        COUNT(*) FILTER (WHERE status = 'graduated') AS graduated,
        COUNT(*) FILTER (WHERE created_at >= date_trunc('year', current_date)) AS this_year,
        COUNT(*) FILTER (WHERE created_at >= current_date - interval '3 months') AS last_3_months
    INTO
        hq_agreements_total,
        hq_agreements_prospect,
        hq_agreements_active,
        hq_agreements_inactive,
        hq_agreements_graduated,
        hq_agreements_this_year,
        hq_agreements_last_3_months
    FROM agreements
    WHERE headquarter_id = target_hq_id;

    -- Calculate average time from prospect to active status
    SELECT AVG(EXTRACT(EPOCH FROM (activation_date - created_at)) / 86400.0) -- 86400 seconds in a day
    INTO avg_days_prospect_to_active
    FROM agreements
    WHERE headquarter_id = target_hq_id
      AND status IN ('active', 'graduated')
      AND activation_date IS NOT NULL
      AND created_at IS NOT NULL
      AND activation_date > created_at;

    -- Workshops and Events count
    SELECT COUNT(*) INTO workshops_count
    FROM scheduled_workshops
    WHERE headquarter_id = target_hq_id
      AND season_id IN (SELECT id FROM seasons WHERE status = 'active');

    SELECT COUNT(*) INTO events_count
    FROM events
    WHERE headquarter_id = target_hq_id
      AND season_id IN (SELECT id FROM seasons WHERE status = 'active');

    -- Student attendance rate (across all workshops in active seasons)
    SELECT COALESCE(AVG(CASE WHEN attendance_status = 'present' THEN 100.0 ELSE 0.0 END), 0)
    INTO avg_student_attendance_rate
    FROM student_attendance sa
             JOIN scheduled_workshops sw ON sa.scheduled_workshop_id = sw.id
             JOIN students s ON sa.student_id = s.user_id
    WHERE s.headquarter_id = target_hq_id
      AND sw.season_id IN (SELECT id FROM seasons WHERE status = 'active');

    -- Construct JSON response
    stats := jsonb_build_object(
            'headquarter_id', target_hq_id,
            'headquarter_name', hq_name,
            'active_students_count', hq_active_students_count,
            'active_collaborators_count', hq_active_collaborators_count,
            'manager_assistants_count', hq_manager_assistants_count,
            'student_age_distribution', COALESCE(student_age_distribution, '{}'::jsonb),
            'student_gender_distribution', COALESCE(student_gender_distribution, '{}'::jsonb),
            'collaborator_age_distribution', COALESCE(collaborator_age_distribution, '{}'::jsonb),
            'collaborator_gender_distribution', COALESCE(collaborator_gender_distribution, '{}'::jsonb),
            'agreements_total', hq_agreements_total,
            'agreements_prospect', hq_agreements_prospect,
            'agreements_active', hq_agreements_active,
            'agreements_inactive', hq_agreements_inactive,
            'agreements_graduated', hq_agreements_graduated,
            'agreements_this_year', hq_agreements_this_year,
            'agreements_last_3_months', hq_agreements_last_3_months,
            'agreements_active_percentage', CASE WHEN hq_agreements_total > 0 THEN ROUND((hq_agreements_active::numeric / hq_agreements_total) * 100, 2) ELSE 0 END,
            'agreements_prospect_percentage', CASE WHEN hq_agreements_total > 0 THEN ROUND((hq_agreements_prospect::numeric / hq_agreements_total) * 100, 2) ELSE 0 END,
            'agreements_graduated_percentage', CASE WHEN hq_agreements_total > 0 THEN ROUND((hq_agreements_graduated::numeric / hq_agreements_total) * 100, 2) ELSE 0 END,
            'workshops_count', workshops_count,
            'events_count', events_count,
            'avg_student_attendance_rate', ROUND(avg_student_attendance_rate, 2),
            'avg_days_prospect_to_active', COALESCE(ROUND(avg_days_prospect_to_active, 2), 0)
             );

    RETURN stats;
END;
$$;

-- Grant execute permission (permissions checked internally)
GRANT EXECUTE ON FUNCTION get_headquarter_dashboard_stats(uuid) TO authenticated;

-- Function to get dashboard statistics for a specific user
-- Accessible by the user themselves, managers (>=50) in the same HQ, or directors (>=90)
CREATE OR REPLACE FUNCTION get_user_dashboard_stats(target_user_id uuid)
    RETURNS jsonb
    LANGUAGE plpgsql
    SECURITY DEFINER -- Allows bypassing RLS for data fetching, but we check permission first
AS $$
DECLARE
    invoker_user_id uuid;
    invoker_role_level integer;
    invoker_hq_id uuid; -- Changed from uuid[]
    target_agreement RECORD;
    target_role RECORD;
    target_hq RECORD;
    target_season RECORD;
    target_person RECORD; -- Can be student or collaborator details
    target_user_email text;
    stats jsonb;
    target_user_type text := 'Unknown';
    target_record_id uuid := NULL;
    target_full_name text := NULL;
    is_authorized boolean := false;
    -- Student specific
    student_attendance_rate numeric;
    student_schedule jsonb;
    student_companion_info jsonb;
    -- Companion specific
    companion_assigned_students jsonb;
    companion_student_count integer;
    -- Facilitator specific
    facilitator_workshops_count integer;
    facilitator_upcoming_workshops jsonb;
    collaborator_details jsonb;
BEGIN
    -- Get invoker details
    invoker_user_id := auth.uid();
    invoker_role_level := fn_get_current_role_level();
    invoker_hq_id := fn_get_current_hq_id(); -- Use single HQ ID function

    -- Find the target user's *single latest active* agreement
    SELECT a.* INTO target_agreement
    FROM agreements a
             JOIN seasons s ON a.season_id = s.id
    WHERE a.user_id = target_user_id AND s.status = 'active'
    ORDER BY s.start_date DESC
    LIMIT 1;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'No active agreement found for user ID %.', target_user_id;
    END IF;

    -- Permission Check:
    -- Allow if invoker is the target user OR invoker is Director+ (>=90) OR invoker is Manager+ (>=50) in the same HQ as the target user
    IF invoker_user_id = target_user_id THEN
        is_authorized := true;
    ELSIF invoker_role_level >= 90 THEN
        is_authorized := true;
    ELSIF invoker_role_level >= 50 AND target_agreement.headquarter_id = invoker_hq_id THEN -- Check against single HQ ID
        is_authorized := true;
    END IF;

    IF NOT is_authorized THEN
        RAISE EXCEPTION 'Insufficient privileges (level % requires self, >= 90, or >= 50 for same HQ) to access dashboard for user ID %.', invoker_role_level, target_user_id;
    END IF;

    -- Fetch associated records (SECURITY DEFINER bypasses RLS)
    SELECT * INTO target_hq FROM headquarters WHERE id = target_agreement.headquarter_id;
    SELECT * INTO target_season FROM seasons WHERE id = target_agreement.season_id;
    SELECT email INTO target_user_email FROM auth.users WHERE id = target_user_id;
    -- Check if the user is a student or collaborator based on the agreement/role
    SELECT * INTO target_role FROM roles WHERE id = target_agreement.role_id;

    -- Determine if this is a student or collaborator
    IF target_role.name = 'Student' THEN
        target_user_type := 'Student';
        -- Try to find student record
        SELECT s.id, s.user_id, s.status,
               (a.name || ' ' || a.last_name) as full_name
        INTO target_person
        FROM students s
                 JOIN agreements a ON s.user_id = a.user_id
        WHERE s.user_id = target_user_id
        LIMIT 1;
    ELSE
        target_user_type := 'Collaborator';
        -- Try to find collaborator record
        SELECT c.id, c.user_id, c.status,
               (a.name || ' ' || a.last_name) as full_name
        INTO target_person
        FROM collaborators c
                 JOIN agreements a ON c.user_id = a.user_id
        WHERE c.user_id = target_user_id
        LIMIT 1;
    END IF;

    -- Set default full name if not found
    IF target_person IS NULL THEN
        target_full_name := COALESCE(target_agreement.name || ' ' || target_agreement.last_name, 'Record Not Found for Role');
    ELSE
        target_full_name := COALESCE(target_person.full_name, 'Name Not Available');
    END IF;

    -- Calculate Role-Specific Stats
    IF target_user_type = 'Student' AND target_person IS NOT NULL THEN
        -- Attendance Rate (for active season workshops)
        SELECT
            COALESCE(
                    ROUND(
                            (SUM(CASE WHEN sa.attendance_status = 'present' THEN 1 ELSE 0 END)::numeric /
                             NULLIF(COUNT(*), 0)) * 100,
                            2
                    ),
                    0
            )
        INTO student_attendance_rate
        FROM student_attendance sa
                 JOIN scheduled_workshops sw ON sa.scheduled_workshop_id = sw.id
        WHERE sa.student_id = target_user_id
          AND sw.season_id = target_season.id;

        -- Schedule (upcoming workshops in active season/HQ)
        WITH UpcomingWorkshops AS (
            SELECT
                sw.id as item_id,
                sw.local_name as item_name,
                sw.start_datetime as item_date,
                'workshop' as item_type,
                mwt.name as workshop_type
            FROM scheduled_workshops sw
                     JOIN master_workshop_types mwt ON sw.master_workshop_type_id = mwt.id
            WHERE sw.headquarter_id = target_hq.id
              AND sw.season_id = target_season.id
              AND sw.start_datetime >= current_date
              AND sw.status = 'scheduled'
        ),
             UpcomingEvents AS (
                 SELECT
                     e.id as item_id,
                     e.title as item_name,
                     e.start_datetime as item_date,
                     'event' as item_type,
                     et.name as event_type
                 FROM events e
                          JOIN event_types et ON e.event_type_id = et.id
                 WHERE e.headquarter_id = target_hq.id
                   AND e.season_id = target_season.id
                   AND e.start_datetime >= current_date
                   AND e.status = 'scheduled'
             ),
             CombinedSchedule AS (
                 SELECT item_id, item_name, item_date, item_type, workshop_type as type_name FROM UpcomingWorkshops
                 UNION ALL
                 SELECT item_id, item_name, item_date, item_type, event_type as type_name FROM UpcomingEvents
             )
        SELECT COALESCE(jsonb_agg(jsonb_build_object(
                                          'item_id', cs.item_id,
                                          'item_name', cs.item_name,
                                          'item_date', cs.item_date,
                                          'item_type', cs.item_type,
                                          'type_name', cs.type_name
                                  ) ORDER BY cs.item_date ASC), '[]'::jsonb)
        INTO student_schedule
        FROM CombinedSchedule cs;

        -- Companion Info
        SELECT jsonb_build_object(
                       'companion_id', csm.companion_id,
                       'name', a.name,
                       'last_name', a.last_name,
                       'email', a.email
               )
        INTO student_companion_info
        FROM companion_student_map csm
                 JOIN agreements a ON csm.companion_id = a.user_id
        WHERE csm.student_id = target_user_id
          AND csm.season_id = target_season.id
        LIMIT 1; -- Assuming one companion per student per season

        -- Construct the student stats
        stats := jsonb_build_object(
                'user_id', target_user_id,
                'user_email', target_user_email,
                'user_type', target_user_type,
                'full_name', target_full_name,
                'role_name', target_role.name,
                'role_level', target_role.level,
                'headquarter_id', target_hq.id,
                'headquarter_name', target_hq.name,
                'season_id', target_season.id,
                'season_name', target_season.name,
                'season_start_date', target_season.start_date,
                'season_end_date', target_season.end_date,
                'agreement_status', target_agreement.status,
                'attendance_rate', student_attendance_rate,
                'upcoming_schedule', student_schedule,
                'companion_info', COALESCE(student_companion_info, '{}'::jsonb)
                 );

    ELSIF target_user_type = 'Collaborator' AND target_person IS NOT NULL THEN
        -- Base details for any collaborator
        collaborator_details := jsonb_build_object(
                'collaborator_id', target_user_id,
                'status', target_person.status,
                'role', target_role.name,
                'headquarter_id', target_agreement.headquarter_id,
                'headquarter_name', target_hq.name
                                );

        -- Add role-specific details for collaborators
        IF target_role.name = 'Companion' THEN
            -- Get assigned students count
            SELECT COUNT(*) INTO companion_student_count
            FROM companion_student_map
            WHERE companion_id = target_user_id
              AND season_id = target_season.id;

            -- Get assigned students details
            SELECT COALESCE(jsonb_agg(jsonb_build_object(
                    'student_id', s.user_id,
                    'name', a.name,
                    'last_name', a.last_name,
                    'status', s.status,
                    'email', a.email
                                      )), '[]'::jsonb)
            INTO companion_assigned_students
            FROM companion_student_map csm
                     JOIN students s ON csm.student_id = s.user_id
                     JOIN agreements a ON s.user_id = a.user_id
            WHERE csm.companion_id = target_user_id
              AND csm.season_id = target_season.id;

            -- Logic specific to Companions
            collaborator_details := collaborator_details || jsonb_build_object(
                    'assigned_students_count', companion_student_count,
                    'assigned_students', companion_assigned_students
                                                            );

        ELSIF target_role.name = 'Facilitator' THEN
            -- Count workshops
            SELECT COUNT(*) INTO facilitator_workshops_count
            FROM scheduled_workshops
            WHERE facilitator_id = target_user_id
              AND season_id = target_season.id;

            -- Get upcoming workshops
            SELECT COALESCE(jsonb_agg(jsonb_build_object(
                                              'workshop_id', sw.id,
                                              'workshop_name', sw.local_name,
                                              'start_datetime', sw.start_datetime,
                                              'end_datetime', sw.end_datetime,
                                              'workshop_type', mwt.name,
                                              'status', sw.status
                                      ) ORDER BY sw.start_datetime ASC), '[]'::jsonb)
            INTO facilitator_upcoming_workshops
            FROM scheduled_workshops sw
                     JOIN master_workshop_types mwt ON sw.master_workshop_type_id = mwt.id
            WHERE sw.facilitator_id = target_user_id
              AND sw.season_id = target_season.id
              AND sw.start_datetime >= current_date
              AND sw.status = 'scheduled';

            -- Logic specific to Facilitators
            collaborator_details := collaborator_details || jsonb_build_object(
                    'workshops_count', facilitator_workshops_count,
                    'upcoming_workshops', facilitator_upcoming_workshops
                                                            );
            -- Add other ELSIF branches for other specific collaborator roles if needed
        END IF; -- End specific collaborator role checks

        -- Add the collaborator-specific details to the main stats object
        stats := jsonb_build_object(
                'user_id', target_user_id,
                'user_email', target_user_email,
                'user_type', target_user_type,
                'full_name', target_full_name,
                'role_name', target_role.name,
                'role_level', target_role.level,
                'headquarter_id', target_hq.id,
                'headquarter_name', target_hq.name,
                'season_id', target_season.id,
                'season_name', target_season.name,
                'season_start_date', target_season.start_date,
                'season_end_date', target_season.end_date,
                'agreement_status', target_agreement.status,
                'collaborator_details', collaborator_details
                 );
    ELSE
        -- Basic info if specific role details not available
        stats := jsonb_build_object(
                'user_id', target_user_id,
                'user_email', target_user_email,
                'user_type', target_user_type,
                'full_name', target_full_name,
                'role_name', COALESCE(target_role.name, 'Unknown'),
                'role_level', COALESCE(target_role.level, 0),
                'headquarter_id', target_hq.id,
                'headquarter_name', target_hq.name,
                'season_id', target_season.id,
                'season_name', target_season.name,
                'agreement_status', target_agreement.status
                 );
    END IF;

    RETURN stats;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_user_dashboard_stats(uuid) TO authenticated;

-- Function for Companions: Get assigned students who missed workshops
CREATE OR REPLACE FUNCTION get_companion_student_attendance_issues(last_n_items integer DEFAULT 5)
    RETURNS TABLE (
                      student_id uuid,
                      student_first_name text,
                      student_last_name text,
                      missed_workshops_count bigint,
                      total_workshops_count bigint,
                      attendance_percentage numeric
                  )
    LANGUAGE plpgsql
    SECURITY INVOKER -- Run as the caller, RLS on underlying tables will apply implicitly
    SET search_path = ''
AS $$
DECLARE
    caller_id uuid := auth.uid();
    is_companion boolean := false;
BEGIN
    -- Verify the caller is currently mapped as a companion to at least one student
    SELECT EXISTS (SELECT 1 FROM companion_student_map WHERE companion_id = caller_id)
    INTO is_companion;

    IF NOT is_companion THEN
        RAISE EXCEPTION 'User % is not currently assigned as a companion.', caller_id;
    END IF;

    RETURN QUERY
        WITH AssignedStudents AS (
            -- Get students assigned to the calling companion
            SELECT csm.student_id
            FROM companion_student_map csm
            WHERE csm.companion_id = caller_id
        ),
             StudentWorkshopAttendance AS (
                 -- Get attendance records for workshops
                 SELECT
                     s.user_id as student_id,
                     s.headquarter_id,
                     a.name as student_first_name,
                     a.last_name as student_last_name,
                     COUNT(sa.id) as total_workshops,
                     COUNT(sa.id) FILTER (WHERE sa.attendance_status = 'present') as attended_workshops
                 FROM students s
                          JOIN AssignedStudents ast ON s.user_id = ast.student_id
                          JOIN agreements a ON s.user_id = a.user_id
                          LEFT JOIN student_attendance sa ON s.user_id = sa.student_id
                 GROUP BY s.user_id, s.headquarter_id, a.name, a.last_name
             )
        -- Final selection: Students with attendance issues
        SELECT
            swa.student_id,
            swa.student_first_name,
            swa.student_last_name,
            (swa.total_workshops - swa.attended_workshops) as missed_workshops_count,
            swa.total_workshops as total_workshops_count,
            CASE
                WHEN swa.total_workshops > 0 THEN
                    ROUND((swa.attended_workshops::numeric / swa.total_workshops) * 100, 2)
                ELSE 0
                END as attendance_percentage
        FROM StudentWorkshopAttendance swa
        WHERE swa.total_workshops > 0
        ORDER BY attendance_percentage ASC;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_companion_student_attendance_issues(integer) TO authenticated;

-- Function for Directors: Rank HQs by agreements created this year
CREATE OR REPLACE FUNCTION get_hq_agreement_ranking_this_year()
    RETURNS TABLE (
                      headquarter_id uuid,
                      headquarter_name text,
                      agreements_this_year_count bigint,
                      agreements_graduated_count bigint,
                      graduation_percentage numeric
                  )
    LANGUAGE plpgsql
    SECURITY DEFINER -- Needs to see all agreements to rank HQs
AS $$
DECLARE
    current_role_level integer;
BEGIN
    -- Permission Check
    current_role_level := fn_get_current_role_level();
    IF current_role_level < 80 THEN -- Let's use Director level 80
        RAISE EXCEPTION 'Insufficient privileges. Required level: 80, Your level: %', current_role_level;
    END IF;

    -- Calculate and return ranking
    RETURN QUERY
        SELECT
            h.id,
            h.name,
            COUNT(a.id) as agreements_count,
            COUNT(a.id) FILTER (WHERE a.status = 'graduated') as graduated_count,
            CASE
                WHEN COUNT(a.id) > 0 THEN
                    ROUND((COUNT(a.id) FILTER (WHERE a.status = 'graduated')::numeric / COUNT(a.id)) * 100, 2)
                ELSE 0
                END as graduation_percentage
        FROM agreements a
                 JOIN headquarters h ON a.headquarter_id = h.id
        WHERE a.created_at >= date_trunc('year', current_date)
        GROUP BY h.id, h.name
        ORDER BY agreements_count DESC;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_hq_agreement_ranking_this_year() TO authenticated;

-- Function for Managers/Directors: Get a breakdown of agreements by user role and status for a specific HQ
CREATE OR REPLACE FUNCTION get_hq_agreement_breakdown(target_hq_id uuid)
    RETURNS jsonb
    LANGUAGE plpgsql
    SECURITY DEFINER -- Needs to query across users/roles potentially outside caller's direct view
AS $$
DECLARE
    current_role_level integer;
    current_user_hq_id uuid;
    breakdown_data jsonb;
BEGIN
    -- Get the role level and HQ ID of the user calling the function
    SELECT fn_get_current_role_level(), fn_get_current_hq_id() -- Use single HQ ID function
    INTO current_role_level, current_user_hq_id;

    -- Permission Check: Allow if user is in the target HQ or role level is >= 70
    IF NOT (current_user_hq_id = target_hq_id OR current_role_level >= 70) THEN
        RAISE EXCEPTION 'Insufficient privileges. User must belong to the target headquarter (%) or have role level >= 70.', target_hq_id;
    END IF;

    -- Calculate the breakdown
    SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::jsonb)
    INTO breakdown_data
    FROM (
             SELECT
                 r.name AS role_name,
                 a.status AS agreement_status,
                 COUNT(*) AS count
             FROM agreements a
                      JOIN roles r ON a.role_id = r.id -- Join directly to roles via a.role_id
             WHERE a.headquarter_id = target_hq_id
             GROUP BY r.name, a.status
             ORDER BY r.name, a.status
         ) t;

    RETURN breakdown_data;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_hq_agreement_breakdown(uuid) TO authenticated;

-- Function for Directors: Get a global breakdown of agreements by user role and status
CREATE OR REPLACE FUNCTION get_global_agreement_breakdown()
    RETURNS jsonb
    LANGUAGE plpgsql
    SECURITY DEFINER -- Needs to query across users/roles globally
AS $$
DECLARE
    current_role_level integer;
    breakdown_data jsonb;
BEGIN
    -- Permission Check
    current_role_level := fn_get_current_role_level();
    IF current_role_level < 90 THEN -- Require Director level 90
        RAISE EXCEPTION 'Insufficient privileges. Required level: 90, Your level: %', current_role_level;
    END IF;

    -- Calculate the global breakdown
    SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::jsonb)
    INTO breakdown_data
    FROM (
             SELECT
                 r.name AS role_name,
                 a.status AS agreement_status,
                 COUNT(*) AS count
             FROM agreements a
                      JOIN roles r ON a.role_id = r.id -- Join directly to roles via a.role_id
             -- No headquarter filter for global view
             GROUP BY r.name, a.status
             ORDER BY r.name, a.status
         ) t;

    RETURN breakdown_data;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_global_agreement_breakdown() TO authenticated;

-- Function to calculate average time from prospect to active status
CREATE OR REPLACE FUNCTION get_prospect_to_active_avg_time(target_hq_id uuid DEFAULT NULL)
    RETURNS jsonb
    LANGUAGE plpgsql
    SECURITY DEFINER
AS $$
DECLARE
    current_role_level integer;
    current_user_hq_id uuid;
    is_authorized boolean := false;
    result_data jsonb;
    avg_days_global numeric;
    avg_days_by_hq jsonb;
BEGIN
    -- Get current user's role level and HQ ID
    current_role_level := fn_get_current_role_level();
    current_user_hq_id := fn_get_current_hq_id();

    -- Permission Check:
    -- If target_hq_id is NULL (global view), require Director+ (>=80)
    -- If target_hq_id is specified, allow if user is in that HQ or role level is >= 70
    IF target_hq_id IS NULL THEN
        IF current_role_level >= 80 THEN
            is_authorized := true;
        END IF;
    ELSE
        IF current_role_level >= 80 OR (current_role_level >= 50 AND target_hq_id = current_user_hq_id) THEN
            is_authorized := true;
        END IF;
    END IF;

    IF NOT is_authorized THEN
        RAISE EXCEPTION 'Insufficient privileges to access prospect-to-active conversion time statistics.';
    END IF;

    -- Calculate global average (if no specific HQ requested)
    IF target_hq_id IS NULL THEN
        SELECT
            ROUND(AVG(EXTRACT(EPOCH FROM (activation_date - created_at)) / 86400.0), 2) -- Convert to days
        INTO avg_days_global
        FROM agreements
        WHERE
            status IN ('active', 'graduated')
          AND activation_date IS NOT NULL
          AND created_at IS NOT NULL
          AND activation_date > created_at;

        -- Calculate average by headquarter
        SELECT
            jsonb_object_agg(hq_name, avg_days)
        INTO avg_days_by_hq
        FROM (
                 SELECT
                     h.name as hq_name,
                     ROUND(AVG(EXTRACT(EPOCH FROM (a.activation_date - a.created_at)) / 86400.0), 2) as avg_days
                 FROM agreements a
                          JOIN headquarters h ON a.headquarter_id = h.id
                 WHERE
                     a.status IN ('active', 'graduated')
                   AND a.activation_date IS NOT NULL
                   AND a.created_at IS NOT NULL
                   AND a.activation_date > a.created_at
                 GROUP BY h.name
                 ORDER BY avg_days
             ) t;

        -- Build result
        result_data := jsonb_build_object(
                'global_avg_days', COALESCE(avg_days_global, 0),
                'by_headquarter', COALESCE(avg_days_by_hq, '{}'::jsonb)
                       );
    ELSE
        -- Calculate for specific headquarter
        SELECT
            ROUND(AVG(EXTRACT(EPOCH FROM (activation_date - created_at)) / 86400.0), 2) -- Convert to days
        INTO avg_days_global
        FROM agreements
        WHERE
            headquarter_id = target_hq_id
          AND status IN ('active', 'graduated')
          AND activation_date IS NOT NULL
          AND created_at IS NOT NULL
          AND activation_date > created_at;

        -- Get headquarter name
        SELECT jsonb_build_object(
                       'headquarter_id', target_hq_id,
                       'headquarter_name', h.name,
                       'avg_days', COALESCE(avg_days_global, 0)
               )
        INTO result_data
        FROM headquarters h
        WHERE h.id = target_hq_id;
    END IF;

    RETURN result_data;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_prospect_to_active_avg_time(uuid) TO authenticated;

-- Function to get trend of active students per quarter for each headquarter
CREATE OR REPLACE FUNCTION get_student_trend_by_quarter(quarters_back integer DEFAULT 4)
    RETURNS jsonb
    LANGUAGE plpgsql
    SECURITY DEFINER
AS $$
DECLARE
    current_role_level integer;
    result_data jsonb;
    quarters jsonb;
BEGIN
    -- Permission Check
    current_role_level := fn_get_current_role_level();
    IF current_role_level < 80 THEN
        RAISE EXCEPTION 'Insufficient privileges. Required level: 80, Your level: %', current_role_level;
    END IF;

    -- Generate array of quarters to analyze
    WITH RECURSIVE quarters_cte AS (
        SELECT
            date_trunc('quarter', current_date) as quarter_start,
            1 as quarter_num
        UNION ALL
        SELECT
            date_trunc('quarter', quarter_start - interval '3 months') as quarter_start,
            quarter_num + 1
        FROM quarters_cte
        WHERE quarter_num < quarters_back
    )
    SELECT
        jsonb_agg(
                jsonb_build_object(
                        'quarter', to_char(quarter_start, 'YYYY-"Q"Q'),
                        'start_date', quarter_start,
                        'end_date', quarter_start + interval '3 months' - interval '1 day'
                )
                ORDER BY quarter_start DESC
        )
    INTO quarters
    FROM quarters_cte;

    -- Calculate active students per quarter per headquarter
    WITH quarter_dates AS (
        SELECT
            q->>'quarter' as quarter_label,
            (q->>'start_date')::timestamptz as start_date,
            (q->>'end_date')::timestamptz as end_date
        FROM jsonb_array_elements(quarters) as q
    ),
         headquarter_quarters AS (
             SELECT
                 h.id as hq_id,
                 h.name as hq_name,
                 qd.quarter_label,
                 qd.start_date,
                 qd.end_date,
                 COUNT(DISTINCT s.user_id) FILTER (
                     WHERE s.status = 'active'
                         AND (s.enrollment_date <= qd.end_date)
                     -- Additional filtering if needed
                     ) as active_students
             FROM headquarters h
                      CROSS JOIN quarter_dates qd
                      LEFT JOIN students s ON s.headquarter_id = h.id
             GROUP BY h.id, h.name, qd.quarter_label, qd.start_date, qd.end_date
             ORDER BY h.name, qd.start_date DESC
         ),
         headquarter_trends AS (
             SELECT
                 hq_id,
                 hq_name,
                 jsonb_agg(
                         jsonb_build_object(
                                 'quarter', quarter_label,
                                 'active_students', active_students
                         )
                         ORDER BY start_date DESC
                 ) as quarters_data
             FROM headquarter_quarters
             GROUP BY hq_id, hq_name
         )
    SELECT
        jsonb_agg(
                jsonb_build_object(
                        'headquarter_id', hq_id,
                        'headquarter_name', hq_name,
                        'quarters', quarters_data
                )
        )
    INTO result_data
    FROM headquarter_trends;

    RETURN jsonb_build_object(
            'quarters_analyzed', quarters,
            'headquarter_trends', COALESCE(result_data, '[]'::jsonb)
           );
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_student_trend_by_quarter(integer) TO authenticated;

-- Function to identify headquarters with the best student-graduation ratio
CREATE OR REPLACE FUNCTION get_hq_graduation_ranking(months_back integer DEFAULT 12)
    RETURNS jsonb
    LANGUAGE plpgsql
    SECURITY DEFINER
AS $$
DECLARE
    current_role_level integer;
    result_data jsonb;
BEGIN
    -- Permission Check
    current_role_level := fn_get_current_role_level();
    IF current_role_level < 80 THEN
        RAISE EXCEPTION 'Insufficient privileges. Required level: 80, Your level: %', current_role_level;
    END IF;

    -- Calculate graduation ratio for each headquarter
    WITH hq_stats AS (
        SELECT
            h.id as hq_id,
            h.name as hq_name,
            COUNT(DISTINCT a.id) FILTER (
                WHERE a.role_id = (SELECT id FROM roles WHERE name = 'Student')
                    AND a.created_at >= current_date - (months_back || ' months')::interval
                ) as total_students,
            COUNT(DISTINCT a.id) FILTER (
                WHERE a.role_id = (SELECT id FROM roles WHERE name = 'Student')
                    AND a.status = 'graduated'
                    AND a.created_at >= current_date - (months_back || ' months')::interval
                ) as graduated_students
        FROM headquarters h
                 LEFT JOIN agreements a ON a.headquarter_id = h.id
        GROUP BY h.id, h.name
    )
    SELECT
        jsonb_agg(
                jsonb_build_object(
                        'headquarter_id', hq_id,
                        'headquarter_name', hq_name,
                        'total_students', total_students,
                        'graduated_students', graduated_students,
                        'graduation_ratio', CASE
                                                WHEN total_students > 0 THEN
                                                    ROUND((graduated_students::numeric / total_students) * 100, 2)
                                                ELSE 0
                            END
                )
                ORDER BY
                    CASE WHEN total_students > 0 THEN
                             (graduated_students::numeric / total_students)
                         ELSE 0 END DESC
        )
    INTO result_data
    FROM hq_stats
    WHERE total_students > 0;

    RETURN jsonb_build_object(
            'months_analyzed', months_back,
            'headquarter_ranking', COALESCE(result_data, '[]'::jsonb)
           );
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_hq_graduation_ranking(integer) TO authenticated;

-- Function to calculate the proportion of facilitators holding multiple roles
CREATE OR REPLACE FUNCTION get_facilitator_multiple_roles_stats()
    RETURNS jsonb
    LANGUAGE plpgsql
    SECURITY DEFINER
AS $$
DECLARE
    current_role_level integer;
    result_data jsonb;
    global_stats jsonb;
    hq_stats jsonb;
BEGIN
    -- Permission Check
    current_role_level := fn_get_current_role_level();
    IF current_role_level < 80 THEN
        RAISE EXCEPTION 'Insufficient privileges. Required level: 80, Your level: %', current_role_level;
    END IF;

    -- Calculate global statistics
    WITH facilitator_roles AS (
        SELECT
            a.user_id,
            COUNT(DISTINCT a.headquarter_id) as hq_count,
            COUNT(DISTINCT a.role_id) as role_count
        FROM agreements a
                 JOIN roles r ON a.role_id = r.id
        WHERE r.name = 'Facilitator' AND a.status = 'active'
        GROUP BY a.user_id
    )
    SELECT
        jsonb_build_object(
                'total_facilitators', COUNT(*),
                'facilitators_multiple_hqs', COUNT(*) FILTER (WHERE hq_count > 1),
                'facilitators_multiple_roles', COUNT(*) FILTER (WHERE role_count > 1),
                'multiple_hqs_percentage', ROUND((COUNT(*) FILTER (WHERE hq_count > 1)::numeric / NULLIF(COUNT(*), 0)) * 100, 2),
                'multiple_roles_percentage', ROUND((COUNT(*) FILTER (WHERE role_count > 1)::numeric / NULLIF(COUNT(*), 0)) * 100, 2)
        )
    INTO global_stats
    FROM facilitator_roles;

    -- Calculate statistics by headquarter
    WITH facilitator_hq_roles AS (
        SELECT
            a.headquarter_id,
            a.user_id,
            COUNT(DISTINCT a.role_id) as role_count
        FROM agreements a
                 JOIN roles r ON a.role_id = r.id
        WHERE r.name = 'Facilitator' AND a.status = 'active'
        GROUP BY a.headquarter_id, a.user_id
    ),
         hq_role_stats AS (
             SELECT
                 h.id as hq_id,
                 h.name as hq_name,
                 COUNT(DISTINCT fhr.user_id) as total_facilitators,
                 COUNT(DISTINCT fhr.user_id) FILTER (WHERE fhr.role_count > 1) as facilitators_multiple_roles
             FROM headquarters h
                      LEFT JOIN facilitator_hq_roles fhr ON h.id = fhr.headquarter_id
             GROUP BY h.id, h.name
         )
    SELECT
        jsonb_agg(
                jsonb_build_object(
                        'headquarter_id', hq_id,
                        'headquarter_name', hq_name,
                        'total_facilitators', total_facilitators,
                        'facilitators_multiple_roles', facilitators_multiple_roles,
                        'multiple_roles_percentage', CASE
                                                         WHEN total_facilitators > 0 THEN
                                                             ROUND((facilitators_multiple_roles::numeric / total_facilitators) * 100, 2)
                                                         ELSE 0
                            END
                )
                ORDER BY
                    CASE WHEN total_facilitators > 0 THEN
                             (facilitators_multiple_roles::numeric / total_facilitators)
                         ELSE 0 END DESC
        )
    INTO hq_stats
    FROM hq_role_stats;

    -- Combine results
    result_data := jsonb_build_object(
            'global', COALESCE(global_stats, '{}'::jsonb),
            'by_headquarter', COALESCE(hq_stats, '[]'::jsonb)
                   );

    RETURN result_data;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_facilitator_multiple_roles_stats() TO authenticated;

-- NEW FUNCTION: Get workshop attendance statistics by headquarter
CREATE OR REPLACE FUNCTION get_workshop_attendance_stats(target_hq_id uuid DEFAULT NULL, season_id uuid DEFAULT NULL)
    RETURNS jsonb
    LANGUAGE plpgsql
    SECURITY DEFINER
AS $$
DECLARE
    current_role_level integer;
    current_user_hq_id uuid;
    is_authorized boolean := false;
    result_data jsonb;
    workshop_attendance jsonb;
    workshop_types jsonb;
BEGIN
    -- Get current user's role level and HQ ID
    current_role_level := fn_get_current_role_level();
    current_user_hq_id := fn_get_current_hq_id();

    -- Permission Check
    IF target_hq_id IS NULL THEN
        -- Global stats require level 80+
        IF current_role_level >= 80 THEN
            is_authorized := true;
        END IF;
    ELSE
        -- HQ-specific stats require level 80+ OR level 50+ and in the same HQ
        IF current_role_level >= 80 OR (current_role_level >= 50 AND target_hq_id = current_user_hq_id) THEN
            is_authorized := true;
        END IF;
    END IF;

    IF NOT is_authorized THEN
        RAISE EXCEPTION 'Insufficient privileges to access workshop attendance statistics.';
    END IF;

    -- Default to current active season if none specified
    IF season_id IS NULL THEN
        SELECT id INTO season_id
        FROM seasons
        WHERE status = 'active'
        ORDER BY start_date DESC
        LIMIT 1;
    END IF;

    -- Calculate workshop attendance statistics
    IF target_hq_id IS NULL THEN
        -- Global stats across all headquarters

        -- By workshop type
        SELECT
            jsonb_agg(
                    jsonb_build_object(
                            'workshop_type', mwt.name,
                            'total_workshops', COUNT(DISTINCT sw.id),
                            'total_attendances', COUNT(sa.id),
                            'present_count', COUNT(sa.id) FILTER (WHERE sa.attendance_status = 'present'),
                            'absent_count', COUNT(sa.id) FILTER (WHERE sa.attendance_status = 'absent'),
                            'attendance_rate', CASE
                                                   WHEN COUNT(sa.id) > 0 THEN
                                                       ROUND((COUNT(sa.id) FILTER (WHERE sa.attendance_status = 'present')::numeric / COUNT(sa.id)) * 100, 2)
                                                   ELSE 0
                                END
                    )
                    ORDER BY COUNT(DISTINCT sw.id) DESC
            )
        INTO workshop_types
        FROM scheduled_workshops sw
                 JOIN master_workshop_types mwt ON sw.master_workshop_type_id = mwt.id
                 LEFT JOIN student_attendance sa ON sw.id = sa.scheduled_workshop_id
        WHERE sw.season_id = season_id
        GROUP BY mwt.name;

        -- By headquarter
        SELECT
            jsonb_agg(
                    jsonb_build_object(
                            'headquarter_id', h.id,
                            'headquarter_name', h.name,
                            'total_workshops', COUNT(DISTINCT sw.id),
                            'total_attendances', COUNT(sa.id),
                            'present_count', COUNT(sa.id) FILTER (WHERE sa.attendance_status = 'present'),
                            'absent_count', COUNT(sa.id) FILTER (WHERE sa.attendance_status = 'absent'),
                            'attendance_rate', CASE
                                                   WHEN COUNT(sa.id) > 0 THEN
                                                       ROUND((COUNT(sa.id) FILTER (WHERE sa.attendance_status = 'present')::numeric / COUNT(sa.id)) * 100, 2)
                                                   ELSE 0
                                END
                    )
                    ORDER BY
                        CASE WHEN COUNT(sa.id) > 0 THEN
                                 (COUNT(sa.id) FILTER (WHERE sa.attendance_status = 'present')::numeric / COUNT(sa.id))
                             ELSE 0 END DESC
            )
        INTO workshop_attendance
        FROM scheduled_workshops sw
                 JOIN headquarters h ON sw.headquarter_id = h.id
                 LEFT JOIN student_attendance sa ON sw.id = sa.scheduled_workshop_id
        WHERE sw.season_id = season_id
        GROUP BY h.id, h.name;

        -- Build result
        result_data := jsonb_build_object(
                'season_id', season_id,
                'by_workshop_type', COALESCE(workshop_types, '[]'::jsonb),
                'by_headquarter', COALESCE(workshop_attendance, '[]'::jsonb)
                       );
    ELSE
        -- HQ-specific stats

        -- By workshop type for specific HQ
        SELECT
            jsonb_agg(
                    jsonb_build_object(
                            'workshop_type', mwt.name,
                            'total_workshops', COUNT(DISTINCT sw.id),
                            'total_attendances', COUNT(sa.id),
                            'present_count', COUNT(sa.id) FILTER (WHERE sa.attendance_status = 'present'),
                            'absent_count', COUNT(sa.id) FILTER (WHERE sa.attendance_status = 'absent'),
                            'attendance_rate', CASE
                                                   WHEN COUNT(sa.id) > 0 THEN
                                                       ROUND((COUNT(sa.id) FILTER (WHERE sa.attendance_status = 'present')::numeric / COUNT(sa.id)) * 100, 2)
                                                   ELSE 0
                                END
                    )
                    ORDER BY COUNT(DISTINCT sw.id) DESC
            )
        INTO workshop_types
        FROM scheduled_workshops sw
                 JOIN master_workshop_types mwt ON sw.master_workshop_type_id = mwt.id
                 LEFT JOIN student_attendance sa ON sw.id = sa.scheduled_workshop_id
        WHERE sw.season_id = season_id AND sw.headquarter_id = target_hq_id
        GROUP BY mwt.name;

        -- Get headquarter name
        SELECT
            jsonb_build_object(
                    'headquarter_id', h.id,
                    'headquarter_name', h.name,
                    'season_id', season_id,
                    'total_workshops', COUNT(DISTINCT sw.id),
                    'total_attendances', COUNT(sa.id),
                    'present_count', COUNT(sa.id) FILTER (WHERE sa.attendance_status = 'present'),
                    'absent_count', COUNT(sa.id) FILTER (WHERE sa.attendance_status = 'absent'),
                    'attendance_rate', CASE
                                           WHEN COUNT(sa.id) > 0 THEN
                                               ROUND((COUNT(sa.id) FILTER (WHERE sa.attendance_status = 'present')::numeric / COUNT(sa.id)) * 100, 2)
                                           ELSE 0
                        END,
                    'by_workshop_type', COALESCE(workshop_types, '[]'::jsonb)
            )
        INTO result_data
        FROM headquarters h
                 LEFT JOIN scheduled_workshops sw ON h.id = sw.headquarter_id AND sw.season_id = season_id
                 LEFT JOIN student_attendance sa ON sw.id = sa.scheduled_workshop_id
        WHERE h.id = target_hq_id
        GROUP BY h.id, h.name;
    END IF;

    RETURN result_data;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_workshop_attendance_stats(uuid, uuid) TO authenticated;

-- NEW FUNCTION: Get student progress statistics
CREATE OR REPLACE FUNCTION get_student_progress_stats(target_hq_id uuid DEFAULT NULL)
    RETURNS jsonb
    LANGUAGE plpgsql
    SECURITY DEFINER
AS $$
DECLARE
    current_role_level integer;
    current_user_hq_id uuid;
    is_authorized boolean := false;
    result_data jsonb;
BEGIN
    -- Get current user's role level and HQ ID
    current_role_level := fn_get_current_role_level();
    current_user_hq_id := fn_get_current_hq_id();

    -- Permission Check
    IF target_hq_id IS NULL THEN
        -- Global stats require level 80+
        IF current_role_level >= 80 THEN
            is_authorized := true;
        END IF;
    ELSE
        -- HQ-specific stats require level 80+ OR level 50+ and in the same HQ
        IF current_role_level >= 80 OR (current_role_level >= 50 AND target_hq_id = current_user_hq_id) THEN
            is_authorized := true;
        END IF;
    END IF;

    IF NOT is_authorized THEN
        RAISE EXCEPTION 'Insufficient privileges to access student progress statistics.';
    END IF;

    -- Calculate student progress statistics
    IF target_hq_id IS NULL THEN
        -- Global student progress stats
        WITH student_status_counts AS (
            SELECT
                h.id as hq_id,
                h.name as hq_name,
                COUNT(s.id) FILTER (WHERE s.status = 'active') as active_count,
                COUNT(s.id) FILTER (WHERE s.status = 'prospect') as prospect_count,
                COUNT(s.id) FILTER (WHERE s.status = 'graduated') as graduated_count,
                COUNT(s.id) FILTER (WHERE s.status = 'inactive') as inactive_count,
                COUNT(s.id) as total_count
            FROM headquarters h
                     LEFT JOIN students s ON h.id = s.headquarter_id
            GROUP BY h.id, h.name
        ),
             attendance_stats AS (
                 SELECT
                     s.headquarter_id,
                     AVG(CASE WHEN sa.attendance_status = 'present' THEN 100.0 ELSE 0.0 END) as avg_attendance_rate
                 FROM student_attendance sa
                          JOIN students s ON sa.student_id = s.user_id
                 GROUP BY s.headquarter_id
             )
        SELECT
            jsonb_agg(
                    jsonb_build_object(
                            'headquarter_id', ssc.hq_id,
                            'headquarter_name', ssc.hq_name,
                            'active_count', ssc.active_count,
                            'prospect_count', ssc.prospect_count,
                            'graduated_count', ssc.graduated_count,
                            'inactive_count', ssc.inactive_count,
                            'total_count', ssc.total_count,
                            'active_percentage', CASE
                                                     WHEN ssc.total_count > 0 THEN
                                                         ROUND((ssc.active_count::numeric / ssc.total_count) * 100, 2)
                                                     ELSE 0
                                END,
                            'graduated_percentage', CASE
                                                        WHEN ssc.total_count > 0 THEN
                                                            ROUND((ssc.graduated_count::numeric / ssc.total_count) * 100, 2)
                                                        ELSE 0
                                END,
                            'avg_attendance_rate', ROUND(COALESCE(ast.avg_attendance_rate, 0), 2)
                    )
                    ORDER BY ssc.total_count DESC
            )
        INTO result_data
        FROM student_status_counts ssc
                 LEFT JOIN attendance_stats ast ON ssc.hq_id = ast.headquarter_id;
    ELSE
        -- HQ-specific student progress stats
        WITH student_data AS (
            SELECT
                        COUNT(s.id) FILTER (WHERE s.status = 'active') as active_count,
                        COUNT(s.id) FILTER (WHERE s.status = 'prospect') as prospect_count,
                        COUNT(s.id) FILTER (WHERE s.status = 'graduated') as graduated_count,
                        COUNT(s.id) FILTER (WHERE s.status = 'inactive') as inactive_count,
                        COUNT(s.id) as total_count,
                        AVG(CASE WHEN sa.attendance_status = 'present' THEN 100.0 ELSE 0.0 END) as avg_attendance_rate
            FROM headquarters h
                     LEFT JOIN students s ON h.id = s.headquarter_id
                     LEFT JOIN student_attendance sa ON s.user_id = sa.student_id
            WHERE h.id = target_hq_id
            GROUP BY h.id
        )
        SELECT
            jsonb_build_object(
                    'headquarter_id', target_hq_id,
                    'headquarter_name', h.name,
                    'active_count', COALESCE(sd.active_count, 0),
                    'prospect_count', COALESCE(sd.prospect_count, 0),
                    'graduated_count', COALESCE(sd.graduated_count, 0),
                    'inactive_count', COALESCE(sd.inactive_count, 0),
                    'total_count', COALESCE(sd.total_count, 0),
                    'active_percentage', CASE
                                             WHEN COALESCE(sd.total_count, 0) > 0 THEN
                                                 ROUND((sd.active_count::numeric / sd.total_count) * 100, 2)
                                             ELSE 0
                        END,
                    'graduated_percentage', CASE
                                                WHEN COALESCE(sd.total_count, 0) > 0 THEN
                                                    ROUND((sd.graduated_count::numeric / sd.total_count) * 100, 2)
                                                ELSE 0
                        END,
                    'avg_attendance_rate', ROUND(COALESCE(sd.avg_attendance_rate, 0), 2)
            )
        INTO result_data
        FROM headquarters h
                 LEFT JOIN student_data sd ON TRUE
        WHERE h.id = target_hq_id;
    END IF;

    RETURN result_data;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_student_progress_stats(uuid) TO authenticated;

-- NEW FUNCTION: Get companion effectiveness metrics
CREATE OR REPLACE FUNCTION get_companion_effectiveness_metrics(target_hq_id uuid DEFAULT NULL)
    RETURNS jsonb
    LANGUAGE plpgsql
    SECURITY DEFINER
AS $$
DECLARE
    current_role_level integer;
    current_user_hq_id uuid;
    is_authorized boolean := false;
    result_data jsonb;
BEGIN
    -- Get current user's role level and HQ ID
    current_role_level := fn_get_current_role_level();
    current_user_hq_id := fn_get_current_hq_id();

    -- Permission Check
    IF target_hq_id IS NULL THEN
        -- Global stats require level 80+
        IF current_role_level >= 80 THEN
            is_authorized := true;
        END IF;
    ELSE
        -- HQ-specific stats require level 80+ OR level 50+ and in the same HQ
        IF current_role_level >= 80 OR (current_role_level >= 50 AND target_hq_id = current_user_hq_id) THEN
            is_authorized := true;
        END IF;
    END IF;

    IF NOT is_authorized THEN
        RAISE EXCEPTION 'Insufficient privileges to access companion effectiveness metrics.';
    END IF;

    -- Calculate companion effectiveness metrics
    IF target_hq_id IS NULL THEN
        -- Global companion metrics
        WITH companion_metrics AS (
            SELECT
                csm.headquarter_id,
                csm.companion_id,
                COUNT(DISTINCT csm.student_id) as assigned_students,
                AVG(CASE WHEN sa.attendance_status = 'present' THEN 100.0 ELSE 0.0 END) as student_attendance_rate
            FROM companion_student_map csm
                     LEFT JOIN student_attendance sa ON csm.student_id = sa.student_id
            GROUP BY csm.headquarter_id, csm.companion_id
        ),
             hq_metrics AS (
                 SELECT
                     h.id as hq_id,
                     h.name as hq_name,
                     COUNT(DISTINCT cm.companion_id) as active_companions,
                     AVG(cm.assigned_students) as avg_students_per_companion,
                     AVG(cm.student_attendance_rate) as avg_student_attendance_rate
                 FROM headquarters h
                          LEFT JOIN companion_metrics cm ON h.id = cm.headquarter_id
                 GROUP BY h.id, h.name
             )
        SELECT
            jsonb_agg(
                    jsonb_build_object(
                            'headquarter_id', hm.hq_id,
                            'headquarter_name', hm.hq_name,
                            'active_companions', COALESCE(hm.active_companions, 0),
                            'avg_students_per_companion', ROUND(COALESCE(hm.avg_students_per_companion, 0), 2),
                            'avg_student_attendance_rate', ROUND(COALESCE(hm.avg_student_attendance_rate, 0), 2)
                    )
                    ORDER BY COALESCE(hm.avg_student_attendance_rate, 0) DESC
            )
        INTO result_data
        FROM hq_metrics hm;
    ELSE
        -- HQ-specific companion metrics
        WITH companion_metrics AS (
            SELECT
                csm.companion_id,
                a.name || ' ' || a.last_name as companion_name,
                COUNT(DISTINCT csm.student_id) as assigned_students,
                AVG(CASE WHEN sa.attendance_status = 'present' THEN 100.0 ELSE 0.0 END) as student_attendance_rate
            FROM companion_student_map csm
                     JOIN agreements a ON csm.companion_id = a.user_id
                     LEFT JOIN student_attendance sa ON csm.student_id = sa.student_id
            WHERE csm.headquarter_id = target_hq_id
            GROUP BY csm.companion_id, companion_name
        ),
             hq_summary AS (
                 SELECT
                     COUNT(DISTINCT cm.companion_id) as active_companions,
                     AVG(cm.assigned_students) as avg_students_per_companion,
                     AVG(cm.student_attendance_rate) as avg_student_attendance_rate
                 FROM companion_metrics cm
             )
        SELECT
            jsonb_build_object(
                    'headquarter_id', target_hq_id,
                    'headquarter_name', h.name,
                    'active_companions', COALESCE(hs.active_companions, 0),
                    'avg_students_per_companion', ROUND(COALESCE(hs.avg_students_per_companion, 0), 2),
                    'avg_student_attendance_rate', ROUND(COALESCE(hs.avg_student_attendance_rate, 0), 2),
                    'companion_details', COALESCE(
                            (SELECT
                                 jsonb_agg(
                                         jsonb_build_object(
                                                 'companion_id', cm.companion_id,
                                                 'companion_name', cm.companion_name,
                                                 'assigned_students', cm.assigned_students,
                                                 'student_attendance_rate', ROUND(COALESCE(cm.student_attendance_rate, 0), 2)
                                         )
                                         ORDER BY cm.student_attendance_rate DESC
                                 )
                             FROM companion_metrics cm),
                            '[]'::jsonb
                                         )
            )
        INTO result_data
        FROM headquarters h
                 LEFT JOIN hq_summary hs ON TRUE
        WHERE h.id = target_hq_id;
    END IF;

    RETURN result_data;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_companion_effectiveness_metrics(uuid) TO authenticated;
