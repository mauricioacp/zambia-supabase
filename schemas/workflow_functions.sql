-- Workflow Helper Functions

-- Function to create a new workflow instance from a template
CREATE OR REPLACE FUNCTION create_workflow_instance(
	p_template_id UUID,
	p_data JSONB DEFAULT '{}'
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
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
$$;

-- Function to assign an action to a user
CREATE OR REPLACE FUNCTION assign_workflow_action(
	p_stage_instance_id UUID,
	p_action_type TEXT,
	p_assigned_to UUID,
	p_due_date TIMESTAMPTZ DEFAULT NULL,
	p_priority TEXT DEFAULT 'medium',
	p_data JSONB DEFAULT '{}'
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
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
$$;

-- Function to complete an action
CREATE OR REPLACE FUNCTION complete_workflow_action(
	p_action_id UUID,
	p_result JSONB DEFAULT '{}',
	p_comment TEXT DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
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
$$;

-- Function to reject an action
CREATE OR REPLACE FUNCTION reject_workflow_action(
	p_action_id UUID,
	p_reason TEXT,
	p_comment TEXT DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
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
$$;

-- Function to get workflow status summary
CREATE OR REPLACE FUNCTION get_workflow_status(p_workflow_id UUID)
RETURNS TABLE (
	workflow_id UUID,
	template_name TEXT,
	status TEXT,
	current_stage TEXT,
	total_stages INTEGER,
	completed_stages INTEGER,
	total_actions INTEGER,
	completed_actions INTEGER,
	pending_actions INTEGER,
	overdue_actions INTEGER
)
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
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
$$;

-- Function to get user's pending actions
CREATE OR REPLACE FUNCTION get_my_pending_actions()
RETURNS TABLE (
	action_id UUID,
	workflow_id UUID,
	workflow_name TEXT,
	stage_name TEXT,
	action_type TEXT,
	priority TEXT,
	due_date TIMESTAMPTZ,
	is_overdue BOOLEAN,
	assigned_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
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
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION create_workflow_instance TO authenticated;
GRANT EXECUTE ON FUNCTION assign_workflow_action TO authenticated;
GRANT EXECUTE ON FUNCTION complete_workflow_action TO authenticated;
GRANT EXECUTE ON FUNCTION reject_workflow_action TO authenticated;
GRANT EXECUTE ON FUNCTION get_workflow_status TO authenticated;
GRANT EXECUTE ON FUNCTION get_my_pending_actions TO authenticated;