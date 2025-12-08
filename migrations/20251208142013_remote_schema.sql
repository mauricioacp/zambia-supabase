drop extension if exists "pg_net";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.assign_workflow_action(p_stage_instance_id uuid, p_action_type text, p_assigned_to uuid, p_due_date timestamp with time zone DEFAULT NULL::timestamp with time zone, p_priority text DEFAULT 'medium'::text, p_data jsonb DEFAULT '{}'::jsonb)
 RETURNS uuid
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE
	v_action_id UUID;
	v_workflow_id UUID;
BEGIN
	-- Validate stage instance exists and is active
	IF NOT EXISTS (
		SELECT 1 FROM public.workflow_stage_instances 
		WHERE id = p_stage_instance_id 
		AND status = 'active'
	) THEN
		RAISE EXCEPTION 'Invalid or inactive stage instance';
	END IF;
	
	-- Get workflow ID for notification
	SELECT workflow_instance_id INTO v_workflow_id
	FROM public.workflow_stage_instances
	WHERE id = p_stage_instance_id;
	
	-- Create action
	INSERT INTO public.workflow_actions (
		stage_instance_id,
		action_type,
		assigned_to,
		assigned_by,
		due_date,
		priority,
		data,
		status
	) VALUES (
		p_stage_instance_id,
		p_action_type,
		p_assigned_to,
		auth.uid(),
		p_due_date,
		p_priority,
		p_data,
		'pending'
	) RETURNING id INTO v_action_id;
	
	-- Create assignment notification
	INSERT INTO public.workflow_notifications (
		workflow_instance_id,
		action_id,
		recipient_id,
		notification_type,
		channel,
		data
	) VALUES (
		v_workflow_id,
		v_action_id,
		p_assigned_to,
		'assignment',
		'in_app',
		jsonb_build_object(
			'action_type', p_action_type,
			'due_date', p_due_date,
			'priority', p_priority
		)
	);
	
	RETURN v_action_id;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.audit_workflow_action_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
	v_user_id UUID;
	v_action TEXT;
	v_previous_value JSONB;
	v_new_value JSONB;
BEGIN
	-- Get the current user ID
	v_user_id := auth.uid();
	
	-- Determine the action type
	IF TG_OP = 'INSERT' THEN
		v_action := 'created';
		v_previous_value := NULL;
		v_new_value := to_jsonb(NEW);
	ELSIF TG_OP = 'UPDATE' THEN
		-- Determine specific action based on what changed
		IF OLD.status IS DISTINCT FROM NEW.status THEN
			v_action := 'status_changed_to_' || NEW.status;
		ELSIF OLD.assigned_to IS DISTINCT FROM NEW.assigned_to THEN
			v_action := 'reassigned';
		ELSIF OLD.due_date IS DISTINCT FROM NEW.due_date THEN
			v_action := 'due_date_changed';
		ELSE
			v_action := 'updated';
		END IF;
		
		-- Store only changed fields
		v_previous_value := jsonb_build_object(
			'status', OLD.status,
			'assigned_to', OLD.assigned_to,
			'due_date', OLD.due_date,
			'priority', OLD.priority,
			'data', OLD.data
		);
		v_new_value := jsonb_build_object(
			'status', NEW.status,
			'assigned_to', NEW.assigned_to,
			'due_date', NEW.due_date,
			'priority', NEW.priority,
			'data', NEW.data
		);
	ELSIF TG_OP = 'DELETE' THEN
		v_action := 'deleted';
		v_previous_value := to_jsonb(OLD);
		v_new_value := NULL;
	END IF;
	
	-- Insert audit record
	INSERT INTO public.workflow_action_history (
		action_id,
		user_id,
		action,
		previous_value,
		new_value,
		ip_address,
		user_agent
	) VALUES (
		COALESCE(NEW.id, OLD.id),
		v_user_id,
		v_action,
		v_previous_value,
		v_new_value,
		inet(current_setting('request.headers', true)::json->>'cf-connecting-ip'),
		current_setting('request.headers', true)::json->>'user-agent'
	);
	
	RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.auto_advance_workflow()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
	v_workflow public.workflow_instances%ROWTYPE;
	v_next_stage public.workflow_template_stages%ROWTYPE;
	v_all_stages_complete BOOLEAN;
BEGIN
	-- Only process when stage becomes completed
	IF OLD.status IS DISTINCT FROM NEW.status AND NEW.status = 'completed' THEN
		-- Get workflow instance
		SELECT * INTO v_workflow FROM public.workflow_instances WHERE id = NEW.workflow_instance_id;
		
		-- Find next sequential stage
		SELECT * INTO v_next_stage
		FROM public.workflow_template_stages
		WHERE template_id = v_workflow.template_id
		AND stage_number > (
			SELECT stage_number 
			FROM public.workflow_template_stages 
			WHERE id = NEW.template_stage_id
		)
		ORDER BY stage_number
		LIMIT 1;
		
		IF v_next_stage.id IS NOT NULL THEN
			-- Create transition record
			INSERT INTO public.workflow_transitions (
				workflow_instance_id,
				from_stage_id,
				to_stage_id,
				triggered_by,
				transition_type
			) VALUES (
				NEW.workflow_instance_id,
				NEW.id,
				NULL,
				auth.uid(),
				'advance'
			);
			
			-- Activate next stage
			UPDATE public.workflow_stage_instances
			SET status = 'active',
			    started_at = NOW()
			WHERE workflow_instance_id = NEW.workflow_instance_id
			AND template_stage_id = v_next_stage.id;
			
			-- Update workflow current stage
			UPDATE public.workflow_instances
			SET current_stage_id = v_next_stage.id
			WHERE id = NEW.workflow_instance_id;
		ELSE
			-- Check if all stages are complete
			SELECT NOT EXISTS (
				SELECT 1 
				FROM public.workflow_stage_instances 
				WHERE workflow_instance_id = NEW.workflow_instance_id 
				AND status NOT IN ('completed', 'skipped')
			) INTO v_all_stages_complete;
			
			-- If all stages complete, mark workflow as completed
			IF v_all_stages_complete THEN
				UPDATE public.workflow_instances
				SET status = 'completed',
				    completed_at = NOW()
				WHERE id = NEW.workflow_instance_id;
			END IF;
		END IF;
	END IF;
	
	RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.auto_assign_workflow_actions()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
	v_role_assignment public.workflow_action_role_assignments%ROWTYPE;
	v_assignee_id UUID;
