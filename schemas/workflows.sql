-- Workflow Templates: Define reusable workflow structures
CREATE TABLE IF NOT EXISTS workflow_templates (
	id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
	name TEXT NOT NULL,
	description TEXT,
	created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
	is_active BOOLEAN DEFAULT true,
	metadata JSONB DEFAULT '{}',
	created_at TIMESTAMPTZ DEFAULT NOW(),
	updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Workflow Template Stages: Define stages within templates
CREATE TABLE IF NOT EXISTS workflow_template_stages (
	id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
	template_id UUID NOT NULL REFERENCES workflow_templates(id) ON DELETE CASCADE,
	stage_number INTEGER NOT NULL,
	name TEXT NOT NULL,
	description TEXT,
	stage_type TEXT CHECK (stage_type IN ('sequential', 'parallel')) DEFAULT 'sequential',
	required_actions INTEGER DEFAULT 1,
	approval_threshold INTEGER DEFAULT 1,
	metadata JSONB DEFAULT '{}',
	created_at TIMESTAMPTZ DEFAULT NOW(),
	updated_at TIMESTAMPTZ DEFAULT NOW(),
	UNIQUE(template_id, stage_number)
);

-- Workflow Instances: Active executions of templates
CREATE TABLE IF NOT EXISTS workflow_instances (
	id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
	template_id UUID NOT NULL REFERENCES workflow_templates(id) ON DELETE RESTRICT,
	current_stage_id UUID REFERENCES workflow_template_stages(id),
	status TEXT CHECK (status IN ('draft', 'active', 'completed', 'cancelled', 'failed')) DEFAULT 'draft',
	initiated_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
	data JSONB DEFAULT '{}',
	completed_at TIMESTAMPTZ,
	cancelled_at TIMESTAMPTZ,
	created_at TIMESTAMPTZ DEFAULT NOW(),
	updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Workflow Stage Instances: Track progress of each stage
CREATE TABLE IF NOT EXISTS workflow_stage_instances (
	id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
	workflow_instance_id UUID NOT NULL REFERENCES workflow_instances(id) ON DELETE CASCADE,
	template_stage_id UUID NOT NULL REFERENCES workflow_template_stages(id) ON DELETE RESTRICT,
	status TEXT CHECK (status IN ('pending', 'active', 'completed', 'failed', 'skipped')) DEFAULT 'pending',
	started_at TIMESTAMPTZ,
	completed_at TIMESTAMPTZ,
	completed_actions INTEGER DEFAULT 0,
	created_at TIMESTAMPTZ DEFAULT NOW(),
	updated_at TIMESTAMPTZ DEFAULT NOW(),
	UNIQUE(workflow_instance_id, template_stage_id)
);

-- Workflow Actions: Individual tasks within stages
CREATE TABLE IF NOT EXISTS workflow_actions (
	id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
	stage_instance_id UUID NOT NULL REFERENCES workflow_stage_instances(id) ON DELETE CASCADE,
	action_type TEXT CHECK (action_type IN ('approve', 'review', 'upload', 'sign', 'custom')) NOT NULL,
	assigned_to UUID REFERENCES auth.users(id) ON DELETE SET NULL,
	assigned_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
	status TEXT CHECK (status IN ('pending', 'in_progress', 'completed', 'rejected', 'cancelled')) DEFAULT 'pending',
	due_date TIMESTAMPTZ,
	priority TEXT CHECK (priority IN ('high', 'medium', 'low')) DEFAULT 'medium',
	data JSONB DEFAULT '{}',
	result JSONB DEFAULT '{}',
	completed_at TIMESTAMPTZ,
	completed_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
	rejected_at TIMESTAMPTZ,
	rejected_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
	rejection_reason TEXT,
	created_at TIMESTAMPTZ DEFAULT NOW(),
	updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Workflow Action History: Audit trail for all action changes
CREATE TABLE IF NOT EXISTS workflow_action_history (
	id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
	action_id UUID NOT NULL REFERENCES workflow_actions(id) ON DELETE CASCADE,
	user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
	action TEXT NOT NULL,
	previous_value JSONB,
	new_value JSONB,
	comment TEXT,
	ip_address INET,
	user_agent TEXT,
	created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Workflow Transitions: Track stage transitions
CREATE TABLE IF NOT EXISTS workflow_transitions (
	id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
	workflow_instance_id UUID NOT NULL REFERENCES workflow_instances(id) ON DELETE CASCADE,
	from_stage_id UUID REFERENCES workflow_stage_instances(id) ON DELETE CASCADE,
	to_stage_id UUID REFERENCES workflow_stage_instances(id) ON DELETE CASCADE,
	triggered_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
	transition_type TEXT CHECK (transition_type IN ('advance', 'rollback', 'skip', 'restart')) DEFAULT 'advance',
	transition_data JSONB DEFAULT '{}',
	created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Workflow Notifications: Track notifications sent
CREATE TABLE IF NOT EXISTS workflow_notifications (
	id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
	workflow_instance_id UUID NOT NULL REFERENCES workflow_instances(id) ON DELETE CASCADE,
	action_id UUID REFERENCES workflow_actions(id) ON DELETE CASCADE,
	recipient_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
	notification_type TEXT CHECK (notification_type IN ('assignment', 'reminder', 'completion', 'rejection', 'escalation')) NOT NULL,
	channel TEXT CHECK (channel IN ('email', 'sms', 'in_app', 'webhook')) NOT NULL,
	sent_at TIMESTAMPTZ,
	read_at TIMESTAMPTZ,
	data JSONB DEFAULT '{}',
	created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_workflow_instances_status ON workflow_instances(status);
CREATE INDEX IF NOT EXISTS idx_workflow_instances_initiated_by ON workflow_instances(initiated_by);
CREATE INDEX IF NOT EXISTS idx_workflow_stage_instances_status ON workflow_stage_instances(status);
CREATE INDEX IF NOT EXISTS idx_workflow_actions_assigned_to ON workflow_actions(assigned_to);
CREATE INDEX IF NOT EXISTS idx_workflow_actions_status ON workflow_actions(status);
CREATE INDEX IF NOT EXISTS idx_workflow_actions_due_date ON workflow_actions(due_date);
CREATE INDEX IF NOT EXISTS idx_workflow_action_history_action_id ON workflow_action_history(action_id);
CREATE INDEX IF NOT EXISTS idx_workflow_action_history_created_at ON workflow_action_history(created_at);
CREATE INDEX IF NOT EXISTS idx_workflow_transitions_workflow_id ON workflow_transitions(workflow_instance_id);
CREATE INDEX IF NOT EXISTS idx_workflow_notifications_recipient ON workflow_notifications(recipient_id, read_at);

-- Enable Row Level Security
ALTER TABLE workflow_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE workflow_template_stages ENABLE ROW LEVEL SECURITY;
ALTER TABLE workflow_instances ENABLE ROW LEVEL SECURITY;
ALTER TABLE workflow_stage_instances ENABLE ROW LEVEL SECURITY;
ALTER TABLE workflow_actions ENABLE ROW LEVEL SECURITY;
ALTER TABLE workflow_action_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE workflow_transitions ENABLE ROW LEVEL SECURITY;
ALTER TABLE workflow_notifications ENABLE ROW LEVEL SECURITY;

-- Update timestamp triggers
CREATE TRIGGER handle_updated_at_workflow_templates
	BEFORE UPDATE ON workflow_templates
	FOR EACH ROW EXECUTE PROCEDURE moddatetime(updated_at);

CREATE TRIGGER handle_updated_at_workflow_template_stages
	BEFORE UPDATE ON workflow_template_stages
	FOR EACH ROW EXECUTE PROCEDURE moddatetime(updated_at);

CREATE TRIGGER handle_updated_at_workflow_instances
	BEFORE UPDATE ON workflow_instances
	FOR EACH ROW EXECUTE PROCEDURE moddatetime(updated_at);

CREATE TRIGGER handle_updated_at_workflow_stage_instances
	BEFORE UPDATE ON workflow_stage_instances
	FOR EACH ROW EXECUTE PROCEDURE moddatetime(updated_at);

CREATE TRIGGER handle_updated_at_workflow_actions
	BEFORE UPDATE ON workflow_actions
	FOR EACH ROW EXECUTE PROCEDURE moddatetime(updated_at);