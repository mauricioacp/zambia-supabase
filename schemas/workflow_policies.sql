-- Workflow RLS Policies

-- Helper function to check if user has workflow admin role (level 80+)
CREATE OR REPLACE FUNCTION is_workflow_admin()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
	-- Konsejo members (80+) and above can administer workflows
	RETURN public.fn_is_konsejo_member_or_higher();
END;
$$;

-- Helper function to check if user is involved in a workflow
CREATE OR REPLACE FUNCTION is_workflow_participant(p_workflow_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
	RETURN EXISTS (
		SELECT 1 
		FROM public.workflow_actions wa
		JOIN public.workflow_stage_instances wsi ON wa.stage_instance_id = wsi.id
		WHERE wsi.workflow_instance_id = p_workflow_id
		AND wa.assigned_to = auth.uid()
	);
END;
$$;

-- Workflow Templates Policies
CREATE POLICY "Workflow admins can manage templates"
	ON workflow_templates
	FOR ALL
	USING (is_workflow_admin())
	WITH CHECK (is_workflow_admin());

CREATE POLICY "Users can view active templates"
	ON workflow_templates
	FOR SELECT
	USING (is_active = true);

-- Workflow Template Stages Policies
CREATE POLICY "Workflow admins can manage template stages"
	ON workflow_template_stages
	FOR ALL
	USING (is_workflow_admin())
	WITH CHECK (is_workflow_admin());

CREATE POLICY "Users can view stages of active templates"
	ON workflow_template_stages
	FOR SELECT
	USING (
		EXISTS (
			SELECT 1 FROM workflow_templates wt
			WHERE wt.id = template_id
			AND wt.is_active = true
		)
	);

-- Workflow Instances Policies
CREATE POLICY "Workflow admins can manage all instances"
	ON workflow_instances
	FOR ALL
	USING (is_workflow_admin())
	WITH CHECK (is_workflow_admin());

CREATE POLICY "Users can view workflows they initiated"
	ON workflow_instances
	FOR SELECT
	USING (initiated_by = auth.uid());

CREATE POLICY "Users can view workflows they participate in"
	ON workflow_instances
	FOR SELECT
	USING (is_workflow_participant(id));

-- Note: The insert policy is now defined in workflow_rbac.sql with proper permission checks

-- Workflow Stage Instances Policies
CREATE POLICY "Workflow admins can manage all stage instances"
	ON workflow_stage_instances
	FOR ALL
	USING (is_workflow_admin())
	WITH CHECK (is_workflow_admin());

CREATE POLICY "Users can view stages of their workflows"
	ON workflow_stage_instances
	FOR SELECT
	USING (
		EXISTS (
			SELECT 1 FROM workflow_instances wi
			WHERE wi.id = workflow_instance_id
			AND (wi.initiated_by = auth.uid() OR is_workflow_participant(wi.id))
		)
	);

-- Workflow Actions Policies
CREATE POLICY "Workflow admins can manage all actions"
	ON workflow_actions
	FOR ALL
	USING (is_workflow_admin())
	WITH CHECK (is_workflow_admin());

CREATE POLICY "Users can view actions assigned to them"
	ON workflow_actions
	FOR SELECT
	USING (assigned_to = auth.uid());

CREATE POLICY "Users can view actions in their workflows"
	ON workflow_actions
	FOR SELECT
	USING (
		EXISTS (
			SELECT 1 
			FROM workflow_stage_instances wsi
			JOIN workflow_instances wi ON wsi.workflow_instance_id = wi.id
			WHERE wsi.id = stage_instance_id
			AND wi.initiated_by = auth.uid()
		)
	);

CREATE POLICY "Users can update their assigned actions"
	ON workflow_actions
	FOR UPDATE
	USING (
		assigned_to = auth.uid() AND
		status IN ('pending', 'in_progress')
	)
	WITH CHECK (
		assigned_to = auth.uid()
		-- Note: Cannot prevent changing assignment in RLS policy
		-- Assignment changes should be restricted through application logic
	);

-- Workflow Action History Policies
CREATE POLICY "Workflow admins can view all history"
	ON workflow_action_history
	FOR SELECT
	USING (is_workflow_admin());

CREATE POLICY "Users can view history of their actions"
	ON workflow_action_history
	FOR SELECT
	USING (
		EXISTS (
			SELECT 1 FROM workflow_actions wa
			WHERE wa.id = action_id
			AND wa.assigned_to = auth.uid()
		)
	);

CREATE POLICY "System can insert history records"
	ON workflow_action_history
	FOR INSERT
	WITH CHECK (true);

-- Workflow Transitions Policies
CREATE POLICY "Workflow admins can view all transitions"
	ON workflow_transitions
	FOR SELECT
	USING (is_workflow_admin());

CREATE POLICY "Users can view transitions of their workflows"
	ON workflow_transitions
	FOR SELECT
	USING (
		EXISTS (
			SELECT 1 FROM workflow_instances wi
			WHERE wi.id = workflow_instance_id
			AND (wi.initiated_by = auth.uid() OR is_workflow_participant(wi.id))
		)
	);

CREATE POLICY "System can insert transition records"
	ON workflow_transitions
	FOR INSERT
	WITH CHECK (true);

-- Workflow Notifications Policies
CREATE POLICY "Users can view their notifications"
	ON workflow_notifications
	FOR SELECT
	USING (recipient_id = auth.uid());

CREATE POLICY "Users can update their notifications (mark as read)"
	ON workflow_notifications
	FOR UPDATE
	USING (recipient_id = auth.uid())
	WITH CHECK (
		recipient_id = auth.uid()
		-- Note: Cannot prevent changing fields other than read_at in RLS policy
		-- Field restrictions should be handled through application logic
	);

CREATE POLICY "System can create notifications"
	ON workflow_notifications
	FOR INSERT
	WITH CHECK (true);

-- Grant necessary permissions to authenticated users
GRANT SELECT ON workflow_templates TO authenticated;
GRANT SELECT ON workflow_template_stages TO authenticated;
GRANT SELECT, INSERT ON workflow_instances TO authenticated;
GRANT SELECT ON workflow_stage_instances TO authenticated;
GRANT SELECT, UPDATE ON workflow_actions TO authenticated;
GRANT SELECT ON workflow_action_history TO authenticated;
GRANT SELECT ON workflow_transitions TO authenticated;
GRANT SELECT, UPDATE ON workflow_notifications TO authenticated;