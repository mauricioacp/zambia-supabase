-- Notification Templates Seed Data
-- These templates can be used with the create_notification_from_template function

-- User activation templates
INSERT INTO notification_templates (code, type, name, description, title_template, body_template, default_priority, default_channels, variables) VALUES
(
	'user_activated',
	'system',
	'User Account Activated',
	'Sent when a new user account is activated from an agreement',
	'¡Bienvenido a la Academia, {{user_name}}!',
	'Tu cuenta ha sido activada exitosamente. Tu email es {{email}} y tu contraseña temporal es {{password}}. Por favor, cámbiala en tu primer inicio de sesión.',
	'high',
	'{in_app, email}',
	'{"user_name": "Full name of the user", "email": "User email", "password": "Temporary password"}'::jsonb
),
(
	'manager_user_activated',
	'action_required',
	'New User in Your HQ',
	'Sent to managers when a new user is activated in their HQ',
	'Nuevo usuario activado en {{hq_name}}',
	'Se ha activado un nuevo usuario: {{user_name}} ({{role_name}}). Email: {{email}}',
	'medium',
	'{in_app}',
	'{"hq_name": "Headquarter name", "user_name": "New user name", "role_name": "User role", "email": "User email"}'::jsonb
);

-- Workflow templates
INSERT INTO notification_templates (code, type, name, description, title_template, body_template, default_priority, default_channels, variables) VALUES
(
	'workflow_action_assigned',
	'action_required',
	'Workflow Action Assigned',
	'Sent when a workflow action is assigned to a user',
	'Nueva acción asignada: {{action_type}}',
	'Se te ha asignado una acción en el flujo "{{workflow_name}}". Etapa: {{stage_name}}. {{due_text}}',
	'medium',
	'{in_app, email}',
	'{"action_type": "Type of action", "workflow_name": "Workflow name", "stage_name": "Stage name", "due_text": "Due date text"}'::jsonb
),
(
	'workflow_completed',
	'system',
	'Workflow Completed',
	'Sent when a workflow is completed',
	'Flujo completado: {{workflow_name}}',
	'El flujo "{{workflow_name}}" ha sido completado exitosamente. Duración total: {{duration}}',
	'low',
	'{in_app}',
	'{"workflow_name": "Workflow name", "duration": "Total duration"}'::jsonb
),
(
	'workflow_action_overdue',
	'alert',
	'Workflow Action Overdue',
	'Sent when a workflow action is overdue',
	'Acción vencida: {{action_type}}',
	'La acción "{{action_type}}" en el flujo "{{workflow_name}}" está vencida desde {{overdue_date}}. Por favor, complétala lo antes posible.',
	'urgent',
	'{in_app, email}',
	'{"action_type": "Type of action", "workflow_name": "Workflow name", "overdue_date": "Date when it became overdue"}'::jsonb
);

-- Workshop templates
INSERT INTO notification_templates (code, type, name, description, title_template, body_template, default_priority, default_channels, variables) VALUES
(
	'workshop_reminder_facilitator',
	'reminder',
	'Workshop Reminder for Facilitator',
	'Sent to facilitators before a workshop',
	'Recordatorio: Taller {{workshop_name}}',
	'Tienes un taller programado para {{date}} a las {{time}}. Ubicación: {{location}}. Participantes confirmados: {{participant_count}}',
	'high',
	'{in_app, email}',
	'{"workshop_name": "Workshop name", "date": "Workshop date", "time": "Workshop time", "location": "Workshop location", "participant_count": "Number of participants"}'::jsonb
),
(
	'workshop_cancelled',
	'alert',
	'Workshop Cancelled',
	'Sent when a workshop is cancelled',
	'Taller cancelado: {{workshop_name}}',
	'El taller "{{workshop_name}}" programado para {{date}} ha sido cancelado. Motivo: {{reason}}',
	'high',
	'{in_app, email}',
	'{"workshop_name": "Workshop name", "date": "Original date", "reason": "Cancellation reason"}'::jsonb
),
(
	'workshop_attendance_confirmed',
	'system',
	'Workshop Attendance Confirmed',
	'Sent when attendance is confirmed for a workshop',
	'Asistencia confirmada',
	'Tu asistencia al taller "{{workshop_name}}" ha sido confirmada. Te esperamos el {{date}} a las {{time}}.',
	'medium',
	'{in_app}',
	'{"workshop_name": "Workshop name", "date": "Workshop date", "time": "Workshop time"}'::jsonb
);

-- Achievement templates
INSERT INTO notification_templates (code, type, name, description, title_template, body_template, default_priority, default_channels, variables) VALUES
(
	'milestone_reached',
	'achievement',
	'Milestone Reached',
	'Sent when a user reaches a milestone',
	'¡Felicitaciones! Has alcanzado un hito',
	'Has completado {{milestone_name}}. {{achievement_description}}',
	'medium',
	'{in_app}',
	'{"milestone_name": "Name of the milestone", "achievement_description": "Description of the achievement"}'::jsonb
),
(
	'first_workshop_completed',
	'achievement',
	'First Workshop Completed',
	'Sent when a user completes their first workshop',
	'¡Primer taller completado!',
	'Felicitaciones {{user_name}}, has completado tu primer taller: "{{workshop_name}}". ¡Sigue así!',
	'low',
	'{in_app}',
	'{"user_name": "User name", "workshop_name": "Workshop name"}'::jsonb
);

-- System maintenance templates
INSERT INTO notification_templates (code, type, name, description, title_template, body_template, default_priority, default_channels, variables) VALUES
(
	'system_maintenance',
	'system',
	'System Maintenance',
	'Sent before system maintenance',
	'Mantenimiento programado',
	'El sistema estará en mantenimiento el {{date}} de {{start_time}} a {{end_time}}. Por favor, guarda tu trabajo antes de este horario.',
	'high',
	'{in_app, email}',
	'{"date": "Maintenance date", "start_time": "Start time", "end_time": "End time"}'::jsonb
),
(
	'password_reset',
	'system',
	'Password Reset',
	'Sent when a password is reset',
	'Contraseña restablecida',
	'Tu contraseña ha sido restablecida exitosamente. Tu nueva contraseña temporal es: {{password}}. Por favor, cámbiala al iniciar sesión.',
	'urgent',
	'{in_app, email}',
	'{"password": "New temporary password"}'::jsonb
),
(
	'account_deactivated',
	'alert',
	'Account Deactivated',
	'Sent when an account is deactivated',
	'Cuenta desactivada',
	'Tu cuenta ha sido desactivada. Si crees que esto es un error, por favor contacta al administrador.',
	'urgent',
	'{email}',
	'{}'::jsonb
);

-- Direct message template
INSERT INTO notification_templates (code, type, name, description, title_template, body_template, default_priority, default_channels, variables) VALUES
(
	'direct_message',
	'direct_message',
	'Direct Message',
	'Template for user-to-user messages',
	'Mensaje de {{sender_name}}',
	'{{message_content}}',
	'medium',
	'{in_app}',
	'{"sender_name": "Name of the sender", "message_content": "Message content"}'::jsonb
);

-- Role-based announcement template
INSERT INTO notification_templates (code, type, name, description, title_template, body_template, default_priority, default_channels, variables) VALUES
(
	'role_announcement',
	'role_based',
	'Role-Based Announcement',
	'Announcement for specific roles',
	'{{announcement_title}}',
	'{{announcement_body}}',
	'medium',
	'{in_app}',
	'{"announcement_title": "Title of the announcement", "announcement_body": "Body of the announcement"}'::jsonb
);