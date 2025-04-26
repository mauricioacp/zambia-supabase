-- Functions for dashboard statistics

-- Function to get global dashboard statistics (accessible only by roles >= 40)
CREATE OR REPLACE FUNCTION get_global_dashboard_stats()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    current_role_level integer;
    total_headquarters bigint;
    total_collaborators bigint;
    total_students bigint;
    total_active_seasons bigint;
    total_agreements bigint;
    total_active_agreements bigint;
    total_prospect_agreements bigint;
    total_inactive_agreements bigint;
    stats jsonb;
    total_workshops bigint;
    total_events bigint;
    agreements_prospect bigint;
    agreements_active bigint;
    agreements_inactive bigint;
    agreements_this_year bigint;
BEGIN
    current_role_level := fn_get_current_role_level();
    IF current_role_level < 40 THEN
        RAISE EXCEPTION 'Insufficient privileges to access global dashboard statistics. Required level: 90, Your level: %', current_role_level;
    END IF;

    SELECT COUNT(*) INTO total_headquarters FROM headquarters WHERE status = 'active';
    SELECT COUNT(*) INTO total_collaborators FROM collaborators WHERE status = 'active';
    SELECT COUNT(*) INTO total_students FROM students WHERE status = 'active';
    SELECT COUNT(*) INTO total_active_seasons FROM seasons WHERE status = 'active';
    SELECT COUNT(*) INTO total_agreements FROM agreements;
    SELECT COUNT(*) INTO total_active_agreements FROM agreements where status = 'active';
    SELECT COUNT(*) INTO total_prospect_agreements FROM agreements where status = 'prospect';
    SELECT COUNT(*) INTO total_inactive_agreements FROM agreements where status = 'inactive';







    -- Count workshops and events associated with active seasons
    SELECT COUNT(w.*) INTO total_workshops
    FROM workshops w
    JOIN seasons s ON w.season_id = s.id
    WHERE s.status = 'active';

    SELECT COUNT(e.*) INTO total_events
    FROM events e
    JOIN seasons s ON e.season_id = s.id
    WHERE s.status = 'active'; -- Only count events in currently active seasons

    -- Count agreements
    SELECT
        COUNT(*) AS total,
        COUNT(*) FILTER (WHERE status = 'prospect') AS prospect,
        COUNT(*) FILTER (WHERE status = 'active') AS active,
        COUNT(*) FILTER (WHERE status = 'inactive') AS inactive, -- Assuming 'inactive' status exists
        COUNT(*) FILTER (WHERE created_at >= date_trunc('year', current_date)) AS this_year
    INTO
        total_agreements,
        agreements_prospect,
        agreements_active,
        agreements_inactive,
        agreements_this_year
    FROM agreements;

    -- Construct the JSON response
    stats := jsonb_build_object(
        'total_headquarters', total_headquarters,
        'total_collaborators', total_collaborators,
        'total_students', total_students,
        'total_agreements_all_time', total_agreements,
        'total_agreements_prospect', agreements_prospect,
        'total_agreements_active', agreements_active,
        'total_agreements_inactive', agreements_inactive,
        'total_agreements_this_year', agreements_this_year,
        'percentage_agreements_active', CASE WHEN total_agreements > 0 THEN ROUND((agreements_active::numeric / total_agreements) * 100, 2) ELSE 0 END,
        'percentage_agreements_prospect', CASE WHEN total_agreements > 0 THEN ROUND((agreements_prospect::numeric / total_agreements) * 100, 2) ELSE 0 END,
        'total_active_seasons', total_active_seasons, -- Note: Seasons might need better definition of 'active' globally
        'total_workshops_active_seasons', total_workshops,
        'total_events_active_seasons', total_events
    );

    RETURN stats;
END;
$$;

-- Grant execute permission to authenticated users
-- The permission check is done inside the function
GRANT EXECUTE ON FUNCTION get_global_dashboard_stats() TO authenticated;

-- Function to get dashboard statistics for a specific headquarter
-- Accessible by users belonging to that HQ or roles >= 70
CREATE OR REPLACE FUNCTION get_headquarter_dashboard_stats(target_hq_id uuid)
RETURNS jsonb -- Changed return type to jsonb for flexibility
LANGUAGE plpgsql
SECURITY DEFINER -- Allows bypassing RLS for counting, but we check permission first
AS $$
DECLARE
    current_role_level integer;
    current_user_hq_id uuid; -- Changed from uuid[]
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
    hq_agreements_this_year bigint;
    hq_agreements_last_3_months bigint;
    -- Distributions
    student_age_distribution jsonb;
    collaborator_age_distribution jsonb;
    student_gender_distribution jsonb;
    collaborator_gender_distribution jsonb;
    hq_name text;
