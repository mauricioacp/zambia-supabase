-- Notification System Triggers
-- These triggers automatically create notifications based on system events

-- Trigger for new user creation (agreement activation)
CREATE OR REPLACE FUNCTION notify_user_created()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
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
$$;

-- Trigger for workflow action assignments
CREATE OR REPLACE FUNCTION notify_workflow_action_assigned()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
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
$$;

-- Trigger for workflow action completion
CREATE OR REPLACE FUNCTION notify_workflow_action_completed()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
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
$$;

-- Trigger for scheduled workshop reminders
CREATE OR REPLACE FUNCTION notify_workshop_reminder()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
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
$$;

-- Create triggers
CREATE TRIGGER notify_on_user_creation
	AFTER UPDATE ON agreements
	FOR EACH ROW EXECUTE FUNCTION notify_user_created();

CREATE TRIGGER notify_on_workflow_action_assignment
	AFTER INSERT OR UPDATE ON workflow_actions
	FOR EACH ROW EXECUTE FUNCTION notify_workflow_action_assigned();

CREATE TRIGGER notify_on_workflow_action_completion
	AFTER UPDATE ON workflow_actions
	FOR EACH ROW EXECUTE FUNCTION notify_workflow_action_completed();

CREATE TRIGGER notify_on_workshop_scheduling
	AFTER UPDATE ON scheduled_workshops
	FOR EACH ROW EXECUTE FUNCTION notify_workshop_reminder();

-- Trigger to update search index when agreements change
CREATE TRIGGER update_search_index_on_agreement_change
	AFTER INSERT OR UPDATE ON agreements
	FOR EACH ROW 
	WHEN (NEW.user_id IS NOT NULL AND NEW.status = 'active')
	EXECUTE FUNCTION update_user_search_index();

-- Trigger to update search index on user changes
CREATE TRIGGER update_search_index_on_user_change
	AFTER INSERT OR UPDATE OR DELETE ON auth.users
	FOR EACH ROW EXECUTE FUNCTION update_user_search_index();