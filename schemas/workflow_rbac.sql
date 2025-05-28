-- Workflow RBAC Integration
-- This file integrates the workflow system with the existing RBAC structure

-- Table to define which roles can create specific workflow templates
CREATE TABLE IF NOT EXISTS workflow_template_permissions (
	id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
	template_id UUID NOT NULL REFERENCES workflow_templates(id) ON DELETE CASCADE,
	min_role_level INTEGER NOT NULL DEFAULT 50, -- Minimum role level to create instances
	allowed_roles TEXT[] DEFAULT '{}', -- Specific role codes that can use this template
	created_at TIMESTAMPTZ DEFAULT NOW(),
	updated_at TIMESTAMPTZ DEFAULT NOW(),
	UNIQUE(template_id)
);

-- Table to define role-based action assignments
CREATE TABLE IF NOT EXISTS workflow_action_role_assignments (
	id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
	template_stage_id UUID NOT NULL REFERENCES workflow_template_stages(id) ON DELETE CASCADE,
	action_type TEXT NOT NULL,
	assigned_role_code TEXT, -- Role code that should handle this action type
	min_role_level INTEGER DEFAULT 20, -- Minimum role level required
	assignment_rule JSONB DEFAULT '{}', -- Additional rules for assignment
	created_at TIMESTAMPTZ DEFAULT NOW(),
	updated_at TIMESTAMPTZ DEFAULT NOW(),
	UNIQUE(template_stage_id, action_type)
);

-- Function to check if user can create workflow from template
CREATE OR REPLACE FUNCTION can_create_workflow_from_template(p_template_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
	v_min_level INTEGER;
	v_allowed_roles TEXT[];
	v_user_role TEXT;
	v_user_level INTEGER;
BEGIN
	-- Get template permissions
	SELECT min_role_level, allowed_roles INTO v_min_level, v_allowed_roles
	FROM workflow_template_permissions
	WHERE template_id = p_template_id;
	
	-- If no permissions defined, require level 50 (local manager)
	IF v_min_level IS NULL THEN
		v_min_level := 50;
	END IF;
	
	-- Get user's role and level
	v_user_role := fn_get_current_role_code();
	v_user_level := fn_get_current_role_level();
	
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to auto-assign actions based on role
CREATE OR REPLACE FUNCTION auto_assign_workflow_actions()
RETURNS TRIGGER AS $$
DECLARE
	v_role_assignment workflow_action_role_assignments%ROWTYPE;
	v_assignee_id UUID;
BEGIN
	-- Only process when stage becomes active
	IF NEW.status = 'active' AND OLD.status != 'active' THEN
		-- Get role assignments for this stage
		FOR v_role_assignment IN 
			SELECT * FROM workflow_action_role_assignments
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
					FROM workflow_instances 
					WHERE id = NEW.workflow_instance_id
				)
			)
			ORDER BY random() -- Simple random assignment
			LIMIT 1;
			
			-- Create action if assignee found
			IF v_assignee_id IS NOT NULL THEN
				INSERT INTO workflow_actions (
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if user can perform action based on role
CREATE OR REPLACE FUNCTION can_perform_workflow_action(p_action_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
	v_action workflow_actions%ROWTYPE;
	v_min_level INTEGER;
	v_allowed_roles TEXT[];
BEGIN
	-- Get action details
	SELECT * INTO v_action FROM workflow_actions WHERE id = p_action_id;
	
	-- User must be assigned to the action
	IF v_action.assigned_to != auth.uid() THEN
		-- Check if user is workflow admin
		IF is_workflow_admin() THEN
			RETURN TRUE;
		END IF;
		RETURN FALSE;
	END IF;
	
	-- Get role requirements for this action type
	SELECT min_role_level INTO v_min_level
	FROM workflow_action_role_assignments
	WHERE template_stage_id = (
		SELECT template_stage_id 
		FROM workflow_stage_instances 
		WHERE id = v_action.stage_instance_id
	)
	AND action_type = v_action.action_type;
	
	-- Check role level
	IF v_min_level IS NOT NULL AND fn_get_current_role_level() < v_min_level THEN
		RETURN FALSE;
	END IF;
	
	RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Users can create workflow instances with proper permissions
CREATE POLICY "Users can create workflow instances with permission"
	ON workflow_instances
	FOR INSERT
	TO authenticated
	WITH CHECK (
		initiated_by = auth.uid() AND
		can_create_workflow_from_template(template_id)
	);

-- Add trigger for auto-assignment
CREATE TRIGGER auto_assign_actions_on_stage_activation
	AFTER UPDATE ON workflow_stage_instances
	FOR EACH ROW EXECUTE FUNCTION auto_assign_workflow_actions();

-- Indexes
CREATE INDEX IF NOT EXISTS idx_workflow_template_permissions_template ON workflow_template_permissions(template_id);
CREATE INDEX IF NOT EXISTS idx_workflow_action_role_assignments_stage ON workflow_action_role_assignments(template_stage_id);

-- Enable RLS
ALTER TABLE workflow_template_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE workflow_action_role_assignments ENABLE ROW LEVEL SECURITY;

-- Policies for permission tables (only workflow admins can manage)
CREATE POLICY "Workflow admins can manage template permissions"
	ON workflow_template_permissions
	FOR ALL
	USING (is_workflow_admin())
	WITH CHECK (is_workflow_admin());

CREATE POLICY "Workflow admins can manage role assignments"
	ON workflow_action_role_assignments
	FOR ALL
	USING (is_workflow_admin())
	WITH CHECK (is_workflow_admin());

-- Update triggers
CREATE TRIGGER handle_updated_at_workflow_template_permissions
	BEFORE UPDATE ON workflow_template_permissions
	FOR EACH ROW EXECUTE PROCEDURE moddatetime(updated_at);

CREATE TRIGGER handle_updated_at_workflow_action_role_assignments
	BEFORE UPDATE ON workflow_action_role_assignments
	FOR EACH ROW EXECUTE PROCEDURE moddatetime(updated_at);