BEGIN
    -- Get current user's role level and HQ ID
    current_role_level := fn_get_current_role_level();
    current_user_hq_id := fn_get_current_hq_id(); -- Use single HQ ID function

    -- Permission Check:
    -- Allow if user is Director+ (>=80) OR (Manager+ (>=50) AND target_hq_id is one of their HQs)
    IF current_role_level >= 80 THEN
        is_authorized := true;
    ELSIF current_role_level >= 50 AND target_hq_id = current_user_hq_id THEN -- Check against single HQ ID
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

    -- Student Counts and Distributions
    SELECT
        COUNT(*) INTO hq_active_students_count
    FROM agreements WHERE headquarter_id = target_hq_id AND status = 'active';

    SELECT jsonb_object_agg(gender, count) INTO gender_distribution
    FROM (SELECT COALESCE(gender, 'unknown') as gender, COUNT(*) as count FROM agreements WHERE headquarter_id = target_hq_id AND status = 'active' GROUP BY gender) genders;

    -- Collaborator Counts and Distributions
    SELECT
        COUNT(*) INTO hq_active_collaborators_count
    FROM collaborators WHERE headquarter_id = target_hq_id AND status = 'active';

    SELECT jsonb_object_agg(age_group, count) INTO collaborator_age_distribution
    FROM (
        SELECT CASE
                   WHEN age < 18 THEN '<18'
                   WHEN age BETWEEN 18 AND 24 THEN '18-24'
                   WHEN age BETWEEN 25 AND 34 THEN '25-34'
                   WHEN age BETWEEN 35 AND 44 THEN '35-44'
                   WHEN age BETWEEN 45 AND 54 THEN '45-54'
                   WHEN age >= 55 THEN '55+'
                   ELSE 'Unknown'
               END as age_group, COUNT(*) as count
        FROM (SELECT date_part('year', age(birth_date)) as age FROM agreements WHERE headquarter_id = target_hq_id AND status = 'active' AND birth_date IS NOT NULL) ages
        GROUP BY age_group
    ) grouped_ages;

    SELECT jsonb_object_agg(gender, count) INTO collaborator_gender_distribution
    FROM (SELECT COALESCE(gender, 'Unknown') as gender, COUNT(*) as count FROM collaborators WHERE headquarter_id = target_hq_id AND status = 'active' GROUP BY gender) genders;

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
        COUNT(*) FILTER (WHERE status = 'inactive') AS inactive, -- Assuming 'inactive' status exists
        COUNT(*) FILTER (WHERE created_at >= date_trunc('year', current_date)) AS this_year,
        COUNT(*) FILTER (WHERE created_at >= current_date - interval '3 months') AS last_3_months
    INTO
        hq_agreements_total,
        hq_agreements_prospect,
        hq_agreements_active,
        hq_agreements_inactive,
        hq_agreements_this_year,
        hq_agreements_last_3_months
    FROM agreements
    WHERE headquarter_id = target_hq_id;

    -- Removed calculation for average time from prospect to active due to missing activation_date
    /* SELECT AVG(EXTRACT(EPOCH FROM (activation_date - prospect_date)) / 86400.0) -- 86400 seconds in a day
    INTO avg_days_prospect_to_active
    FROM agreements
    WHERE headquarter_id = target_hq_id
      AND prospect_date IS NOT NULL
      AND activation_date IS NOT NULL
      AND activation_date > prospect_date
      AND status IN ('active', 'inactive'); */

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
        'agreements_this_year', hq_agreements_this_year,
        'agreements_last_3_months', hq_agreements_last_3_months,
        'agreements_active_percentage', CASE WHEN hq_agreements_total > 0 THEN ROUND((hq_agreements_active::numeric / hq_agreements_total) * 100, 2) ELSE 0 END,
        'agreements_prospect_percentage', CASE WHEN hq_agreements_total > 0 THEN ROUND((hq_agreements_prospect::numeric / hq_agreements_total) * 100, 2) ELSE 0 END
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

    IF target_role.name = 'Student' THEN
        target_user_type := 'Student';
        SELECT *, (first_name || ' ' || last_name) as full_name INTO target_person
        FROM students WHERE user_id = target_user_id;
    ELSE
        target_user_type := 'Collaborator';
        SELECT *, (first_name || ' ' || last_name) as full_name INTO target_person
        FROM collaborators WHERE user_id = target_user_id;
    END IF;

    IF target_person IS NULL THEN
       target_full_name := 'Record Not Found for Role';
    ELSE
       target_full_name := target_person.full_name;
    END IF;

    -- Calculate Role-Specific Stats
    IF target_user_type = 'Student' AND target_person IS NOT NULL THEN
        -- Attendance Rate (for active season) - combining both mentoring events and workshops
        WITH EventAttendance AS (
            -- Mentoring events attendance
            SELECT 
                COUNT(*) as total_events,
                SUM(CASE WHEN attended THEN 1 ELSE 0 END) as attended_events
            FROM student_event_attendance sea
            JOIN events e ON sea.event_id = e.id
            WHERE sea.student_id = target_user_id 
              AND e.season_id = target_season.id
              AND e.event_type = 'mentoring'
        ),
        WorkshopAttendance AS (
            -- Workshop attendance
            SELECT 
                COUNT(*) as total_workshops,
                SUM(CASE WHEN attended THEN 1 ELSE 0 END) as attended_workshops
            FROM student_workshop_attendance swa
            JOIN workshops w ON swa.workshop_id = w.id
            WHERE swa.student_id = target_user_id 
              AND w.season_id = target_season.id
        )
        SELECT 
            COALESCE(
                ROUND(
                    ((COALESCE(ea.attended_events, 0) + COALESCE(wa.attended_workshops, 0))::numeric / 
                     NULLIF((COALESCE(ea.total_events, 0) + COALESCE(wa.total_workshops, 0)), 0)) * 100, 
                    2
                ), 
                0
            )
        INTO student_attendance_rate
        FROM EventAttendance ea
        CROSS JOIN WorkshopAttendance wa;

        -- Schedule (upcoming mentoring events and workshops in active season/HQ)
        WITH MentoringEvents AS (
            SELECT 
                e.id as item_id,
                e.title as item_name,
                e.start_datetime as item_date,
                'mentoring' as item_type
            FROM events e
            WHERE e.headquarter_id = target_hq.id
              AND e.season_id = target_season.id
              AND e.start_datetime >= current_date
              AND e.event_type = 'mentoring'
        ),
        Workshops AS (
            SELECT 
                w.id as item_id,
                w.name as item_name,
                w.start_datetime as item_date,
                'workshop' as item_type
            FROM workshops w
            WHERE w.headquarter_id = target_hq.id
              AND w.season_id = target_season.id
              AND w.start_datetime >= current_date
        ),
        CombinedSchedule AS (
            SELECT * FROM MentoringEvents
            UNION ALL
            SELECT * FROM Workshops
        )
        SELECT COALESCE(jsonb_agg(jsonb_build_object(
            'item_id', cs.item_id,
            'item_name', cs.item_name,
            'item_date', cs.item_date,
            'item_type', cs.item_type
        ) ORDER BY cs.item_date ASC), '[]'::jsonb)
        INTO student_schedule
        FROM CombinedSchedule cs;

        -- Companion Info
        SELECT jsonb_build_object(
            'companion_id', csm.companion_id,
            'first_name', c.first_name,
            'last_name', c.last_name,
            'email', au.email
            )
        INTO student_companion_info
        FROM companion_student_map csm
        JOIN collaborators c ON csm.companion_id = c.user_id
        JOIN auth.users au ON c.user_id = au.id
        WHERE csm.student_id = target_user_id
        LIMIT 1; -- Assuming one companion per student for simplicity

    ELSIF target_user_type = 'Collaborator' AND target_person IS NOT NULL THEN
        -- Base details for any collaborator
        collaborator_details := jsonb_build_object(
            'collaborator_id', target_user_id,
            'first_name', target_person.first_name,
            'last_name', target_person.last_name,
            'status', target_person.status,
            'role', target_role.name,
            'headquarter_id', target_person.headquarter_id,
            'headquarter_name', target_hq.name
            -- Add more common collaborator fields if needed
        );

        -- Add role-specific details for collaborators
        IF target_role.name = 'Companion' THEN
            -- Logic specific to Companions
            collaborator_details := collaborator_details || jsonb_build_object(
                'assigned_students', (
                    SELECT COALESCE(jsonb_agg(jsonb_build_object(
                               'student_id', s.id, -- Join students on students.id
                               'first_name', s.first_name,
                               'last_name', s.last_name,
                               'status', s.status
                           )), '[]'::jsonb)
                    FROM companion_student_map csm
                    JOIN students s ON csm.student_id = s.id
                    WHERE csm.companion_id = target_user_id
                )
            );

        ELSIF target_role.name = 'Facilitator' THEN
            -- Logic specific to Facilitators
            collaborator_details := collaborator_details || jsonb_build_object(
                'upcoming_assigned_workshops', (
                    SELECT COALESCE(jsonb_agg(jsonb_build_object(
                        'workshop_id', w.id,
                        'workshop_name', w.name,
                        'start_date', w.start_date, -- Assuming workshops have dates
                        'headquarter_name', h.name
                    )), '[]'::jsonb)
                    FROM facilitator_workshop_map fwm
                    JOIN workshops w ON fwm.workshop_id = w.id
                    JOIN headquarters h ON w.headquarter_id = h.id
                    WHERE fwm.facilitator_id = target_user_id
                      AND w.start_date >= current_date -- Or some relevant 'upcoming' logic
                    ORDER BY w.start_date ASC
                    LIMIT 5 -- Limit to a reasonable number
                )
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

    END IF;

    RETURN stats;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_user_dashboard_stats(uuid) TO authenticated;

-- Function for Companions: Get assigned students who missed the last N relevant events or workshops
CREATE OR REPLACE FUNCTION get_companion_student_attendance_issues(last_n_items integer DEFAULT 5)
RETURNS TABLE (
    student_id uuid,
    student_first_name text,
    student_last_name text,
    missed_mentoring_count bigint,
    missed_workshop_count bigint,
    total_missed_count bigint
)
LANGUAGE plpgsql
SECURITY INVOKER -- Run as the caller, RLS on underlying tables will apply implicitly
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
    -- MENTORING EVENTS SECTION
    RecentMentoringEvents AS (
        -- Get the N most recent MENTORING events for the HQs/Active Seasons of the companion's students
        SELECT 
            e.id as event_id, 
            e.start_datetime as event_date, 
            s.id as student_id,
            'mentoring' as item_type
        FROM events e
        JOIN students s ON e.headquarter_id = s.headquarter_id -- Match event HQ to student HQ
        JOIN agreements a ON s.id = a.student_id AND e.season_id = a.season_id -- Match event season to student's agreement season
        JOIN seasons sn ON e.season_id = sn.id AND sn.status = 'active' -- Consider only active seasons
        WHERE s.id IN (SELECT student_id FROM AssignedStudents)
          AND e.start_datetime <= current_date -- Consider past or current events only
          AND e.event_type = 'mentoring' -- Filter for mentoring events
        ORDER BY s.id, e.start_datetime DESC
    ),
    RankedRecentMentoringEvents AS (
        -- Rank mentoring events per student
        SELECT *, ROW_NUMBER() OVER(PARTITION BY student_id ORDER BY event_date DESC) as rn
        FROM RecentMentoringEvents
    ),
    LastNMentoringEventsPerStudent AS (
        -- Filter to the last N mentoring events per student
        SELECT event_id, student_id FROM RankedRecentMentoringEvents WHERE rn <= last_n_items
    ),
    MentoringAttendanceLastN AS (
        -- Check attendance for those specific mentoring events
        SELECT
            lneps.student_id,
            lneps.event_id,
            COALESCE(sea.attended, false) as attended -- Assume not attended if no record exists
        FROM LastNMentoringEventsPerStudent lneps
        LEFT JOIN student_event_attendance sea
            ON sea.student_id = lneps.student_id AND sea.event_id = lneps.event_id
    ),
    MentoringMissedCounts AS (
        -- Count how many of the last N mentoring events were missed by each student
        SELECT
            student_id,
            COUNT(*) FILTER (WHERE NOT attended) as missed_count,
            COUNT(*) as total_considered
        FROM MentoringAttendanceLastN
        GROUP BY student_id
    ),

    -- WORKSHOPS SECTION
    RecentWorkshops AS (
        -- Get the N most recent workshops for the HQs/Active Seasons of the companion's students
        SELECT 
            w.id as workshop_id, 
            w.start_datetime as workshop_date, 
            s.id as student_id,
            'workshop' as item_type
        FROM workshops w
        JOIN students s ON w.headquarter_id = s.headquarter_id -- Match workshop HQ to student HQ
        JOIN agreements a ON s.id = a.student_id AND w.season_id = a.season_id -- Match workshop season to student's agreement season
        JOIN seasons sn ON w.season_id = sn.id AND sn.status = 'active' -- Consider only active seasons
        WHERE s.id IN (SELECT student_id FROM AssignedStudents)
          AND w.start_datetime <= current_date -- Consider past or current workshops only
        ORDER BY s.id, w.start_datetime DESC
    ),
    RankedRecentWorkshops AS (
        -- Rank workshops per student
        SELECT *, ROW_NUMBER() OVER(PARTITION BY student_id ORDER BY workshop_date DESC) as rn
        FROM RecentWorkshops
    ),
    LastNWorkshopsPerStudent AS (
        -- Filter to the last N workshops per student
        SELECT workshop_id, student_id FROM RankedRecentWorkshops WHERE rn <= last_n_items
    ),
    WorkshopAttendanceLastN AS (
        -- Check attendance for those specific workshops
        SELECT
            lnwps.student_id,
            lnwps.workshop_id,
            COALESCE(swa.attended, false) as attended -- Assume not attended if no record exists
        FROM LastNWorkshopsPerStudent lnwps
        LEFT JOIN student_workshop_attendance swa
            ON swa.student_id = lnwps.student_id AND swa.workshop_id = lnwps.workshop_id
    ),
    WorkshopMissedCounts AS (
        -- Count how many of the last N workshops were missed by each student
        SELECT
            student_id,
            COUNT(*) FILTER (WHERE NOT attended) as missed_count,
            COUNT(*) as total_considered
        FROM WorkshopAttendanceLastN
        GROUP BY student_id
    ),

    -- COMBINED RESULTS
    CombinedMissedCounts AS (
        -- Combine mentoring and workshop missed counts
        SELECT
            COALESCE(mmc.student_id, wmc.student_id) as student_id,
            COALESCE(mmc.missed_count, 0) as missed_mentoring_count,
            COALESCE(mmc.total_considered, 0) as total_mentoring_considered,
            COALESCE(wmc.missed_count, 0) as missed_workshop_count,
            COALESCE(wmc.total_considered, 0) as total_workshop_considered,
            (COALESCE(mmc.missed_count, 0) + COALESCE(wmc.missed_count, 0)) as total_missed_count,
            (COALESCE(mmc.total_considered, 0) + COALESCE(wmc.total_considered, 0)) as total_items_considered
        FROM MentoringMissedCounts mmc
        FULL OUTER JOIN WorkshopMissedCounts wmc ON mmc.student_id = wmc.student_id
    )
    -- Final selection: Students who missed a significant number of events/workshops
    SELECT
        cmc.student_id,
        s.first_name,
        s.last_name,
        cmc.missed_mentoring_count,
        cmc.missed_workshop_count,
        cmc.total_missed_count
    FROM CombinedMissedCounts cmc
    JOIN students s ON cmc.student_id = s.id
    WHERE cmc.total_missed_count >= last_n_items -- Missed at least N items total
      AND cmc.total_items_considered >= last_n_items; -- Ensure we considered enough items

END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_companion_student_attendance_issues(integer) TO authenticated;

-- Function for Directors: Rank HQs by agreements created this year
CREATE OR REPLACE FUNCTION get_hq_agreement_ranking_this_year()
RETURNS TABLE (
    headquarter_id uuid,
    headquarter_name text,
    agreements_this_year_count bigint
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
        COUNT(a.id) as agreements_count
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
    status = 'active'
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
             a.status = 'active'
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
  AND status = 'active'
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
    COUNT(DISTINCT a.user_id) FILTER (
    WHERE a.status = 'active'
    AND (a.activation_date <= qd.end_date OR a.created_at <= qd.end_date)
    AND (a.updated_at >= qd.start_date OR a.updated_at IS NULL)
    ) as active_students
FROM headquarters h
    CROSS JOIN quarter_dates qd
    LEFT JOIN agreements a ON a.headquarter_id = h.id AND a.role_id = (SELECT id FROM roles WHERE name = 'Student')
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