BEGIN
	-- Only process when stage becomes active
	IF NEW.status = 'active' AND OLD.status != 'active' THEN
		-- Get role assignments for this stage
		FOR v_role_assignment IN 
			SELECT * FROM public.workflow_action_role_assignments
			WHERE template_stage_id = NEW.template_stage_id
		LOOP
			-- Find user with appropriate role
			-- This is a simplified version - you might want to implement
			-- more complex assignment logic (load balancing, availability, etc.)
			SELECT id INTO v_assignee_id
			FROM auth.users
			WHERE raw_user_meta_data->>'role' = v_role_assignment.assigned_role_code
			AND (raw_user_meta_data->>'role_level')::INTEGER >= v_role_assignment.min_role_level
			-- Optionally filter by HQ or other criteria
			AND (
				v_role_assignment.assignment_rule->>'require_same_hq' != 'true' 
				OR raw_user_meta_data->>'hq_id' = (
					SELECT data->>'hq_id' 
					FROM public.workflow_instances 
					WHERE id = NEW.workflow_instance_id
				)
			)
			ORDER BY random() -- Simple random assignment
			LIMIT 1;
			
			-- Create action if assignee found
			IF v_assignee_id IS NOT NULL THEN
				INSERT INTO public.workflow_actions (
					stage_instance_id,
					action_type,
					assigned_to,
					assigned_by,
					priority,
					data
				) VALUES (
					NEW.id,
					v_role_assignment.action_type,
					v_assignee_id,
					NULL, -- System assigned
					'medium',
					jsonb_build_object('auto_assigned', true)
				);
			END IF;
		END LOOP;
	END IF;
	
	RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.can_create_workflow_from_template(p_template_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
	v_min_level INTEGER;
	v_allowed_roles TEXT[];
	v_user_role TEXT;
	v_user_level INTEGER;
BEGIN
	-- Get template permissions
	SELECT min_role_level, allowed_roles INTO v_min_level, v_allowed_roles
	FROM public.workflow_template_permissions
	WHERE template_id = p_template_id;
	
	-- If no permissions defined, require level 50 (local manager)
	IF v_min_level IS NULL THEN
		v_min_level := 50;
	END IF;
	
	-- Get user's role and level
	v_user_role := public.fn_get_current_role_code();
	v_user_level := public.fn_get_current_role_level();
	
	-- Check level requirement
	IF v_user_level < v_min_level THEN
		RETURN FALSE;
	END IF;
	
	-- If specific roles are defined, check if user's role is allowed
	IF array_length(v_allowed_roles, 1) > 0 THEN
		RETURN v_user_role = ANY(v_allowed_roles);
	END IF;
	
	RETURN TRUE;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.can_perform_workflow_action(p_action_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
	v_action public.workflow_actions%ROWTYPE;
	v_min_level INTEGER;
	v_allowed_roles TEXT[];
BEGIN
	-- Get action details
	SELECT * INTO v_action FROM public.workflow_actions WHERE id = p_action_id;
	
	-- User must be assigned to the action
	IF v_action.assigned_to != auth.uid() THEN
		-- Check if user is workflow admin
		IF public.is_workflow_admin() THEN
			RETURN TRUE;
		END IF;
		RETURN FALSE;
	END IF;
	
	-- Get role requirements for this action type
	SELECT min_role_level INTO v_min_level
	FROM public.workflow_action_role_assignments
	WHERE template_stage_id = (
		SELECT template_stage_id 
		FROM public.workflow_stage_instances 
		WHERE id = v_action.stage_instance_id
	)
	AND action_type = v_action.action_type;
	
	-- Check role level
	IF v_min_level IS NOT NULL AND public.fn_get_current_role_level() < v_min_level THEN
		RETURN FALSE;
	END IF;
	
	RETURN TRUE;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.check_collaborator_has_agreement()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.agreements WHERE user_id = NEW.user_id) THEN
        RAISE EXCEPTION 'Collaborator must have a valid agreement';
    END IF;
    RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.check_companion_student_hq_consistency()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE
    companion_hq_id UUID;
    student_hq_id UUID;
BEGIN
    -- Get companion's HQ for the relevant season
    SELECT a.headquarter_id INTO companion_hq_id
    FROM public.agreements a
    WHERE a.user_id = NEW.companion_id AND a.season_id = NEW.season_id
    LIMIT 1;

    -- Get student's HQ for the relevant season
    SELECT a.headquarter_id INTO student_hq_id
    FROM public.agreements a
    WHERE a.user_id = NEW.student_id AND a.season_id = NEW.season_id
    LIMIT 1;

    IF NEW.headquarter_id IS DISTINCT FROM companion_hq_id THEN
        RAISE EXCEPTION 'Companion HQ (%) does not match mapping HQ (%) for season %', companion_hq_id, NEW.headquarter_id, NEW.season_id;
    END IF;
    IF NEW.headquarter_id IS DISTINCT FROM student_hq_id THEN
        RAISE EXCEPTION 'Student HQ (%) does not match mapping HQ (%) for season %', student_hq_id, NEW.headquarter_id, NEW.season_id;
    END IF;
    RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.check_facilitator_workshop_map_consistency()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE
    facilitator_hq_id UUID;
    workshop_hq_id UUID;
    workshop_season_id UUID;
BEGIN
    -- Get facilitator's HQ
    SELECT c.headquarter_id INTO facilitator_hq_id
    FROM public.collaborators c
    WHERE c.user_id = NEW.facilitator_id
    LIMIT 1;

    -- Get workshop's HQ and season
    SELECT w.headquarter_id, w.season_id INTO workshop_hq_id, workshop_season_id
    FROM public.scheduled_workshops w
    WHERE w.id = NEW.workshop_id
    LIMIT 1;

    IF NEW.headquarter_id IS DISTINCT FROM facilitator_hq_id THEN
        RAISE EXCEPTION 'Facilitator HQ (%) does not match mapping HQ (%)', facilitator_hq_id, NEW.headquarter_id;
    END IF;
    IF NEW.headquarter_id IS DISTINCT FROM workshop_hq_id THEN
        RAISE EXCEPTION 'Workshop HQ (%) does not match mapping HQ (%)', workshop_hq_id, NEW.headquarter_id;
    END IF;
    IF NEW.season_id IS DISTINCT FROM workshop_season_id THEN
        RAISE EXCEPTION 'Workshop season (%) does not match mapping season (%)', workshop_season_id, NEW.season_id;
    END IF;
    RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.cleanup_expired_notifications()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
	v_count INTEGER;
BEGIN
	DELETE FROM public.notifications
	WHERE expires_at < NOW()
	OR (is_archived AND archived_at < NOW() - INTERVAL '30 days');
	
	GET DIAGNOSTICS v_count = ROW_COUNT;
	RETURN v_count;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.complete_workflow_action(p_action_id uuid, p_result jsonb DEFAULT '{}'::jsonb, p_comment text DEFAULT NULL::text)
 RETURNS boolean
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE
	v_action public.workflow_actions%ROWTYPE;
BEGIN
	-- Get action details
	SELECT * INTO v_action
	FROM public.workflow_actions
	WHERE id = p_action_id;
	
	-- Validate action exists and user is assigned
	IF v_action.id IS NULL THEN
		RAISE EXCEPTION 'Action not found';
	END IF;
	
	IF v_action.assigned_to != auth.uid() AND NOT is_workflow_admin() THEN
		RAISE EXCEPTION 'Not authorized to complete this action';
	END IF;
	
	IF v_action.status NOT IN ('pending', 'in_progress') THEN
		RAISE EXCEPTION 'Action is not in a completable state';
	END IF;
	
	-- Update action to completed
	UPDATE public.workflow_actions
	SET status = 'completed',
	    result = p_result,
	    completed_at = NOW(),
	    completed_by = auth.uid()
	WHERE id = p_action_id;
	
	-- Add history entry with comment if provided
	IF p_comment IS NOT NULL THEN
		INSERT INTO public.workflow_action_history (
			action_id,
			user_id,
			action,
			comment
		) VALUES (
			p_action_id,
			auth.uid(),
			'completed_with_comment',
			p_comment
		);
	END IF;
	
	RETURN true;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.create_notification_from_template(p_template_code text, p_recipient_id uuid, p_variables jsonb DEFAULT '{}'::jsonb, p_sender_id uuid DEFAULT NULL::uuid, p_priority public.notification_priority DEFAULT NULL::public.notification_priority, p_related_entity_type text DEFAULT NULL::text, p_related_entity_id uuid DEFAULT NULL::uuid, p_action_url text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
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
$function$
;

CREATE OR REPLACE FUNCTION public.create_workflow_instance(p_template_id uuid, p_data jsonb DEFAULT '{}'::jsonb)
 RETURNS uuid
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE
	v_workflow_id UUID;
	v_first_stage public.workflow_template_stages%ROWTYPE;
BEGIN
	-- Validate template exists and is active
	IF NOT EXISTS (
		SELECT 1 FROM public.workflow_templates 
		WHERE id = p_template_id AND is_active = true
	) THEN
		RAISE EXCEPTION 'Invalid or inactive workflow template';
	END IF;
	
	-- Create workflow instance
	INSERT INTO public.workflow_instances (
		template_id,
		initiated_by,
		status,
		data
	) VALUES (
		p_template_id,
		auth.uid(),
		'active',
		p_data
	) RETURNING id INTO v_workflow_id;
	
	-- Create stage instances for all template stages
	INSERT INTO public.workflow_stage_instances (
		workflow_instance_id,
		template_stage_id,
		status
	)
	SELECT
		v_workflow_id,
		id,
		CASE 
			WHEN stage_number = 1 THEN 'active'
			ELSE 'pending'
		END
	FROM public.workflow_template_stages
	WHERE template_id = p_template_id
	ORDER BY stage_number;
	
	-- Get first stage
	SELECT * INTO v_first_stage
	FROM public.workflow_template_stages
	WHERE template_id = p_template_id
	AND stage_number = 1;
	
	-- Update workflow with current stage
	UPDATE public.workflow_instances
	SET current_stage_id = v_first_stage.id
	WHERE id = v_workflow_id;
	
	-- Mark first stage as started
	UPDATE public.workflow_stage_instances
	SET started_at = NOW()
	WHERE workflow_instance_id = v_workflow_id
	AND template_stage_id = v_first_stage.id;
	
	RETURN v_workflow_id;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.fn_can_access_agreement(p_agreement_hq_id uuid, p_agreement_user_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
SELECT 
    CASE 
        -- Level 80+: Full access (Konsejo and above)
        WHEN public.fn_get_current_role_level() >= 80 THEN true
        
        -- Level 50-79: Only their headquarter (Local directors)
        WHEN public.fn_get_current_role_level() >= 50 THEN 
            p_agreement_hq_id = public.fn_get_current_hq_id()
        
        -- Level 21-49: Only their headquarter (Assistants)
        WHEN public.fn_get_current_role_level() >= 21 THEN 
            p_agreement_hq_id = public.fn_get_current_hq_id()
            
        -- Level 1-20: Only their own agreement
        ELSE p_agreement_user_id = auth.uid()
    END;
$function$
;

CREATE OR REPLACE FUNCTION public.fn_get_current_agreement_id()
 RETURNS uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
SELECT NULLIF(public.fn_get_current_user_metadata() ->> 'agreement_id', '')::uuid;
$function$
;

CREATE OR REPLACE FUNCTION public.fn_get_current_hq_id()
 RETURNS uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
SELECT NULLIF(public.fn_get_current_user_metadata() ->> 'hq_id', '')::uuid;
$function$
;

CREATE OR REPLACE FUNCTION public.fn_get_current_role_code()
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
SELECT public.fn_get_current_user_metadata() ->> 'role';
$function$
;

CREATE OR REPLACE FUNCTION public.fn_get_current_role_id()
 RETURNS uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
SELECT NULLIF(public.fn_get_current_user_metadata() ->> 'role_id', '')::uuid;
$function$
;

CREATE OR REPLACE FUNCTION public.fn_get_current_role_level()
 RETURNS integer
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
SELECT COALESCE((public.fn_get_current_user_metadata() ->> 'role_level')::integer, 0);
$function$
;

CREATE OR REPLACE FUNCTION public.fn_get_current_season_id()
 RETURNS uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
SELECT NULLIF(public.fn_get_current_user_metadata() ->> 'season_id', '')::uuid;
$function$
;

CREATE OR REPLACE FUNCTION public.fn_get_current_user_metadata()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
SELECT COALESCE(raw_user_meta_data, '{}'::jsonb)
FROM auth.users
WHERE id = auth.uid();
$function$
;

CREATE OR REPLACE FUNCTION public.fn_is_collaborator_or_higher()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
SELECT public.fn_get_current_role_level() >= 20;
$function$
;

CREATE OR REPLACE FUNCTION public.fn_is_current_user_hq_equal_to(hq_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
SELECT public.fn_get_current_hq_id() = hq_id;
$function$
;

CREATE OR REPLACE FUNCTION public.fn_is_general_director_or_higher()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
SELECT public.fn_get_current_role_level() >= 95;
$function$
;

CREATE OR REPLACE FUNCTION public.fn_is_konsejo_member_or_higher()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
SELECT public.fn_get_current_role_level() >= 80;
$function$
;

CREATE OR REPLACE FUNCTION public.fn_is_local_manager_or_higher()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
SELECT public.fn_get_current_role_level() >= 50;
$function$
;

CREATE OR REPLACE FUNCTION public.fn_is_manager_assistant_or_higher()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
SELECT public.fn_get_current_role_level() >= 30;
$function$
;

CREATE OR REPLACE FUNCTION public.fn_is_role_level_below(p_role_id uuid, p_level_threshold integer)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
    DECLARE
role_level INT;
BEGIN
SELECT level INTO role_level FROM public.roles WHERE id = p_role_id;
RETURN role_level < p_level_threshold;
END;
    $function$
;

CREATE OR REPLACE FUNCTION public.fn_is_student_or_higher()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
SELECT public.fn_get_current_role_level() >= 1;
$function$
;

CREATE OR REPLACE FUNCTION public.fn_is_super_admin()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
SELECT public.fn_get_current_role_level() >= 100;
$function$
;

CREATE OR REPLACE FUNCTION public.fn_is_valid_facilitator_for_hq(p_user_id uuid, p_headquarter_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
DECLARE
    is_valid boolean := false;
    facilitator_role_level integer := 20;
BEGIN
    -- Check if a collaborator exists, belongs to the HQ, and has the facilitator role level
    SELECT EXISTS (
        SELECT 1
        FROM public.collaborators c
        JOIN public.roles r ON c.role_id = r.id
        WHERE c.user_id = p_user_id
          AND c.headquarter_id = p_headquarter_id
          AND r.level >= facilitator_role_level
    ) INTO is_valid;
    RETURN is_valid;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_companion_effectiveness_metrics(target_hq_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    current_role_level integer;
    current_user_hq_id uuid;
    is_authorized      boolean := false;
    result_data        jsonb;
BEGIN
    -- Get current user's role level and HQ ID
    current_role_level := public.fn_get_current_role_level();
    current_user_hq_id := public.fn_get_current_hq_id();

    -- Permission Check
    IF target_hq_id IS NULL THEN
        -- Global stats require level 80+
        IF current_role_level >= 80 THEN
            is_authorized := true;
        END IF;
    ELSE
        -- HQ-specific stats require level 80+ OR level 50+ and in the same HQ
        IF current_role_level >= 80 OR
           (current_role_level >= 50 AND target_hq_id = current_user_hq_id) THEN
            is_authorized := true;
        END IF;
    END IF;

    IF NOT is_authorized THEN
        RAISE EXCEPTION 'Insufficient privileges to access companion effectiveness metrics.';
    END IF;

    -- Calculate companion effectiveness metrics
    IF target_hq_id IS NULL THEN
        -- Global companion metrics
        WITH companion_metrics AS (SELECT csm.headquarter_id,
                                          csm.companion_id,
                                          COUNT(DISTINCT csm.student_id) as assigned_students,
                                          AVG(CASE
                                                  WHEN sa.attendance_status = 'present' THEN 100.0
                                                  ELSE 0.0 END)          as student_attendance_rate
                                   FROM public.companion_student_map csm
                                            LEFT JOIN public.student_attendance sa
                                                      ON csm.student_id = sa.student_id
                                   GROUP BY csm.headquarter_id, csm.companion_id),
             hq_metrics AS (SELECT h.id                            as hq_id,
                                   h.name                          as hq_name,
                                   COUNT(DISTINCT cm.companion_id) as active_companions,
                                   AVG(cm.assigned_students)       as avg_students_per_companion,
                                   AVG(cm.student_attendance_rate) as avg_student_attendance_rate
                            FROM public.headquarters h
                                     LEFT JOIN companion_metrics cm ON h.id = cm.headquarter_id
                            GROUP BY h.id, h.name)
        SELECT jsonb_agg(
                       jsonb_build_object(
                               'headquarter_id', hm.hq_id,
                               'headquarter_name', hm.hq_name,
                               'active_companions', COALESCE(hm.active_companions, 0),
                               'avg_students_per_companion',
                               ROUND(COALESCE(hm.avg_students_per_companion, 0), 2),
                               'avg_student_attendance_rate',
                               ROUND(COALESCE(hm.avg_student_attendance_rate, 0), 2)
                       )
                       ORDER BY COALESCE(hm.avg_student_attendance_rate, 0) DESC
               )
        INTO result_data
        FROM hq_metrics hm;
    ELSE
        -- HQ-specific companion metrics
        WITH companion_metrics AS (SELECT csm.companion_id,
                                          a.name || ' ' || a.last_name   as companion_name,
                                          COUNT(DISTINCT csm.student_id) as assigned_students,
                                          AVG(CASE
                                                  WHEN sa.attendance_status = 'present' THEN 100.0
                                                  ELSE 0.0 END)          as student_attendance_rate
                                   FROM public.companion_student_map csm
                                            JOIN public.agreements a ON csm.companion_id = a.user_id
                                            LEFT JOIN public.student_attendance sa
                                                      ON csm.student_id = sa.student_id
                                   WHERE csm.headquarter_id = target_hq_id
                                   GROUP BY csm.companion_id, companion_name),
             hq_summary AS (SELECT COUNT(DISTINCT cm.companion_id) as active_companions,
                                   AVG(cm.assigned_students)       as avg_students_per_companion,
                                   AVG(cm.student_attendance_rate) as avg_student_attendance_rate
                            FROM companion_metrics cm)
        SELECT jsonb_build_object(
                       'headquarter_id', target_hq_id,
                       'headquarter_name', h.name,
                       'active_companions', COALESCE(hs.active_companions, 0),
                       'avg_students_per_companion',
                       ROUND(COALESCE(hs.avg_students_per_companion, 0), 2),
                       'avg_student_attendance_rate',
                       ROUND(COALESCE(hs.avg_student_attendance_rate, 0), 2),
                       'companion_details', COALESCE(
                               (SELECT jsonb_agg(
                                               jsonb_build_object(
                                                       'companion_id', cm.companion_id,
                                                       'companion_name', cm.companion_name,
                                                       'assigned_students', cm.assigned_students,
                                                       'student_attendance_rate',
                                                       ROUND(COALESCE(cm.student_attendance_rate, 0), 2)
                                               )
                                               ORDER BY cm.student_attendance_rate DESC
                                       )
                                FROM companion_metrics cm),
                               '[]'::jsonb
                                            )
               )
        INTO result_data
        FROM public.headquarters h
                 LEFT JOIN hq_summary hs ON TRUE
        WHERE h.id = target_hq_id;
    END IF;

    RETURN result_data;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_companion_student_attendance_issues(last_n_items integer DEFAULT 5)
 RETURNS TABLE(student_id uuid, student_first_name text, student_last_name text, missed_workshops_count bigint, total_workshops_count bigint, attendance_percentage numeric)
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE
    caller_id    uuid    := auth.uid();
    is_companion boolean := false;
BEGIN
    -- Verify the caller is currently mapped as a companion to at least one student
    SELECT EXISTS (SELECT 1 FROM public.companion_student_map WHERE companion_id = caller_id)
    INTO is_companion;

    IF NOT is_companion THEN
        RAISE EXCEPTION 'User % is not currently assigned as a companion.', caller_id;
    END IF;

    RETURN QUERY
        WITH AssignedStudents AS (
            -- Get students assigned to the calling companion
            SELECT csm.student_id
            FROM public.companion_student_map csm
            WHERE csm.companion_id = caller_id),
             StudentWorkshopAttendance AS (
                 -- Get attendance records for workshops
                 SELECT s.user_id                                       as student_id,
                        s.headquarter_id,
                        a.name                                          as student_first_name,
                        a.last_name                                     as student_last_name,
                        COUNT(sa.id)                                    as total_workshops,
                        COUNT(sa.id)
                        FILTER (WHERE sa.attendance_status = 'present') as attended_workshops
                 FROM public.students s
                          JOIN AssignedStudents ast ON s.user_id = ast.student_id
                          JOIN public.agreements a ON s.user_id = a.user_id
                          LEFT JOIN public.student_attendance sa ON s.user_id = sa.student_id
                 GROUP BY s.user_id, s.headquarter_id, a.name, a.last_name)
        -- Final selection: Students with attendance issues
        SELECT swa.student_id,
               swa.student_first_name,
               swa.student_last_name,
               (swa.total_workshops - swa.attended_workshops) as missed_workshops_count,
               swa.total_workshops                            as total_workshops_count,
               CASE
                   WHEN swa.total_workshops > 0 THEN
                       ROUND((swa.attended_workshops::numeric / swa.total_workshops) * 100, 2)
                   ELSE 0
                   END                                        as attendance_percentage
        FROM StudentWorkshopAttendance swa
        WHERE swa.total_workshops > 0
        ORDER BY attendance_percentage ASC;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_dashboard_agreement_review_statistics()
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE
    result jsonb;
BEGIN
    result := jsonb_build_object(
            'students', (WITH stats
                                  AS (SELECT COUNT(*)
                                             FILTER (WHERE a.status = 'prospect' AND r.code = 'student')  AS pending,
                                             COUNT(*)
                                             FILTER (WHERE a.status != 'prospect' AND r.code = 'student') AS reviewed,
                                             COUNT(*) FILTER (WHERE r.code = 'student')                   AS total
                                      FROM public.agreements a
                                               JOIN public.roles r ON a.role_id = r.id)
                         SELECT jsonb_build_object(
                                        'pending', pending,
                                        'reviewed', reviewed,
                                        'total', total,
                                        'percentage_reviewed', CASE
                                                                   WHEN total > 0
                                                                       THEN ROUND((reviewed::numeric / total::numeric) * 100, 2)
                                                                   ELSE 0
                                            END
                                )
                         FROM stats),
            'collaborators', (WITH stats
                                       AS (SELECT COUNT(*)
                                                  FILTER (WHERE a.status = 'prospect' AND r.level >= 10 AND r.level < 50)  AS pending,
                                                  COUNT(*)
                                                  FILTER (WHERE a.status != 'prospect' AND r.level >= 10 AND r.level < 50) AS reviewed,
                                                  COUNT(*) FILTER (WHERE r.level >= 10 AND r.level < 50)                   AS total
                                           FROM public.agreements a
                                                    JOIN public.roles r ON a.role_id = r.id)
                              SELECT jsonb_build_object(
                                             'pending', pending,
                                             'reviewed', reviewed,
                                             'total', total,
                                             'percentage_reviewed', CASE
                                                                        WHEN total > 0
                                                                            THEN ROUND((reviewed::numeric / total::numeric) * 100, 2)
                                                                        ELSE 0
                                                 END
                                     )
                              FROM stats),
            'konsejo_members', (WITH stats
                                         AS (SELECT COUNT(*)
                                                    FILTER (WHERE a.status = 'prospect' AND r.level >= 80)  AS pending,
                                                    COUNT(*)
                                                    FILTER (WHERE a.status != 'prospect' AND r.level >= 80) AS reviewed,
                                                    COUNT(*) FILTER (WHERE r.level >= 80)                   AS total
                                             FROM public.agreements a
                                                      JOIN public.roles r ON a.role_id = r.id)
                                SELECT jsonb_build_object(
                                               'pending', pending,
                                               'reviewed', reviewed,
                                               'total', total,
                                               'percentage_reviewed', CASE
                                                                          WHEN total > 0
                                                                              THEN ROUND((reviewed::numeric / total::numeric) * 100, 2)
                                                                          ELSE 0
                                                   END
                                       )
                                FROM stats),
            'directors', (WITH stats
                                   AS (SELECT COUNT(*)
                                              FILTER (WHERE a.status = 'prospect' AND r.level >= 50 AND r.level < 80)  AS pending,
                                              COUNT(*)
                                              FILTER (WHERE a.status != 'prospect' AND r.level >= 50 AND r.level < 80) AS reviewed,
                                              COUNT(*) FILTER (WHERE r.level >= 50 AND r.level < 80)                   AS total
                                       FROM public.agreements a
                                                JOIN public.roles r ON a.role_id = r.id)
                          SELECT jsonb_build_object(
                                         'pending', pending,
                                         'reviewed', reviewed,
                                         'total', total,
                                         'percentage_reviewed', CASE
                                                                    WHEN total > 0
                                                                        THEN ROUND((reviewed::numeric / total::numeric) * 100, 2)
                                                                    ELSE 0
                                             END
                                 )
                          FROM stats),
            'facilitators', (WITH stats
                                      AS (SELECT COUNT(*)
                                                 FILTER (WHERE a.status = 'prospect' AND r.code = 'facilitator')  AS pending,
                                                 COUNT(*)
                                                 FILTER (WHERE a.status != 'prospect' AND r.code = 'facilitator') AS reviewed,
                                                 COUNT(*) FILTER (WHERE r.code = 'facilitator')                   AS total
                                          FROM public.agreements a
                                                   JOIN public.roles r ON a.role_id = r.id)
                             SELECT jsonb_build_object(
                                            'pending', pending,
                                            'reviewed', reviewed,
                                            'total', total,
                                            'percentage_reviewed', CASE
                                                                       WHEN total > 0
                                                                           THEN ROUND((reviewed::numeric / total::numeric) * 100, 2)
                                                                       ELSE 0
                                                END
                                    )
                             FROM stats),
            'companions', (WITH stats
                                    AS (SELECT COUNT(*)
                                               FILTER (WHERE a.status = 'prospect' AND r.code = 'companion')  AS pending,
                                               COUNT(*)
                                               FILTER (WHERE a.status != 'prospect' AND r.code = 'companion') AS reviewed,
                                               COUNT(*) FILTER (WHERE r.code = 'companion')                   AS total
                                        FROM public.agreements a
                                                 JOIN public.roles r ON a.role_id = r.id)
                           SELECT jsonb_build_object(
                                          'pending', pending,
                                          'reviewed', reviewed,
                                          'total', total,
                                          'percentage_reviewed', CASE
                                                                     WHEN total > 0
                                                                         THEN ROUND((reviewed::numeric / total::numeric) * 100, 2)
                                                                     ELSE 0
                                              END
                                  )
                           FROM stats),
            'overall',
            (WITH stats AS (SELECT COUNT(*) FILTER (WHERE a.status = 'prospect')  AS pending,
                                   COUNT(*) FILTER (WHERE a.status != 'prospect') AS reviewed,
                                   COUNT(*)                                       AS total
                            FROM public.agreements a)
             SELECT jsonb_build_object(
                            'pending', pending,
                            'reviewed', reviewed,
                            'total', total,
                            'percentage_reviewed', CASE
                                                       WHEN total > 0
                                                           THEN ROUND((reviewed::numeric / total::numeric) * 100, 2)
                                                       ELSE 0
                                END
                    )
             FROM stats)
              );

    RETURN result;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_dashboard_statistics()
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE
    result jsonb;
BEGIN
    result := jsonb_build_object(
            'countries', (SELECT jsonb_build_object(
                                         'total', COUNT(*),
                                         'active', COUNT(*) FILTER (WHERE status = 'active'),
                                         'inactive', COUNT(*) FILTER (WHERE status = 'inactive')
                                 )
                          FROM public.countries),
            'headquarters', (SELECT jsonb_build_object(
                                            'total', COUNT(*),
                                            'active', COUNT(*) FILTER (WHERE status = 'active'),
                                            'inactive', COUNT(*) FILTER (WHERE status = 'inactive')
                                    )
                             FROM public.headquarters),
            'collaborators', (SELECT jsonb_build_object(
                                             'total', COUNT(*),
                                             'active', COUNT(*) FILTER (WHERE status = 'active'),
                                             'inactive',
                                             COUNT(*) FILTER (WHERE status = 'inactive'),
                                             'standby', COUNT(*) FILTER (WHERE status = 'standby')
                                     )
                              FROM public.collaborators),
            'students', (SELECT jsonb_build_object(
                                        'total', COUNT(*),
                                        'active', COUNT(*) FILTER (WHERE status = 'active'),
                                        'inactive', COUNT(*) FILTER (WHERE status != 'active')
                                )
                         FROM public.students),
            'konsejo_members', (SELECT jsonb_build_object(
                                               'total', COUNT(*),
                                               'active',
                                               COUNT(*) FILTER (WHERE c.status = 'active'),
                                               'inactive',
                                               COUNT(*) FILTER (WHERE c.status != 'active')
                                       )
                                FROM public.collaborators c
                                         JOIN public.roles r ON c.role_id = r.id
                                WHERE r.level >= 80),
            'directors', (SELECT jsonb_build_object(
                                         'total', COUNT(*),
                                         'active', COUNT(*) FILTER (WHERE c.status = 'active'),
                                         'inactive', COUNT(*) FILTER (WHERE c.status != 'active')
                                 )
                          FROM public.collaborators c
                                   JOIN public.roles r ON c.role_id = r.id
                          WHERE r.level >= 50
                            AND r.level < 80),
            'facilitators', (SELECT jsonb_build_object(
                                            'total', COUNT(*),
                                            'active', COUNT(*) FILTER (WHERE c.status = 'active'),
                                            'inactive', COUNT(*) FILTER (WHERE c.status != 'active')
                                    )
                             FROM public.collaborators c
                                      JOIN public.roles r ON c.role_id = r.id
                             WHERE r.code = 'facilitator'),
            'companions', (SELECT jsonb_build_object(
                                          'total', COUNT(*),
                                          'active', COUNT(*) FILTER (WHERE c.status = 'active'),
                                          'inactive', COUNT(*) FILTER (WHERE c.status != 'active')
                                  )
                           FROM public.collaborators c
                                    JOIN public.roles r ON c.role_id = r.id
                           WHERE r.code = 'companion')
              );

    RETURN result;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_facilitator_multiple_roles_stats()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    current_role_level integer;
    result_data        jsonb;
    global_stats       jsonb;
    hq_stats           jsonb;
BEGIN
    -- Permission Check
    current_role_level := public.fn_get_current_role_level();
    IF current_role_level < 80 THEN
        RAISE EXCEPTION 'Insufficient privileges. Required level: 80, Your level: %', current_role_level;
    END IF;

    -- Calculate global statistics
    WITH facilitator_roles AS (SELECT a.user_id,
                                      COUNT(DISTINCT a.headquarter_id) as hq_count,
                                      COUNT(DISTINCT a.role_id)        as role_count
                               FROM public.agreements a
                                        JOIN public.roles r ON a.role_id = r.id
                               WHERE r.name = 'Facilitator'
                                 AND a.status = 'active'
                               GROUP BY a.user_id)
    SELECT jsonb_build_object(
                   'total_facilitators', COUNT(*),
                   'facilitators_multiple_hqs', COUNT(*) FILTER (WHERE hq_count > 1),
                   'facilitators_multiple_roles', COUNT(*) FILTER (WHERE role_count > 1),
                   'multiple_hqs_percentage', ROUND(
                           (COUNT(*) FILTER (WHERE hq_count > 1)::numeric / NULLIF(COUNT(*), 0)) *
                           100, 2),
                   'multiple_roles_percentage', ROUND(
                           (COUNT(*) FILTER (WHERE role_count > 1)::numeric / NULLIF(COUNT(*), 0)) *
                           100, 2)
           )
    INTO global_stats
    FROM facilitator_roles;

    -- Calculate statistics by headquarter
    WITH facilitator_hq_roles AS (SELECT a.headquarter_id,
                                         a.user_id,
                                         COUNT(DISTINCT a.role_id) as role_count
                                  FROM public.agreements a
                                           JOIN public.roles r ON a.role_id = r.id
                                  WHERE r.name = 'Facilitator'
                                    AND a.status = 'active'
                                  GROUP BY a.headquarter_id, a.user_id),
         hq_role_stats AS (SELECT h.id                              as hq_id,
                                  h.name                            as hq_name,
                                  COUNT(DISTINCT fhr.user_id)       as total_facilitators,
                                  COUNT(DISTINCT fhr.user_id)
                                  FILTER (WHERE fhr.role_count > 1) as facilitators_multiple_roles
                           FROM public.headquarters h
                                    LEFT JOIN facilitator_hq_roles fhr ON h.id = fhr.headquarter_id
                           GROUP BY h.id, h.name)
    SELECT jsonb_agg(
                   jsonb_build_object(
                           'headquarter_id', hq_id,
                           'headquarter_name', hq_name,
                           'total_facilitators', total_facilitators,
                           'facilitators_multiple_roles', facilitators_multiple_roles,
                           'multiple_roles_percentage', CASE
                                                            WHEN total_facilitators > 0 THEN
                                                                ROUND(
                                                                        (facilitators_multiple_roles::numeric / total_facilitators) *
                                                                        100, 2)
                                                            ELSE 0
                               END
                   )
                   ORDER BY
                       CASE
                           WHEN total_facilitators > 0 THEN
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
$function$
;

CREATE OR REPLACE FUNCTION public.get_global_agreement_breakdown()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    current_role_level integer;
    breakdown_data     jsonb;
BEGIN
    -- Permission Check
    current_role_level := public.fn_get_current_role_level();
    IF current_role_level < 90 THEN -- Require Director level 90
        RAISE EXCEPTION 'Insufficient privileges. Required level: 90, Your level: %', current_role_level;
    END IF;

    -- Calculate the global breakdown
    SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::jsonb)
    INTO breakdown_data
    FROM (SELECT r.name   AS role_name,
                 a.status AS agreement_status,
                 COUNT(*) AS count
          FROM public.agreements a
                   JOIN public.roles r ON a.role_id = r.id -- Join directly to roles via a.role_id
          -- No headquarter filter for global view
          GROUP BY r.name, a.status
          ORDER BY r.name, a.status) t;

    RETURN breakdown_data;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_global_dashboard_stats()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    current_role_level          integer;
    total_headquarters          bigint;
    total_collaborators         bigint;
    total_students              bigint;
    total_active_seasons        bigint;
    total_agreements            bigint;
    agreements_prospect         bigint;
    agreements_active           bigint;
    agreements_inactive         bigint;
    agreements_graduated        bigint;
    agreements_this_year        bigint;
    stats                       jsonb;
    total_workshops             bigint;
    total_events                bigint;
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
    SELECT COUNT(*)                                                               AS total,
           COUNT(*) FILTER (WHERE status = 'prospect')                            AS prospect,
           COUNT(*) FILTER (WHERE status = 'active')                              AS active,
           COUNT(*) FILTER (WHERE status = 'inactive')                            AS inactive,
           COUNT(*) FILTER (WHERE status = 'graduated')                           AS graduated,
           COUNT(*) FILTER (WHERE created_at >= date_trunc('year', current_date)) AS this_year
    INTO
        total_agreements,
        agreements_prospect,
        agreements_active,
        agreements_inactive,
        agreements_graduated,
        agreements_this_year
    FROM public.agreements;

    -- Count scheduled_workshops and events associated with active seasons
    SELECT COUNT(w.*)
    INTO total_workshops
    FROM public.scheduled_workshops w
             JOIN public.seasons s ON w.season_id = s.id
    WHERE s.status = 'active';

    SELECT COUNT(e.*)
    INTO total_events
    FROM public.events e
             JOIN public.seasons s ON e.season_id = s.id
    WHERE s.status = 'active';
    -- Only count events in currently active seasons

    -- Calculate average time from prospect to active status
    SELECT AVG(EXTRACT(EPOCH FROM (activation_date - created_at)) / 86400.0) -- 86400 seconds in a day
    INTO avg_days_prospect_to_active
    FROM public.agreements
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
            'percentage_agreements_active', CASE
                                                WHEN total_agreements > 0 THEN ROUND(
                                                        (agreements_active::numeric / total_agreements) *
                                                        100, 2)
                                                ELSE 0 END,
            'percentage_agreements_prospect', CASE
                                                  WHEN total_agreements > 0 THEN ROUND(
                                                          (agreements_prospect::numeric / total_agreements) *
                                                          100, 2)
                                                  ELSE 0 END,
            'percentage_agreements_graduated', CASE
                                                   WHEN total_agreements > 0 THEN ROUND(
                                                           (agreements_graduated::numeric / total_agreements) *
                                                           100, 2)
                                                   ELSE 0 END,
            'total_active_seasons', total_active_seasons,
            'total_workshops_active_seasons', total_workshops,
            'total_events_active_seasons', total_events,
            'avg_days_prospect_to_active', COALESCE(ROUND(avg_days_prospect_to_active, 2), 0)
             );

    RETURN stats;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_headquarter_dashboard_stats(target_hq_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    current_role_level               integer;
    current_user_hq_id               uuid;
    is_authorized                    boolean := false;
    stats                            jsonb;
    -- Counts
    hq_active_students_count         bigint;
    hq_active_collaborators_count    bigint;
    hq_manager_assistants_count      bigint; -- Role Level >= 50
    hq_agreements_total              bigint;
    hq_agreements_prospect           bigint;
    hq_agreements_active             bigint;
    hq_agreements_inactive           bigint;
    hq_agreements_graduated          bigint;
    hq_agreements_this_year          bigint;
    hq_agreements_last_3_months      bigint;
    -- Distributions
    student_age_distribution         jsonb;
    collaborator_age_distribution    jsonb;
    student_gender_distribution      jsonb;
    collaborator_gender_distribution jsonb;
    -- Workshop & Event metrics
    workshops_count                  bigint;
    events_count                     bigint;
    avg_student_attendance_rate      numeric;
    avg_days_prospect_to_active      numeric;
    -- HQ info
    hq_name                          text;
BEGIN
    -- Get current user's role level and HQ ID
    current_role_level := public.fn_get_current_role_level();
    current_user_hq_id := public.fn_get_current_hq_id();
    -- Use single HQ ID function

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
    SELECT name INTO hq_name FROM public.headquarters WHERE id = target_hq_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Headquarter with ID % not found.', target_hq_id;
    END IF;

    -- Calculate stats for the target headquarter (SECURITY DEFINER bypasses RLS here)

    -- Student and Collaborator Counts
    SELECT COUNT(*)
    INTO hq_active_students_count
    FROM public.students
    WHERE headquarter_id = target_hq_id
      AND status = 'active';

    SELECT COUNT(*)
    INTO hq_active_collaborators_count
    FROM public.collaborators
    WHERE headquarter_id = target_hq_id
      AND status = 'active';

    -- Student gender distribution
    SELECT jsonb_object_agg(gender, count)
    INTO student_gender_distribution
    FROM (SELECT COALESCE(gender, 'unknown') as gender, COUNT(*) as count
          FROM public.agreements a
                   JOIN public.students s ON a.user_id = s.user_id
          WHERE s.headquarter_id = target_hq_id
            AND s.status = 'active'
          GROUP BY gender) genders;

    -- Student age distribution
    SELECT jsonb_object_agg(age_group, count)
    INTO student_age_distribution
    FROM (SELECT CASE
                     WHEN age < 18 THEN '<18'
                     WHEN age BETWEEN 18 AND 24 THEN '18-24'
                     WHEN age BETWEEN 25 AND 34 THEN '25-34'
                     WHEN age BETWEEN 35 AND 44 THEN '35-44'
                     WHEN age BETWEEN 45 AND 54 THEN '45-54'
                     WHEN age >= 55 THEN '55+'
                     ELSE 'Unknown'
                     END  as age_group,
                 COUNT(*) as count
          FROM (SELECT date_part('year', age(birth_date)) as age
                FROM public.agreements a
                         JOIN public.students s ON a.user_id = s.user_id
                WHERE s.headquarter_id = target_hq_id
                  AND s.status = 'active'
                  AND birth_date IS NOT NULL) ages
          GROUP BY age_group) grouped_ages;

    -- Collaborator gender distribution
    SELECT jsonb_object_agg(gender, count)
    INTO collaborator_gender_distribution
    FROM (SELECT COALESCE(gender, 'Unknown') as gender, COUNT(*) as count
          FROM public.agreements a
                   JOIN public.collaborators c ON a.user_id = c.user_id
          WHERE c.headquarter_id = target_hq_id
            AND c.status = 'active'
          GROUP BY gender) genders;

    -- Collaborator age distribution
    SELECT jsonb_object_agg(age_group, count)
    INTO collaborator_age_distribution
    FROM (SELECT CASE
                     WHEN age < 18 THEN '<18'
                     WHEN age BETWEEN 18 AND 24 THEN '18-24'
                     WHEN age BETWEEN 25 AND 34 THEN '25-34'
                     WHEN age BETWEEN 35 AND 44 THEN '35-44'
                     WHEN age BETWEEN 45 AND 54 THEN '45-54'
                     WHEN age >= 55 THEN '55+'
                     ELSE 'Unknown'
                     END  as age_group,
                 COUNT(*) as count
          FROM (SELECT date_part('year', age(birth_date)) as age
                FROM public.agreements a
                         JOIN public.collaborators c ON a.user_id = c.user_id
                WHERE c.headquarter_id = target_hq_id
                  AND c.status = 'active'
                  AND birth_date IS NOT NULL) ages
          GROUP BY age_group) grouped_ages;

    -- Count Manager Assistants+ (role level >= 50)
    SELECT COUNT(c.*)
    INTO hq_manager_assistants_count
    FROM public.collaborators c
             JOIN public.roles r ON c.role_id = r.id
    WHERE c.headquarter_id = target_hq_id
      AND c.status = 'active'
      AND r.level >= 50;

    -- Agreement Counts
    SELECT COUNT(*)                                                                 AS total,
           COUNT(*) FILTER (WHERE status = 'prospect')                              AS prospect,
           COUNT(*) FILTER (WHERE status = 'active')                                AS active,
           COUNT(*) FILTER (WHERE status = 'inactive')                              AS inactive,
           COUNT(*) FILTER (WHERE status = 'graduated')                             AS graduated,
           COUNT(*) FILTER (WHERE created_at >= date_trunc('year', current_date))   AS this_year,
           COUNT(*) FILTER (WHERE created_at >= current_date - interval '3 months') AS last_3_months
    INTO
        hq_agreements_total,
        hq_agreements_prospect,
        hq_agreements_active,
        hq_agreements_inactive,
        hq_agreements_graduated,
        hq_agreements_this_year,
        hq_agreements_last_3_months
    FROM public.agreements
    WHERE headquarter_id = target_hq_id;

    -- Calculate average time from prospect to active status
    SELECT AVG(EXTRACT(EPOCH FROM (activation_date - created_at)) / 86400.0) -- 86400 seconds in a day
    INTO avg_days_prospect_to_active
    FROM public.agreements
    WHERE headquarter_id = target_hq_id
      AND status IN ('active', 'graduated')
      AND activation_date IS NOT NULL
      AND created_at IS NOT NULL
      AND activation_date > created_at;

    -- Workshops and Events count
    SELECT COUNT(*)
    INTO workshops_count
    FROM public.scheduled_workshops
    WHERE headquarter_id = target_hq_id
      AND season_id IN (SELECT id FROM public.seasons WHERE status = 'active');

    SELECT COUNT(*)
    INTO events_count
    FROM public.events
    WHERE headquarter_id = target_hq_id
      AND season_id IN (SELECT id FROM public.seasons WHERE status = 'active');

    -- Student attendance rate (across all workshops in active seasons)
    SELECT COALESCE(AVG(CASE WHEN attendance_status = 'present' THEN 100.0 ELSE 0.0 END), 0)
    INTO avg_student_attendance_rate
    FROM public.student_attendance sa
             JOIN public.scheduled_workshops sw ON sa.scheduled_workshop_id = sw.id
             JOIN public.students s ON sa.student_id = s.user_id
    WHERE s.headquarter_id = target_hq_id
      AND sw.season_id IN (SELECT id FROM public.seasons WHERE status = 'active');

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
            'collaborator_gender_distribution',
            COALESCE(collaborator_gender_distribution, '{}'::jsonb),
            'agreements_total', hq_agreements_total,
            'agreements_prospect', hq_agreements_prospect,
            'agreements_active', hq_agreements_active,
            'agreements_inactive', hq_agreements_inactive,
            'agreements_graduated', hq_agreements_graduated,
            'agreements_this_year', hq_agreements_this_year,
            'agreements_last_3_months', hq_agreements_last_3_months,
            'agreements_active_percentage', CASE
                                                WHEN hq_agreements_total > 0 THEN ROUND(
                                                        (hq_agreements_active::numeric / hq_agreements_total) *
                                                        100, 2)
                                                ELSE 0 END,
            'agreements_prospect_percentage', CASE
                                                  WHEN hq_agreements_total > 0 THEN ROUND(
                                                          (hq_agreements_prospect::numeric / hq_agreements_total) *
                                                          100, 2)
                                                  ELSE 0 END,
            'agreements_graduated_percentage', CASE
                                                   WHEN hq_agreements_total > 0 THEN ROUND(
                                                           (hq_agreements_graduated::numeric / hq_agreements_total) *
                                                           100, 2)
                                                   ELSE 0 END,
            'workshops_count', workshops_count,
            'events_count', events_count,
            'avg_student_attendance_rate', ROUND(avg_student_attendance_rate, 2),
            'avg_days_prospect_to_active', COALESCE(ROUND(avg_days_prospect_to_active, 2), 0)
             );

    RETURN stats;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_hq_agreement_breakdown(target_hq_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    current_role_level integer;
    current_user_hq_id uuid;
    breakdown_data     jsonb;
BEGIN
    -- Get the role level and HQ ID of the user calling the function
    SELECT public.fn_get_current_role_level(),
           public.fn_get_current_hq_id() -- Use single HQ ID function
    INTO current_role_level, current_user_hq_id;

    -- Permission Check: Allow if user is in the target HQ or role level is >= 70
    IF NOT (current_user_hq_id = target_hq_id OR current_role_level >= 70) THEN
        RAISE EXCEPTION 'Insufficient privileges. User must belong to the target headquarter (%) or have role level >= 70.', target_hq_id;
    END IF;

    -- Calculate the breakdown
    SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::jsonb)
    INTO breakdown_data
    FROM (SELECT r.name   AS role_name,
                 a.status AS agreement_status,
                 COUNT(*) AS count
          FROM public.agreements a
                   JOIN public.roles r ON a.role_id = r.id -- Join directly to roles via a.role_id
          WHERE a.headquarter_id = target_hq_id
          GROUP BY r.name, a.status
          ORDER BY r.name, a.status) t;

    RETURN breakdown_data;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_hq_agreement_ranking_this_year()
 RETURNS TABLE(headquarter_id uuid, headquarter_name text, agreements_this_year_count bigint, agreements_graduated_count bigint, graduation_percentage numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    current_role_level integer;
BEGIN
    -- Permission Check
    current_role_level := public.fn_get_current_role_level();
    IF current_role_level < 80 THEN -- Let's use Director level 80
        RAISE EXCEPTION 'Insufficient privileges. Required level: 80, Your level: %', current_role_level;
    END IF;

    -- Calculate and return ranking
    RETURN QUERY
        SELECT h.id,
               h.name,
               COUNT(a.id)                                       as agreements_count,
               COUNT(a.id) FILTER (WHERE a.status = 'graduated') as graduated_count,
               CASE
                   WHEN COUNT(a.id) > 0 THEN
                       ROUND((COUNT(a.id) FILTER (WHERE a.status = 'graduated')::numeric /
                              COUNT(a.id)) * 100, 2)
                   ELSE 0
                   END                                           as graduation_percentage
        FROM public.agreements a
                 JOIN public.headquarters h ON a.headquarter_id = h.id
        WHERE a.created_at >= date_trunc('year', current_date)
        GROUP BY h.id, h.name
        ORDER BY agreements_count DESC;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_hq_graduation_ranking(months_back integer DEFAULT 12)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    current_role_level integer;
    result_data        jsonb;
BEGIN
    -- Permission Check
    current_role_level := public.fn_get_current_role_level();
    IF current_role_level < 80 THEN
        RAISE EXCEPTION 'Insufficient privileges. Required level: 80, Your level: %', current_role_level;
    END IF;

    -- Calculate graduation ratio for each headquarter
    WITH hq_stats AS (SELECT h.id   as hq_id,
                             h.name as hq_name,
                             COUNT(DISTINCT a.id) FILTER (
                                 WHERE
                                 a.role_id = (SELECT id FROM public.roles WHERE name = 'Student')
                                     AND a.created_at >= current_date - (months_back || ' months')::interval
                                 )  as total_students,
                             COUNT(DISTINCT a.id) FILTER (
                                 WHERE
                                 a.role_id = (SELECT id FROM public.roles WHERE name = 'Student')
                                     AND a.status = 'graduated'
                                     AND a.created_at >= current_date - (months_back || ' months')::interval
                                 )  as graduated_students
                      FROM public.headquarters h
                               LEFT JOIN public.agreements a ON a.headquarter_id = h.id
                      GROUP BY h.id, h.name)
    SELECT jsonb_agg(
                   jsonb_build_object(
                           'headquarter_id', hq_id,
                           'headquarter_name', hq_name,
                           'total_students', total_students,
                           'graduated_students', graduated_students,
                           'graduation_ratio', CASE
                                                   WHEN total_students > 0 THEN
                                                       ROUND(
                                                               (graduated_students::numeric / total_students) *
                                                               100, 2)
                                                   ELSE 0
                               END
                   )
                   ORDER BY
                       CASE
                           WHEN total_students > 0 THEN
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
$function$
;

CREATE OR REPLACE FUNCTION public.get_my_pending_actions()
 RETURNS TABLE(action_id uuid, workflow_id uuid, workflow_name text, stage_name text, action_type text, priority text, due_date timestamp with time zone, is_overdue boolean, assigned_at timestamp with time zone)
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
BEGIN
	RETURN QUERY
	SELECT
		wa.id,
		wi.id,
		wt.name,
		wts.name,
		wa.action_type,
		wa.priority,
		wa.due_date,
		CASE WHEN wa.due_date < NOW() THEN true ELSE false END,
		wa.created_at
	FROM public.workflow_actions wa
	JOIN public.workflow_stage_instances wsi ON wa.stage_instance_id = wsi.id
	JOIN public.workflow_instances wi ON wsi.workflow_instance_id = wi.id
	JOIN public.workflow_templates wt ON wi.template_id = wt.id
	JOIN public.workflow_template_stages wts ON wsi.template_stage_id = wts.id
	WHERE wa.assigned_to = auth.uid()
	AND wa.status IN ('pending', 'in_progress')
	ORDER BY 
		CASE WHEN wa.due_date < NOW() THEN 0 ELSE 1 END,
		wa.priority = 'high' DESC,
		wa.priority = 'medium' DESC,
		wa.due_date NULLS LAST,
		wa.created_at;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_prospect_to_active_avg_time(target_hq_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    current_role_level integer;
    current_user_hq_id uuid;
    is_authorized      boolean := false;
    result_data        jsonb;
    avg_days_global    numeric;
    avg_days_by_hq     jsonb;
BEGIN
    -- Get current user's role level and HQ ID
    current_role_level := public.fn_get_current_role_level();
    current_user_hq_id := public.fn_get_current_hq_id();

    -- Permission Check:
    -- If target_hq_id is NULL (global view), require Director+ (>=80)
    -- If target_hq_id is specified, allow if user is in that HQ or role level is >= 70
    IF target_hq_id IS NULL THEN
        IF current_role_level >= 80 THEN
            is_authorized := true;
        END IF;
    ELSE
        IF current_role_level >= 80 OR
           (current_role_level >= 50 AND target_hq_id = current_user_hq_id) THEN
            is_authorized := true;
        END IF;
    END IF;

    IF NOT is_authorized THEN
        RAISE EXCEPTION 'Insufficient privileges to access prospect-to-active conversion time statistics.';
    END IF;

    -- Calculate global average (if no specific HQ requested)
    IF target_hq_id IS NULL THEN
        SELECT ROUND(AVG(EXTRACT(EPOCH FROM (activation_date - created_at)) / 86400.0),
                     2) -- Convert to days
        INTO avg_days_global
        FROM public.agreements
        WHERE status IN ('active', 'graduated')
          AND activation_date IS NOT NULL
          AND created_at IS NOT NULL
          AND activation_date > created_at;

        -- Calculate average by headquarter
        SELECT jsonb_object_agg(hq_name, avg_days)
        INTO avg_days_by_hq
        FROM (SELECT h.name   as hq_name,
                     ROUND(AVG(EXTRACT(EPOCH FROM (a.activation_date - a.created_at)) / 86400.0),
                           2) as avg_days
              FROM public.agreements a
                       JOIN public.headquarters h ON a.headquarter_id = h.id
              WHERE a.status IN ('active', 'graduated')
                AND a.activation_date IS NOT NULL
                AND a.created_at IS NOT NULL
                AND a.activation_date > a.created_at
              GROUP BY h.name
              ORDER BY avg_days) t;

        -- Build result
        result_data := jsonb_build_object(
                'global_avg_days', COALESCE(avg_days_global, 0),
                'by_headquarter', COALESCE(avg_days_by_hq, '{}'::jsonb)
                       );
    ELSE
        -- Calculate for specific headquarter
        SELECT ROUND(AVG(EXTRACT(EPOCH FROM (activation_date - created_at)) / 86400.0),
                     2) -- Convert to days
        INTO avg_days_global
        FROM public.agreements
        WHERE headquarter_id = target_hq_id
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
        FROM public.headquarters h
        WHERE h.id = target_hq_id;
    END IF;

    RETURN result_data;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_student_progress_stats(target_hq_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    current_role_level integer;
    current_user_hq_id uuid;
    is_authorized      boolean := false;
    result_data        jsonb;
BEGIN
    -- Get current user's role level and HQ ID
    current_role_level := public.fn_get_current_role_level();
    current_user_hq_id := public.fn_get_current_hq_id();

    -- Permission Check
    IF target_hq_id IS NULL THEN
        -- Global stats require level 80+
        IF current_role_level >= 80 THEN
            is_authorized := true;
        END IF;
    ELSE
        -- HQ-specific stats require level 80+ OR level 50+ and in the same HQ
        IF current_role_level >= 80 OR
           (current_role_level >= 50 AND target_hq_id = current_user_hq_id) THEN
            is_authorized := true;
        END IF;
    END IF;

    IF NOT is_authorized THEN
        RAISE EXCEPTION 'Insufficient privileges to access student progress statistics.';
    END IF;

    -- Calculate student progress statistics
    IF target_hq_id IS NULL THEN
        -- Global student progress stats
        WITH student_status_counts AS (SELECT h.id                                              as hq_id,
                                              h.name                                            as hq_name,
                                              COUNT(s.id) FILTER (WHERE s.status = 'active')    as active_count,
                                              COUNT(s.id) FILTER (WHERE s.status = 'prospect')  as prospect_count,
                                              COUNT(s.id) FILTER (WHERE s.status = 'graduated') as graduated_count,
                                              COUNT(s.id) FILTER (WHERE s.status = 'inactive')  as inactive_count,
                                              COUNT(s.id)                                       as total_count
                                       FROM public.headquarters h
                                                LEFT JOIN public.students s ON h.id = s.headquarter_id
                                       GROUP BY h.id, h.name),
             attendance_stats AS (SELECT s.headquarter_id,
                                         AVG(CASE
                                                 WHEN sa.attendance_status = 'present' THEN 100.0
                                                 ELSE 0.0 END) as avg_attendance_rate
                                  FROM public.student_attendance sa
                                           JOIN public.students s ON sa.student_id = s.user_id
                                  GROUP BY s.headquarter_id)
        SELECT jsonb_agg(
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
                                                            ROUND(
                                                                    (ssc.active_count::numeric / ssc.total_count) *
                                                                    100, 2)
                                                        ELSE 0
                                   END,
                               'graduated_percentage', CASE
                                                           WHEN ssc.total_count > 0 THEN
                                                               ROUND(
                                                                       (ssc.graduated_count::numeric / ssc.total_count) *
                                                                       100, 2)
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
        WITH student_data AS (SELECT COUNT(s.id) FILTER (WHERE s.status = 'active')    as active_count,
                                     COUNT(s.id) FILTER (WHERE s.status = 'prospect')  as prospect_count,
                                     COUNT(s.id) FILTER (WHERE s.status = 'graduated') as graduated_count,
                                     COUNT(s.id) FILTER (WHERE s.status = 'inactive')  as inactive_count,
                                     COUNT(s.id)                                       as total_count,
                                     AVG(CASE
                                             WHEN sa.attendance_status = 'present' THEN 100.0
                                             ELSE 0.0 END)                             as avg_attendance_rate
                              FROM public.headquarters h
                                       LEFT JOIN public.students s ON h.id = s.headquarter_id
                                       LEFT JOIN public.student_attendance sa ON s.user_id = sa.student_id
                              WHERE h.id = target_hq_id
                              GROUP BY h.id)
        SELECT jsonb_build_object(
                       'headquarter_id', target_hq_id,
                       'headquarter_name', h.name,
                       'active_count', COALESCE(sd.active_count, 0),
                       'prospect_count', COALESCE(sd.prospect_count, 0),
                       'graduated_count', COALESCE(sd.graduated_count, 0),
                       'inactive_count', COALESCE(sd.inactive_count, 0),
                       'total_count', COALESCE(sd.total_count, 0),
                       'active_percentage', CASE
                                                WHEN COALESCE(sd.total_count, 0) > 0 THEN
                                                    ROUND(
                                                            (sd.active_count::numeric / sd.total_count) *
                                                            100, 2)
                                                ELSE 0
                           END,
                       'graduated_percentage', CASE
                                                   WHEN COALESCE(sd.total_count, 0) > 0 THEN
                                                       ROUND(
                                                               (sd.graduated_count::numeric / sd.total_count) *
                                                               100, 2)
                                                   ELSE 0
                           END,
                       'avg_attendance_rate', ROUND(COALESCE(sd.avg_attendance_rate, 0), 2)
               )
        INTO result_data
        FROM public.headquarters h
                 LEFT JOIN student_data sd ON TRUE
        WHERE h.id = target_hq_id;
    END IF;

    RETURN result_data;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_student_trend_by_quarter(quarters_back integer DEFAULT 4)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    current_role_level integer;
    result_data        jsonb;
    quarters           jsonb;
BEGIN
    -- Permission Check
    current_role_level := public.fn_get_current_role_level();
    IF current_role_level < 80 THEN
        RAISE EXCEPTION 'Insufficient privileges. Required level: 80, Your level: %', current_role_level;
    END IF;

    -- Generate array of quarters to analyze
    WITH RECURSIVE quarters_cte AS (SELECT date_trunc('quarter', current_date) as quarter_start,
                                           1                                   as quarter_num
                                    UNION ALL
                                    SELECT date_trunc('quarter', quarter_start - interval '3 months') as quarter_start,
                                           quarter_num + 1
                                    FROM quarters_cte
                                    WHERE quarter_num < quarters_back)
    SELECT jsonb_agg(
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
    WITH quarter_dates AS (SELECT q ->> 'quarter'                   as quarter_label,
                                  (q ->> 'start_date')::timestamptz as start_date,
                                  (q ->> 'end_date')::timestamptz   as end_date
                           FROM jsonb_array_elements(quarters) as q),
         headquarter_quarters AS (SELECT h.id   as hq_id,
                                         h.name as hq_name,
                                         qd.quarter_label,
                                         qd.start_date,
                                         qd.end_date,
                                         COUNT(DISTINCT s.user_id) FILTER (
                                             WHERE s.status = 'active'
                                                 AND (s.enrollment_date <= qd.end_date)
                                             -- Additional filtering if needed
                                             )  as active_students
                                  FROM public.headquarters h
                                           CROSS JOIN quarter_dates qd
                                           LEFT JOIN public.students s ON s.headquarter_id = h.id
                                  GROUP BY h.id, h.name, qd.quarter_label, qd.start_date,
                                           qd.end_date
                                  ORDER BY h.name, qd.start_date DESC),
         headquarter_trends AS (SELECT hq_id,
                                       hq_name,
                                       jsonb_agg(
                                               jsonb_build_object(
                                                       'quarter', quarter_label,
                                                       'active_students', active_students
                                               )
                                               ORDER BY start_date DESC
                                       ) as quarters_data
                                FROM headquarter_quarters
                                GROUP BY hq_id, hq_name)
    SELECT jsonb_agg(
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
$function$
;

CREATE OR REPLACE FUNCTION public.get_unread_notification_count(p_user_id uuid DEFAULT NULL::uuid)
 RETURNS bigint
 LANGUAGE sql
 SET search_path TO ''
AS $function$
	SELECT COUNT(*)
	FROM public.notifications
	WHERE 
		recipient_id = COALESCE(p_user_id, auth.uid())
		AND NOT is_read 
		AND NOT is_archived
		AND (expires_at IS NULL OR expires_at > NOW());
$function$
;

CREATE OR REPLACE FUNCTION public.get_user_dashboard_stats(target_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    invoker_user_id                uuid;
    invoker_role_level             integer;
    invoker_hq_id                  uuid; -- Changed from uuid[]
    target_agreement               RECORD;
    target_role                    RECORD;
    target_hq                      RECORD;
    target_season                  RECORD;
    target_person                  RECORD; -- Can be student or collaborator details
    target_user_email              text;
    stats                          jsonb;
    target_user_type               text    := 'Unknown';
    target_record_id               uuid    := NULL;
    target_full_name               text    := NULL;
    is_authorized                  boolean := false;
    -- Student specific
    student_attendance_rate        numeric;
    student_schedule               jsonb;
    student_companion_info         jsonb;
    -- Companion specific
    companion_assigned_students    jsonb;
    companion_student_count        integer;
    -- Facilitator specific
    facilitator_workshops_count    integer;
    facilitator_upcoming_workshops jsonb;
    collaborator_details           jsonb;
BEGIN
    -- Get invoker details
    invoker_user_id := auth.uid();
    invoker_role_level := public.fn_get_current_role_level();
    invoker_hq_id := public.fn_get_current_hq_id();
    -- Use single HQ ID function

    -- Find the target user's *single latest active* agreement
    SELECT a.*
    INTO target_agreement
    FROM public.agreements a
             JOIN public.seasons s ON a.season_id = s.id
    WHERE a.user_id = target_user_id
      AND s.status = 'active'
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
    ELSIF invoker_role_level >= 50 AND
          target_agreement.headquarter_id = invoker_hq_id THEN -- Check against single HQ ID
        is_authorized := true;
    END IF;

    IF NOT is_authorized THEN
        RAISE EXCEPTION 'Insufficient privileges (level % requires self, >= 90, or >= 50 for same HQ) to access dashboard for user ID %.', invoker_role_level, target_user_id;
    END IF;

    -- Fetch associated records (SECURITY DEFINER bypasses RLS)
    SELECT * INTO target_hq FROM public.headquarters WHERE id = target_agreement.headquarter_id;
    SELECT * INTO target_season FROM public.seasons WHERE id = target_agreement.season_id;
    SELECT email INTO target_user_email FROM auth.users WHERE id = target_user_id;
    -- Check if the user is a student or collaborator based on the agreement/role
    SELECT * INTO target_role FROM public.roles WHERE id = target_agreement.role_id;

    -- Determine if this is a student or collaborator
    IF target_role.name = 'Student' THEN
        target_user_type := 'Student';
        -- Try to find student record
        SELECT s.id,
               s.user_id,
               s.status,
               (a.name || ' ' || a.last_name) as full_name
        INTO target_person
        FROM public.students s
                 JOIN public.agreements a ON s.user_id = a.user_id
        WHERE s.user_id = target_user_id
        LIMIT 1;
    ELSE
        target_user_type := 'Collaborator';
        -- Try to find collaborator record
        SELECT c.id,
               c.user_id,
               c.status,
               (a.name || ' ' || a.last_name) as full_name
        INTO target_person
        FROM public.collaborators c
                 JOIN public.agreements a ON c.user_id = a.user_id
        WHERE c.user_id = target_user_id
        LIMIT 1;
    END IF;

    -- Set default full name if not found
    IF target_person IS NULL THEN
        target_full_name := COALESCE(target_agreement.name || ' ' || target_agreement.last_name,
                                     'Record Not Found for Role');
    ELSE
        target_full_name := COALESCE(target_person.full_name, 'Name Not Available');
    END IF;

    -- Calculate Role-Specific Stats
    IF target_user_type = 'Student' AND target_person IS NOT NULL THEN
        -- Attendance Rate (for active season workshops)
        SELECT COALESCE(
                       ROUND(
                               (SUM(CASE WHEN sa.attendance_status = 'present' THEN 1 ELSE 0 END)::numeric /
                                NULLIF(COUNT(*), 0)) * 100,
                               2
                       ),
                       0
               )
        INTO student_attendance_rate
        FROM public.student_attendance sa
                 JOIN public.scheduled_workshops sw ON sa.scheduled_workshop_id = sw.id
        WHERE sa.student_id = target_user_id
          AND sw.season_id = target_season.id;

        -- Schedule (upcoming workshops in active season/HQ)
        WITH UpcomingWorkshops AS (SELECT sw.id             as item_id,
                                          sw.local_name     as item_name,
                                          sw.start_datetime as item_date,
                                          'workshop'        as item_type,
                                          mwt.name          as workshop_type
                                   FROM public.scheduled_workshops sw
                                            JOIN public.master_workshop_types mwt
                                                 ON sw.master_workshop_type_id = mwt.id
                                   WHERE sw.headquarter_id = target_hq.id
                                     AND sw.season_id = target_season.id
                                     AND sw.start_datetime >= current_date
                                     AND sw.status = 'scheduled'),
             UpcomingEvents AS (SELECT e.id             as item_id,
                                       e.title          as item_name,
                                       e.start_datetime as item_date,
                                       'event'          as item_type,
                                       et.name          as event_type
                                FROM public.events e
                                         JOIN public.event_types et ON e.event_type_id = et.id
                                WHERE e.headquarter_id = target_hq.id
                                  AND e.season_id = target_season.id
                                  AND e.start_datetime >= current_date
                                  AND e.status = 'scheduled'),
             CombinedSchedule AS (SELECT item_id,
                                         item_name,
                                         item_date,
                                         item_type,
                                         workshop_type as type_name
                                  FROM UpcomingWorkshops
                                  UNION ALL
                                  SELECT item_id,
                                         item_name,
                                         item_date,
                                         item_type,
                                         event_type as type_name
                                  FROM UpcomingEvents)
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
        FROM public.companion_student_map csm
                 JOIN public.agreements a ON csm.companion_id = a.user_id
        WHERE csm.student_id = target_user_id
          AND csm.season_id = target_season.id
        LIMIT 1;
        -- Assuming one companion per student per season

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
            SELECT COUNT(*)
            INTO companion_student_count
            FROM public.companion_student_map
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
            FROM public.companion_student_map csm
                     JOIN public.students s ON csm.student_id = s.user_id
                     JOIN public.agreements a ON s.user_id = a.user_id
            WHERE csm.companion_id = target_user_id
              AND csm.season_id = target_season.id;

            -- Logic specific to Companions
            collaborator_details := collaborator_details || jsonb_build_object(
                    'assigned_students_count', companion_student_count,
                    'assigned_students', companion_assigned_students
                                                            );

        ELSIF target_role.name = 'Facilitator' THEN
            -- Count workshops
            SELECT COUNT(*)
            INTO facilitator_workshops_count
            FROM public.scheduled_workshops
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
            FROM public.scheduled_workshops sw
                     JOIN public.master_workshop_types mwt ON sw.master_workshop_type_id = mwt.id
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
        END IF;
        -- End specific collaborator role checks

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
$function$
;

CREATE OR REPLACE FUNCTION public.get_user_notifications(p_limit integer DEFAULT 20, p_offset integer DEFAULT 0, p_type public.notification_type DEFAULT NULL::public.notification_type, p_priority public.notification_priority DEFAULT NULL::public.notification_priority, p_is_read boolean DEFAULT NULL::boolean, p_category text DEFAULT NULL::text)
 RETURNS TABLE(id uuid, type public.notification_type, priority public.notification_priority, sender_id uuid, sender_name text, title text, body text, data jsonb, is_read boolean, read_at timestamp with time zone, created_at timestamp with time zone, action_url text, total_count bigint)
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
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
$function$
;

CREATE OR REPLACE FUNCTION public.get_workflow_status(p_workflow_id uuid)
 RETURNS TABLE(workflow_id uuid, template_name text, status text, current_stage text, total_stages integer, completed_stages integer, total_actions integer, completed_actions integer, pending_actions integer, overdue_actions integer)
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
BEGIN
	RETURN QUERY
	SELECT
		wi.id,
		wt.name,
		wi.status,
		wts.name,
		COUNT(DISTINCT wsi.id)::INTEGER,
		COUNT(DISTINCT CASE WHEN wsi.status = 'completed' THEN wsi.id END)::INTEGER,
		COUNT(DISTINCT wa.id)::INTEGER,
		COUNT(DISTINCT CASE WHEN wa.status = 'completed' THEN wa.id END)::INTEGER,
		COUNT(DISTINCT CASE WHEN wa.status = 'pending' THEN wa.id END)::INTEGER,
		COUNT(DISTINCT CASE WHEN wa.status = 'pending' AND wa.due_date < NOW() THEN wa.id END)::INTEGER
	FROM public.workflow_instances wi
	JOIN public.workflow_templates wt ON wi.template_id = wt.id
	LEFT JOIN public.workflow_template_stages wts ON wi.current_stage_id = wts.id
	LEFT JOIN public.workflow_stage_instances wsi ON wi.id = wsi.workflow_instance_id
	LEFT JOIN public.workflow_actions wa ON wsi.id = wa.stage_instance_id
	WHERE wi.id = p_workflow_id
	GROUP BY wi.id, wt.name, wi.status, wts.name;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.is_workflow_admin()
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
	-- Konsejo members (80+) and above can administer workflows
	RETURN public.fn_is_konsejo_member_or_higher();
END;
$function$
;

CREATE OR REPLACE FUNCTION public.is_workflow_participant(p_workflow_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
	RETURN EXISTS (
		SELECT 1 
		FROM public.workflow_actions wa
		JOIN public.workflow_stage_instances wsi ON wa.stage_instance_id = wsi.id
		WHERE wsi.workflow_instance_id = p_workflow_id
		AND wa.assigned_to = auth.uid()
	);
END;
$function$
;

CREATE OR REPLACE FUNCTION public.mark_notifications_read(p_notification_ids uuid[])
 RETURNS integer
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
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
$function$
;

CREATE OR REPLACE FUNCTION public.notify_user_created()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
	IF NEW.status = 'active' AND OLD.status = 'prospect' AND NEW.user_id IS NOT NULL THEN
		-- Welcome notification for new user
		INSERT INTO public.notifications (
			type,
			priority,
			sender_type,
			recipient_id,
			title,
			body,
			data,
			related_entity_type,
			related_entity_id
		) VALUES (
			'system',
			'high',
			'system',
			NEW.user_id,
			'¡Bienvenido a la Academia!',
			'Tu cuenta ha sido activada exitosamente. Ahora puedes acceder a todos los recursos de la plataforma.',
			jsonb_build_object(
				'agreement_id', NEW.id,
				'headquarter_id', NEW.headquarter_id,
				'season_id', NEW.season_id
			),
			'agreement',
			NEW.id
		);
		
		-- Notify local manager about new user
		INSERT INTO public.notifications (
			type,
			priority,
			sender_type,
			recipient_id,
			title,
			body,
			data,
			related_entity_type,
			related_entity_id
		)
		SELECT 
			'action_required',
			'medium',
			'system',
			u.id,
			'Nuevo usuario activado',
			'Se ha activado un nuevo usuario en tu sede: ' || NEW.name || ' ' || NEW.last_name,
			jsonb_build_object(
				'agreement_id', NEW.id,
				'user_name', NEW.name || ' ' || NEW.last_name,
				'user_email', NEW.email
			),
			'agreement',
			NEW.id
		FROM auth.users u
		WHERE 
			(u.raw_user_meta_data->>'hq_id')::UUID = NEW.headquarter_id
			AND (u.raw_user_meta_data->>'role_level')::INTEGER >= 50;
	END IF;
	
	RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.notify_workflow_action_assigned()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
	v_workflow_data RECORD;
BEGIN
	IF NEW.assigned_to IS NOT NULL AND (OLD.assigned_to IS NULL OR OLD.assigned_to != NEW.assigned_to) THEN
		-- Get workflow information
		SELECT 
			wi.name AS workflow_name,
			wts.name AS stage_name,
			wi.initiated_by
		INTO v_workflow_data
		FROM public.workflow_stage_instances wsi
		JOIN public.workflow_instances wi ON wsi.workflow_instance_id = wi.id
		JOIN public.workflow_template_stages wts ON wsi.template_stage_id = wts.id
		WHERE wsi.id = NEW.stage_instance_id;
		
		-- Create notification for assignee
		INSERT INTO public.notifications (
			type,
			priority,
			sender_id,
			sender_type,
			recipient_id,
			title,
			body,
			data,
			related_entity_type,
			related_entity_id,
			action_url
		) VALUES (
			'action_required',
			CASE NEW.priority
				WHEN 'urgent' THEN 'urgent'
				WHEN 'high' THEN 'high'
				ELSE 'medium'
			END,
			v_workflow_data.initiated_by,
			'workflow',
			NEW.assigned_to,
			'Nueva acción asignada: ' || NEW.action_type,
			'Se te ha asignado una acción en el flujo "' || v_workflow_data.workflow_name || 
			'" - Etapa: ' || v_workflow_data.stage_name,
			jsonb_build_object(
				'action_id', NEW.id,
				'action_type', NEW.action_type,
				'workflow_name', v_workflow_data.workflow_name,
				'stage_name', v_workflow_data.stage_name,
				'due_date', NEW.due_date
			),
			'workflow_action',
			NEW.id,
			'/workflows/actions/' || NEW.id
		);
	END IF;
	
	RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.notify_workflow_action_completed()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
	v_workflow_data RECORD;
	v_next_user UUID;
BEGIN
	IF NEW.status = 'completed' AND OLD.status != 'completed' THEN
		-- Get workflow information
		SELECT 
			wi.name AS workflow_name,
			wi.initiated_by,
			wsi.id AS stage_instance_id
		INTO v_workflow_data
		FROM public.workflow_stage_instances wsi
		JOIN public.workflow_instances wi ON wsi.workflow_instance_id = wi.id
		WHERE wsi.id = NEW.stage_instance_id;
		
		-- Notify workflow initiator
		IF v_workflow_data.initiated_by != NEW.performed_by THEN
			INSERT INTO public.notifications (
				type,
				priority,
				sender_id,
				sender_type,
				recipient_id,
				title,
				body,
				data,
				related_entity_type,
				related_entity_id
			) VALUES (
				'system',
				'medium',
				NEW.performed_by,
				'workflow',
				v_workflow_data.initiated_by,
				'Acción completada en tu flujo',
				'La acción "' || NEW.action_type || '" ha sido completada en el flujo "' || 
				v_workflow_data.workflow_name || '"',
				jsonb_build_object(
					'action_id', NEW.id,
					'action_type', NEW.action_type,
					'workflow_name', v_workflow_data.workflow_name,
					'completed_by', NEW.performed_by
				),
				'workflow_action',
				NEW.id
			);
		END IF;
		
		-- Check if there are pending actions in the same stage for notification
		SELECT assigned_to INTO v_next_user
		FROM public.workflow_actions
		WHERE 
			stage_instance_id = NEW.stage_instance_id
			AND status = 'pending'
			AND id != NEW.id
		LIMIT 1;
		
		IF v_next_user IS NOT NULL THEN
			INSERT INTO public.notifications (
				type,
				priority,
				sender_type,
				recipient_id,
				title,
				body,
				data,
				related_entity_type,
				related_entity_id
			) VALUES (
				'reminder',
				'medium',
				'system',
				v_next_user,
				'Recordatorio: Tienes acciones pendientes',
				'Un compañero ha completado su parte. Ahora es tu turno en el flujo "' || 
				v_workflow_data.workflow_name || '"',
				jsonb_build_object(
					'workflow_name', v_workflow_data.workflow_name,
					'stage_instance_id', v_workflow_data.stage_instance_id
				),
				'workflow_action',
				NEW.stage_instance_id
			);
		END IF;
	END IF;
	
	RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.notify_workshop_reminder()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
	-- When a workshop is scheduled, create reminder notifications
	IF NEW.scheduled_date IS NOT NULL AND 
	   (OLD.scheduled_date IS NULL OR OLD.scheduled_date != NEW.scheduled_date) THEN
		
		-- Notification for facilitators (1 day before)
		INSERT INTO public.notifications (
			type,
			priority,
			sender_type,
			recipient_id,
			title,
			body,
			data,
			related_entity_type,
			related_entity_id,
			expires_at
		)
		SELECT 
			'reminder',
			'high',
			'system',
			fwm.user_id,
			'Recordatorio: Taller mañana',
			'Tienes un taller programado para mañana: ' || NEW.name,
			jsonb_build_object(
				'workshop_id', NEW.id,
				'workshop_name', NEW.name,
				'scheduled_date', NEW.scheduled_date,
				'location', NEW.location
			),
			'workshop',
			NEW.id,
			NEW.scheduled_date::TIMESTAMPTZ
		FROM public.facilitator_workshop_map fwm
		WHERE fwm.workshop_id = NEW.id;
		
		-- Schedule these notifications to be sent 1 day before
		-- This would be handled by a cron job or scheduled function
	END IF;
	
	RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.reject_workflow_action(p_action_id uuid, p_reason text, p_comment text DEFAULT NULL::text)
 RETURNS boolean
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE
	v_action public.workflow_actions%ROWTYPE;
BEGIN
	-- Get action details
	SELECT * INTO v_action
	FROM public.workflow_actions
	WHERE id = p_action_id;
	
	-- Validate action exists and user is assigned
	IF v_action.id IS NULL THEN
		RAISE EXCEPTION 'Action not found';
	END IF;
	
	IF v_action.assigned_to != auth.uid() AND NOT is_workflow_admin() THEN
		RAISE EXCEPTION 'Not authorized to reject this action';
	END IF;
	
	IF v_action.status NOT IN ('pending', 'in_progress') THEN
		RAISE EXCEPTION 'Action is not in a rejectable state';
	END IF;
	
	-- Update action to rejected
	UPDATE public.workflow_actions
	SET status = 'rejected',
	    rejection_reason = p_reason,
	    rejected_at = NOW(),
	    rejected_by = auth.uid()
	WHERE id = p_action_id;
	
	-- Add history entry
	INSERT INTO public.workflow_action_history (
		action_id,
		user_id,
		action,
		comment
	) VALUES (
		p_action_id,
		auth.uid(),
		'rejected',
		COALESCE(p_comment, p_reason)
	);
	
	RETURN true;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.search_users_vector(p_query text, p_role_code text DEFAULT NULL::text, p_min_role_level integer DEFAULT NULL::integer, p_limit integer DEFAULT 10, p_offset integer DEFAULT 0)
 RETURNS TABLE(user_id uuid, full_name text, email text, role_code text, role_name text, role_level integer, headquarter_name text, similarity real)
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
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
$function$
;

CREATE OR REPLACE FUNCTION public.send_role_based_notification(p_role_codes text[], p_title text, p_body text, p_min_role_level integer DEFAULT NULL::integer, p_type public.notification_type DEFAULT 'role_based'::public.notification_type, p_priority public.notification_priority DEFAULT 'medium'::public.notification_priority, p_data jsonb DEFAULT '{}'::jsonb)
 RETURNS integer
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
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
$function$
;

CREATE OR REPLACE FUNCTION public.set_activation_date_on_update()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    IF OLD.status = 'prospect' AND NEW.status = 'active' AND NEW.activation_date IS NULL THEN
        NEW.activation_date := NOW();
    END IF;
    RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.track_action_completion()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
	v_stage_instance public.workflow_stage_instances%ROWTYPE;
	v_template_stage public.workflow_template_stages%ROWTYPE;
	v_completed_count INTEGER;
BEGIN
	-- Only process on status change to completed or rejected
	IF OLD.status IS DISTINCT FROM NEW.status AND 
	   NEW.status IN ('completed', 'rejected') THEN
		
		-- Set completion/rejection timestamps
		IF NEW.status = 'completed' AND NEW.completed_at IS NULL THEN
			NEW.completed_at := NOW();
			NEW.completed_by := COALESCE(NEW.completed_by, auth.uid());
		ELSIF NEW.status = 'rejected' AND NEW.rejected_at IS NULL THEN
			NEW.rejected_at := NOW();
			NEW.rejected_by := COALESCE(NEW.rejected_by, auth.uid());
		END IF;
		
		-- Get stage instance and template info
		SELECT * INTO v_stage_instance FROM public.workflow_stage_instances WHERE id = NEW.stage_instance_id;
		SELECT * INTO v_template_stage FROM public.workflow_template_stages WHERE id = v_stage_instance.template_stage_id;
		
		-- Count completed actions for this stage
		SELECT COUNT(*) INTO v_completed_count
		FROM public.workflow_actions
		WHERE stage_instance_id = NEW.stage_instance_id
		AND status = 'completed';
		
		-- Update stage instance completed actions count
		UPDATE public.workflow_stage_instances
		SET completed_actions = v_completed_count
		WHERE id = NEW.stage_instance_id;
		
		-- Check if stage is complete (meets approval threshold)
		IF v_completed_count >= v_template_stage.approval_threshold THEN
			UPDATE public.workflow_stage_instances
			SET status = 'completed',
			    completed_at = NOW()
			WHERE id = NEW.stage_instance_id
			AND status != 'completed';
		END IF;
	END IF;
	
	RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.track_stage_instance_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
BEGIN
	-- Track status changes
	IF OLD.status IS DISTINCT FROM NEW.status THEN
		-- If moving to active, set started_at
		IF NEW.status = 'active' AND NEW.started_at IS NULL THEN
			NEW.started_at := NOW();
		END IF;
		
		-- If moving to completed, set completed_at
		IF NEW.status = 'completed' AND NEW.completed_at IS NULL THEN
			NEW.completed_at := NOW();
		END IF;
	END IF;
	
	RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.track_workflow_instance_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
BEGIN
	-- Track status changes
	IF OLD.status IS DISTINCT FROM NEW.status THEN
		-- If moving to completed, set completed_at
		IF NEW.status = 'completed' AND NEW.completed_at IS NULL THEN
			NEW.completed_at := NOW();
		END IF;
		
		-- If moving to cancelled, set cancelled_at
		IF NEW.status = 'cancelled' AND NEW.cancelled_at IS NULL THEN
			NEW.cancelled_at := NOW();
		END IF;
	END IF;
	
	RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.trg_audit()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  user_email text;
BEGIN
  -- Get the user's email for better readability in audit logs
  SELECT email INTO user_email FROM auth.users WHERE id = auth.uid();

  IF (TG_OP = 'DELETE') THEN
    INSERT INTO public.audit_log(table_name, action, record_id, changed_by, user_name, diff)
    VALUES (TG_TABLE_NAME, TG_OP, OLD.id, auth.uid(), user_email, to_jsonb(OLD));
    RETURN OLD;
  ELSIF (TG_OP = 'UPDATE') THEN
    INSERT INTO public.audit_log(table_name, action, record_id, changed_by, user_name, diff)
    VALUES (TG_TABLE_NAME, TG_OP, NEW.id, auth.uid(), user_email,
            jsonb_build_object('old', to_jsonb(OLD), 'new', to_jsonb(NEW)));
    RETURN NEW;
  ELSE  -- INSERT
    INSERT INTO public.audit_log(table_name, action, record_id, changed_by, user_name, diff)
    VALUES (TG_TABLE_NAME, TG_OP, NEW.id, auth.uid(), user_email, to_jsonb(NEW));
    RETURN NEW;
  END IF;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.trigger_validate_workshop_facilitator()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
BEGIN
    -- Check on INSERT or if facilitator_id or headquarter_id is changed on UPDATE
    IF TG_OP = 'INSERT' OR (TG_OP = 'UPDATE' AND (NEW.facilitator_id IS DISTINCT FROM OLD.facilitator_id OR NEW.headquarter_id IS DISTINCT FROM OLD.headquarter_id)) THEN
        IF NOT public.fn_is_valid_facilitator_for_hq(NEW.facilitator_id, NEW.headquarter_id) THEN
            RAISE EXCEPTION 'User ID % is not a valid facilitator for headquarter ID %.', NEW.facilitator_id, NEW.headquarter_id;
        END IF;
    END IF;
    RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.update_fts_name_lastname()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    NEW.fts_name_lastname :=
        setweight(to_tsvector('spanish', coalesce(NEW.name, '')), 'A') ||
        setweight(to_tsvector('spanish', coalesce(NEW.last_name, '')), 'A') ||
        setweight(to_tsvector('spanish', coalesce(NEW.name, '') || ' ' || coalesce(NEW.last_name, '')), 'B');
    RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.update_user_search_index()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
$function$
;


