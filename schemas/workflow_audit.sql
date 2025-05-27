-- Workflow Audit Functions and Triggers

-- Function to audit workflow action changes
CREATE OR REPLACE FUNCTION audit_workflow_action_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
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
$$;

-- Function to track workflow instance state changes
CREATE OR REPLACE FUNCTION track_workflow_instance_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
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
$$;

-- Function to track stage instance completion
CREATE OR REPLACE FUNCTION track_stage_instance_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
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
$$;

-- Function to track action completion
CREATE OR REPLACE FUNCTION track_action_completion()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
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
$$;

-- Function to auto-advance workflow stages
CREATE OR REPLACE FUNCTION auto_advance_workflow()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
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
$$;

-- Apply audit triggers
CREATE TRIGGER audit_workflow_actions
	AFTER INSERT OR UPDATE OR DELETE ON workflow_actions
	FOR EACH ROW EXECUTE FUNCTION audit_workflow_action_change();

CREATE TRIGGER track_workflow_instance_state
	BEFORE UPDATE ON workflow_instances
	FOR EACH ROW EXECUTE FUNCTION track_workflow_instance_change();

CREATE TRIGGER track_stage_instance_state
	BEFORE UPDATE ON workflow_stage_instances
	FOR EACH ROW EXECUTE FUNCTION track_stage_instance_change();

CREATE TRIGGER track_action_completion_state
	BEFORE UPDATE ON workflow_actions
	FOR EACH ROW EXECUTE FUNCTION track_action_completion();

CREATE TRIGGER auto_advance_workflow_stage
	AFTER UPDATE ON workflow_stage_instances
	FOR EACH ROW EXECUTE FUNCTION auto_advance_workflow();