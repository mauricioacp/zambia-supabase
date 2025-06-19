create extension if not exists "moddatetime" with schema "extensions";


create type "public"."collaborator_status" as enum ('active', 'inactive', 'standby');

create type "public"."notification_channel" as enum ('in_app', 'email', 'sms', 'push');

create type "public"."notification_priority" as enum ('low', 'medium', 'high', 'urgent');

create type "public"."notification_type" as enum ('system', 'direct_message', 'action_required', 'reminder', 'alert', 'achievement', 'role_based');

create sequence "public"."audit_log_id_seq";

create sequence "public"."event_types_id_seq";

create sequence "public"."master_workshop_types_id_seq";

create table "public"."agreements" (
    "id" uuid not null default uuid_generate_v4(),
    "user_id" uuid,
    "headquarter_id" uuid not null,
    "season_id" uuid not null,
    "role_id" uuid not null,
    "status" text default 'prospect'::text,
    "email" text not null,
    "document_number" text,
    "phone" text,
    "created_at" timestamp with time zone default now(),
    "updated_at" timestamp with time zone default now(),
    "name" text,
    "last_name" text,
    "address" text,
    "activation_date" timestamp with time zone,
    "volunteering_agreement" boolean default false,
    "ethical_document_agreement" boolean default false,
    "mailing_agreement" boolean default false,
    "age_verification" boolean default false,
    "signature_data" text,
    "birth_date" date,
    "gender" text default 'unknown'::text,
    "fts_name_lastname" tsvector
);


alter table "public"."agreements" enable row level security;

create table "public"."audit_log" (
    "id" bigint not null default nextval('audit_log_id_seq'::regclass),
    "table_name" text,
    "action" text,
    "record_id" uuid,
    "changed_by" uuid,
    "user_name" text,
    "changed_at" timestamp with time zone default now(),
    "diff" jsonb
);


alter table "public"."audit_log" enable row level security;

create table "public"."collaborators" (
    "id" uuid not null default uuid_generate_v4(),
    "user_id" uuid not null,
    "role_id" uuid not null,
    "headquarter_id" uuid not null,
    "status" collaborator_status default 'inactive'::collaborator_status,
    "start_date" date,
    "end_date" date
);


alter table "public"."collaborators" enable row level security;

create table "public"."companion_student_map" (
    "companion_id" uuid not null,
    "student_id" uuid not null,
    "season_id" uuid not null,
    "headquarter_id" uuid not null,
    "created_at" timestamp with time zone not null default now(),
    "updated_at" timestamp with time zone
);


alter table "public"."companion_student_map" enable row level security;

create table "public"."countries" (
    "id" uuid not null default uuid_generate_v4(),
    "name" text not null,
    "code" text not null,
    "status" text default 'active'::text,
    "created_at" timestamp with time zone default now(),
    "updated_at" timestamp with time zone default now()
);


alter table "public"."countries" enable row level security;

create table "public"."event_types" (
    "id" integer not null default nextval('event_types_id_seq'::regclass),
    "name" text not null,
    "description" text,
    "title" text not null,
    "created_at" timestamp with time zone not null default now(),
    "updated_at" timestamp with time zone
);


alter table "public"."event_types" enable row level security;

create table "public"."events" (
    "id" uuid not null default uuid_generate_v4(),
    "title" text not null,
    "description" text,
    "headquarter_id" uuid,
    "season_id" uuid,
    "created_at" timestamp with time zone default now(),
    "updated_at" timestamp with time zone default now(),
    "start_datetime" timestamp with time zone,
    "end_datetime" timestamp with time zone,
    "data" jsonb,
    "status" text default 'draft'::text,
    "event_type_id" integer
);


alter table "public"."events" enable row level security;

create table "public"."facilitator_workshop_map" (
    "facilitator_id" uuid not null,
    "workshop_id" uuid not null,
    "headquarter_id" uuid not null,
    "season_id" uuid not null,
    "created_at" timestamp with time zone not null default now(),
    "updated_at" timestamp with time zone
);


alter table "public"."facilitator_workshop_map" enable row level security;

create table "public"."headquarters" (
    "id" uuid not null default uuid_generate_v4(),
    "name" text not null,
    "country_id" uuid,
    "address" text,
    "contact_info" jsonb default '{}'::jsonb,
    "status" text default 'active'::text,
    "created_at" timestamp with time zone default now(),
    "updated_at" timestamp with time zone default now()
);


alter table "public"."headquarters" enable row level security;

create table "public"."master_workshop_types" (
    "id" integer not null default nextval('master_workshop_types_id_seq'::regclass),
    "master_name" text not null,
    "master_description" text,
    "created_at" timestamp with time zone not null default now(),
    "updated_at" timestamp with time zone
);


alter table "public"."master_workshop_types" enable row level security;

create table "public"."notification_deliveries" (
    "id" uuid not null default gen_random_uuid(),
    "notification_id" uuid not null,
    "channel" notification_channel not null,
    "status" text not null default 'pending'::text,
    "sent_at" timestamp with time zone,
    "delivered_at" timestamp with time zone,
    "failed_at" timestamp with time zone,
    "error_message" text,
    "metadata" jsonb default '{}'::jsonb,
    "created_at" timestamp with time zone default now()
);


alter table "public"."notification_deliveries" enable row level security;

create table "public"."notification_preferences" (
    "id" uuid not null default gen_random_uuid(),
    "user_id" uuid not null,
    "enabled" boolean default true,
    "quiet_hours_start" time without time zone,
    "quiet_hours_end" time without time zone,
    "timezone" text default 'UTC'::text,
    "channel_preferences" jsonb default '{}'::jsonb,
    "blocked_senders" uuid[] default '{}'::uuid[],
    "blocked_categories" text[] default '{}'::text[],
    "priority_threshold" notification_priority default 'low'::notification_priority,
    "created_at" timestamp with time zone default now(),
    "updated_at" timestamp with time zone default now()
);


alter table "public"."notification_preferences" enable row level security;

create table "public"."notification_templates" (
    "id" uuid not null default gen_random_uuid(),
    "code" text not null,
    "type" notification_type not null,
    "name" text not null,
    "description" text,
    "title_template" text not null,
    "body_template" text not null,
    "default_priority" notification_priority default 'medium'::notification_priority,
    "default_channels" notification_channel[] default '{in_app}'::notification_channel[],
    "variables" jsonb default '{}'::jsonb,
    "metadata" jsonb default '{}'::jsonb,
    "is_active" boolean default true,
    "created_at" timestamp with time zone default now(),
    "updated_at" timestamp with time zone default now()
);


alter table "public"."notification_templates" enable row level security;

create table "public"."notifications" (
    "id" uuid not null default gen_random_uuid(),
    "type" notification_type not null,
    "priority" notification_priority default 'medium'::notification_priority,
    "sender_id" uuid,
    "sender_type" text default 'user'::text,
    "recipient_id" uuid,
    "recipient_role_code" text,
    "recipient_role_level" integer,
    "title" text not null,
    "body" text not null,
    "data" jsonb default '{}'::jsonb,
    "category" text,
    "tags" text[] default '{}'::text[],
    "expires_at" timestamp with time zone,
    "is_read" boolean default false,
    "read_at" timestamp with time zone,
    "is_archived" boolean default false,
    "archived_at" timestamp with time zone,
    "related_entity_type" text,
    "related_entity_id" uuid,
    "action_url" text,
    "created_at" timestamp with time zone default now(),
    "updated_at" timestamp with time zone default now()
);


alter table "public"."notifications" enable row level security;

create table "public"."processes" (
    "id" uuid not null default uuid_generate_v4(),
    "created_at" timestamp with time zone default now(),
    "updated_at" timestamp with time zone default now(),
    "name" character varying(50) not null,
    "description" text,
    "type" text,
    "status" text default 'active'::text,
    "version" text,
    "content" jsonb,
    "required_approvals" uuid[]
);


alter table "public"."processes" enable row level security;

create table "public"."roles" (
    "id" uuid not null default uuid_generate_v4(),
    "code" text not null,
    "name" text not null,
    "description" text,
    "status" text default 'active'::text,
    "level" integer not null,
    "created_at" timestamp with time zone default now(),
    "updated_at" timestamp with time zone default now(),
    "permissions" jsonb default '{}'::jsonb
);


alter table "public"."roles" enable row level security;

create table "public"."scheduled_workshops" (
    "id" uuid not null default uuid_generate_v4(),
    "master_workshop_type_id" integer not null,
    "headquarter_id" uuid not null,
    "season_id" uuid not null,
    "facilitator_id" uuid not null,
    "local_name" text not null,
    "start_datetime" timestamp with time zone not null,
    "end_datetime" timestamp with time zone not null,
    "location_details" text,
    "status" text not null default 'scheduled'::text,
    "created_at" timestamp with time zone not null default now(),
    "updated_at" timestamp with time zone
);


alter table "public"."scheduled_workshops" enable row level security;

create table "public"."seasons" (
    "id" uuid not null default uuid_generate_v4(),
    "name" text not null,
    "headquarter_id" uuid not null,
    "manager_id" uuid,
    "start_date" date,
    "end_date" date,
    "status" text default 'inactive'::text,
    "created_at" timestamp with time zone default now(),
    "updated_at" timestamp with time zone default now()
);


alter table "public"."seasons" enable row level security;

create table "public"."strapi_migrations" (
    "id" bigint generated always as identity not null,
    "migration_timestamp" timestamp with time zone not null default now(),
    "last_migrated_at" timestamp with time zone not null,
    "status" text not null,
    "records_processed" integer not null default 0,
    "error_message" text,
    "created_at" timestamp with time zone not null default now()
);


alter table "public"."strapi_migrations" enable row level security;

create table "public"."student_attendance" (
    "id" uuid not null default uuid_generate_v4(),
    "scheduled_workshop_id" uuid not null,
    "student_id" uuid not null,
    "attendance_status" text not null,
    "attendance_timestamp" timestamp with time zone not null default now(),
    "notes" text,
    "created_at" timestamp with time zone not null default now(),
    "updated_at" timestamp with time zone
);


alter table "public"."student_attendance" enable row level security;

create table "public"."students" (
    "id" uuid not null default uuid_generate_v4(),
    "user_id" uuid not null,
    "headquarter_id" uuid not null,
    "season_id" uuid not null,
    "enrollment_date" date not null,
    "status" text default 'prospect'::text,
    "program_progress_comments" jsonb
);


alter table "public"."students" enable row level security;

create table "public"."user_search_index" (
    "user_id" uuid not null,
    "full_name" text not null,
    "email" text not null,
    "role_code" text not null,
    "role_name" text not null,
    "role_level" integer not null,
    "headquarter_name" text,
    "search_vector" tsvector generated always as ((((setweight(to_tsvector('spanish'::regconfig, COALESCE(full_name, ''::text)), 'A'::"char") || setweight(to_tsvector('spanish'::regconfig, COALESCE(email, ''::text)), 'B'::"char")) || setweight(to_tsvector('spanish'::regconfig, COALESCE(role_name, ''::text)), 'C'::"char")) || setweight(to_tsvector('spanish'::regconfig, COALESCE(headquarter_name, ''::text)), 'D'::"char"))) stored,
    "is_active" boolean default true,
    "last_seen" timestamp with time zone,
    "created_at" timestamp with time zone default now(),
    "updated_at" timestamp with time zone default now()
);


alter table "public"."user_search_index" enable row level security;

create table "public"."workflow_action_history" (
    "id" uuid not null default gen_random_uuid(),
    "action_id" uuid not null,
    "user_id" uuid,
    "action" text not null,
    "previous_value" jsonb,
    "new_value" jsonb,
    "comment" text,
    "ip_address" inet,
    "user_agent" text,
    "created_at" timestamp with time zone default now()
);


alter table "public"."workflow_action_history" enable row level security;

create table "public"."workflow_action_role_assignments" (
    "id" uuid not null default gen_random_uuid(),
    "template_stage_id" uuid not null,
    "action_type" text not null,
    "assigned_role_code" text,
    "min_role_level" integer default 20,
    "assignment_rule" jsonb default '{}'::jsonb,
    "created_at" timestamp with time zone default now(),
    "updated_at" timestamp with time zone default now()
);


alter table "public"."workflow_action_role_assignments" enable row level security;

create table "public"."workflow_actions" (
    "id" uuid not null default gen_random_uuid(),
    "stage_instance_id" uuid not null,
    "action_type" text not null,
    "assigned_to" uuid,
    "assigned_by" uuid,
    "status" text default 'pending'::text,
    "due_date" timestamp with time zone,
    "priority" text default 'medium'::text,
    "data" jsonb default '{}'::jsonb,
    "result" jsonb default '{}'::jsonb,
    "completed_at" timestamp with time zone,
    "completed_by" uuid,
    "rejected_at" timestamp with time zone,
    "rejected_by" uuid,
    "rejection_reason" text,
    "created_at" timestamp with time zone default now(),
    "updated_at" timestamp with time zone default now()
);


alter table "public"."workflow_actions" enable row level security;

create table "public"."workflow_instances" (
    "id" uuid not null default gen_random_uuid(),
    "template_id" uuid not null,
    "current_stage_id" uuid,
    "status" text default 'draft'::text,
    "initiated_by" uuid,
    "data" jsonb default '{}'::jsonb,
    "completed_at" timestamp with time zone,
    "cancelled_at" timestamp with time zone,
    "created_at" timestamp with time zone default now(),
    "updated_at" timestamp with time zone default now()
);


alter table "public"."workflow_instances" enable row level security;

create table "public"."workflow_notifications" (
    "id" uuid not null default gen_random_uuid(),
    "workflow_instance_id" uuid not null,
    "action_id" uuid,
    "recipient_id" uuid,
    "notification_type" text not null,
    "channel" text not null,
    "sent_at" timestamp with time zone,
    "read_at" timestamp with time zone,
    "data" jsonb default '{}'::jsonb,
    "created_at" timestamp with time zone default now()
);


alter table "public"."workflow_notifications" enable row level security;

create table "public"."workflow_stage_instances" (
    "id" uuid not null default gen_random_uuid(),
    "workflow_instance_id" uuid not null,
    "template_stage_id" uuid not null,
    "status" text default 'pending'::text,
    "started_at" timestamp with time zone,
    "completed_at" timestamp with time zone,
    "completed_actions" integer default 0,
    "created_at" timestamp with time zone default now(),
    "updated_at" timestamp with time zone default now()
);


alter table "public"."workflow_stage_instances" enable row level security;

create table "public"."workflow_template_permissions" (
    "id" uuid not null default gen_random_uuid(),
    "template_id" uuid not null,
    "min_role_level" integer not null default 50,
    "allowed_roles" text[] default '{}'::text[],
    "created_at" timestamp with time zone default now(),
    "updated_at" timestamp with time zone default now()
);


alter table "public"."workflow_template_permissions" enable row level security;

create table "public"."workflow_template_stages" (
    "id" uuid not null default gen_random_uuid(),
    "template_id" uuid not null,
    "stage_number" integer not null,
    "name" text not null,
    "description" text,
    "stage_type" text default 'sequential'::text,
    "required_actions" integer default 1,
    "approval_threshold" integer default 1,
    "metadata" jsonb default '{}'::jsonb,
    "created_at" timestamp with time zone default now(),
    "updated_at" timestamp with time zone default now()
);


alter table "public"."workflow_template_stages" enable row level security;

create table "public"."workflow_templates" (
    "id" uuid not null default gen_random_uuid(),
    "name" text not null,
    "description" text,
    "created_by" uuid,
    "is_active" boolean default true,
    "metadata" jsonb default '{}'::jsonb,
    "created_at" timestamp with time zone default now(),
    "updated_at" timestamp with time zone default now()
);


alter table "public"."workflow_templates" enable row level security;

create table "public"."workflow_transitions" (
    "id" uuid not null default gen_random_uuid(),
    "workflow_instance_id" uuid not null,
    "from_stage_id" uuid,
    "to_stage_id" uuid,
    "triggered_by" uuid,
    "transition_type" text default 'advance'::text,
    "transition_data" jsonb default '{}'::jsonb,
    "created_at" timestamp with time zone default now()
);


alter table "public"."workflow_transitions" enable row level security;

alter sequence "public"."audit_log_id_seq" owned by "public"."audit_log"."id";

alter sequence "public"."event_types_id_seq" owned by "public"."event_types"."id";

alter sequence "public"."master_workshop_types_id_seq" owned by "public"."master_workshop_types"."id";

CREATE UNIQUE INDEX agreements_pkey ON public.agreements USING btree (id);

CREATE UNIQUE INDEX agreements_user_id_season_id_key ON public.agreements USING btree (user_id, season_id);

CREATE UNIQUE INDEX audit_log_pkey ON public.audit_log USING btree (id);

CREATE UNIQUE INDEX collaborators_pkey ON public.collaborators USING btree (id);

CREATE UNIQUE INDEX collaborators_user_id_key ON public.collaborators USING btree (user_id);

CREATE UNIQUE INDEX companion_student_map_pkey ON public.companion_student_map USING btree (companion_id, student_id, season_id);

CREATE UNIQUE INDEX countries_code_key ON public.countries USING btree (code);

CREATE UNIQUE INDEX countries_pkey ON public.countries USING btree (id);

CREATE UNIQUE INDEX event_types_name_key ON public.event_types USING btree (name);

CREATE UNIQUE INDEX event_types_pkey ON public.event_types USING btree (id);

CREATE UNIQUE INDEX events_pkey ON public.events USING btree (id);

CREATE UNIQUE INDEX facilitator_workshop_map_pkey ON public.facilitator_workshop_map USING btree (facilitator_id, workshop_id, season_id, headquarter_id);

CREATE UNIQUE INDEX headquarters_pkey ON public.headquarters USING btree (id);

CREATE INDEX idx_agreements_email ON public.agreements USING btree (email);

CREATE INDEX idx_agreements_fts_name_lastname ON public.agreements USING gin (fts_name_lastname);

CREATE INDEX idx_agreements_headquarter_id ON public.agreements USING btree (headquarter_id);

CREATE INDEX idx_agreements_last_name ON public.agreements USING btree (last_name);

CREATE INDEX idx_agreements_name ON public.agreements USING btree (name);

CREATE INDEX idx_agreements_role_id ON public.agreements USING btree (role_id);

CREATE INDEX idx_agreements_season_id ON public.agreements USING btree (season_id);

CREATE INDEX idx_agreements_user_id ON public.agreements USING btree (user_id);

CREATE INDEX idx_collaborators_headquarter_id ON public.collaborators USING btree (headquarter_id);

CREATE INDEX idx_collaborators_role_id ON public.collaborators USING btree (role_id);

CREATE INDEX idx_collaborators_user_id ON public.collaborators USING btree (user_id);

CREATE INDEX idx_companion_student_map_agreement_id ON public.companion_student_map USING btree (headquarter_id, season_id);

CREATE INDEX idx_companion_student_map_companion_id ON public.companion_student_map USING btree (companion_id);

CREATE INDEX idx_companion_student_map_headquarter_id ON public.companion_student_map USING btree (headquarter_id);

CREATE INDEX idx_companion_student_map_season_id ON public.companion_student_map USING btree (season_id);

CREATE INDEX idx_companion_student_map_student_id ON public.companion_student_map USING btree (student_id);

CREATE INDEX idx_countries_code ON public.countries USING btree (code);

CREATE INDEX idx_event_types_name ON public.event_types USING btree (name);

CREATE INDEX idx_events_event_type_id ON public.events USING btree (event_type_id);

CREATE INDEX idx_events_headquarter_id ON public.events USING btree (headquarter_id);

CREATE INDEX idx_events_season_id ON public.events USING btree (season_id);

CREATE INDEX idx_events_start_datetime ON public.events USING btree (start_datetime);

CREATE INDEX idx_events_status ON public.events USING btree (status);

CREATE INDEX idx_facilitator_workshop_map_facilitator_id ON public.facilitator_workshop_map USING btree (facilitator_id);

CREATE INDEX idx_facilitator_workshop_map_facilitator_season ON public.facilitator_workshop_map USING btree (facilitator_id, season_id);

CREATE INDEX idx_facilitator_workshop_map_facilitator_workshop ON public.facilitator_workshop_map USING btree (facilitator_id, workshop_id);

CREATE INDEX idx_facilitator_workshop_map_headquarter_facilitator ON public.facilitator_workshop_map USING btree (headquarter_id, facilitator_id);

CREATE INDEX idx_facilitator_workshop_map_headquarter_id ON public.facilitator_workshop_map USING btree (headquarter_id);

CREATE INDEX idx_facilitator_workshop_map_headquarter_season ON public.facilitator_workshop_map USING btree (headquarter_id, season_id);

CREATE INDEX idx_facilitator_workshop_map_headquarter_workshop ON public.facilitator_workshop_map USING btree (headquarter_id, workshop_id);

CREATE INDEX idx_facilitator_workshop_map_season_id ON public.facilitator_workshop_map USING btree (season_id);

CREATE INDEX idx_facilitator_workshop_map_workshop_id ON public.facilitator_workshop_map USING btree (workshop_id);

CREATE INDEX idx_facilitator_workshop_map_workshop_season ON public.facilitator_workshop_map USING btree (workshop_id, season_id);

CREATE INDEX idx_headquarters_country_id ON public.headquarters USING btree (country_id);

CREATE INDEX idx_notification_templates_code ON public.notification_templates USING btree (code) WHERE is_active;

CREATE INDEX idx_notifications_created ON public.notifications USING btree (created_at DESC);

CREATE INDEX idx_notifications_expires ON public.notifications USING btree (expires_at) WHERE (expires_at IS NOT NULL);

CREATE INDEX idx_notifications_priority ON public.notifications USING btree (priority);

CREATE INDEX idx_notifications_recipient ON public.notifications USING btree (recipient_id) WHERE (NOT is_archived);

CREATE INDEX idx_notifications_related ON public.notifications USING btree (related_entity_type, related_entity_id);

CREATE INDEX idx_notifications_type ON public.notifications USING btree (type);

CREATE INDEX idx_notifications_unread ON public.notifications USING btree (recipient_id) WHERE ((NOT is_read) AND (NOT is_archived));

CREATE INDEX idx_processes_status ON public.processes USING btree (status);

CREATE INDEX idx_roles_code ON public.roles USING btree (code);

CREATE INDEX idx_scheduled_workshops_facilitator ON public.scheduled_workshops USING btree (facilitator_id);

CREATE INDEX idx_scheduled_workshops_hq ON public.scheduled_workshops USING btree (headquarter_id);

CREATE INDEX idx_scheduled_workshops_master_type ON public.scheduled_workshops USING btree (master_workshop_type_id);

CREATE INDEX idx_scheduled_workshops_season ON public.scheduled_workshops USING btree (season_id);

CREATE INDEX idx_scheduled_workshops_start_time ON public.scheduled_workshops USING btree (start_datetime);

CREATE INDEX idx_seasons_headquarter_id ON public.seasons USING btree (headquarter_id);

CREATE INDEX idx_seasons_manager_id ON public.seasons USING btree (manager_id);

CREATE INDEX idx_seasons_start_date ON public.seasons USING btree (start_date);

CREATE INDEX idx_seasons_status ON public.seasons USING btree (status);

CREATE INDEX idx_student_attendance_student ON public.student_attendance USING btree (student_id);

CREATE INDEX idx_student_attendance_workshop ON public.student_attendance USING btree (scheduled_workshop_id);

CREATE INDEX idx_students_headquarter_id ON public.students USING btree (headquarter_id);

CREATE INDEX idx_students_season_id ON public.students USING btree (season_id);

CREATE INDEX idx_students_user_id ON public.students USING btree (user_id);

CREATE INDEX idx_user_search_role ON public.user_search_index USING btree (role_code, role_level);

CREATE INDEX idx_user_search_vector ON public.user_search_index USING gin (search_vector);

CREATE INDEX idx_workflow_action_history_action_id ON public.workflow_action_history USING btree (action_id);

CREATE INDEX idx_workflow_action_history_created_at ON public.workflow_action_history USING btree (created_at);

CREATE INDEX idx_workflow_action_role_assignments_stage ON public.workflow_action_role_assignments USING btree (template_stage_id);

CREATE INDEX idx_workflow_actions_assigned_to ON public.workflow_actions USING btree (assigned_to);

CREATE INDEX idx_workflow_actions_due_date ON public.workflow_actions USING btree (due_date);

CREATE INDEX idx_workflow_actions_status ON public.workflow_actions USING btree (status);

CREATE INDEX idx_workflow_instances_initiated_by ON public.workflow_instances USING btree (initiated_by);

CREATE INDEX idx_workflow_instances_status ON public.workflow_instances USING btree (status);

CREATE INDEX idx_workflow_notifications_recipient ON public.workflow_notifications USING btree (recipient_id, read_at);

CREATE INDEX idx_workflow_stage_instances_status ON public.workflow_stage_instances USING btree (status);

CREATE INDEX idx_workflow_template_permissions_template ON public.workflow_template_permissions USING btree (template_id);

CREATE INDEX idx_workflow_transitions_workflow_id ON public.workflow_transitions USING btree (workflow_instance_id);

CREATE UNIQUE INDEX master_workshop_types_master_name_key ON public.master_workshop_types USING btree (master_name);

CREATE UNIQUE INDEX master_workshop_types_pkey ON public.master_workshop_types USING btree (id);

CREATE UNIQUE INDEX notification_deliveries_notification_id_channel_key ON public.notification_deliveries USING btree (notification_id, channel);

CREATE UNIQUE INDEX notification_deliveries_pkey ON public.notification_deliveries USING btree (id);

CREATE UNIQUE INDEX notification_preferences_pkey ON public.notification_preferences USING btree (id);

CREATE UNIQUE INDEX notification_preferences_user_id_key ON public.notification_preferences USING btree (user_id);

CREATE UNIQUE INDEX notification_templates_code_key ON public.notification_templates USING btree (code);

CREATE UNIQUE INDEX notification_templates_pkey ON public.notification_templates USING btree (id);

CREATE UNIQUE INDEX notifications_pkey ON public.notifications USING btree (id);

CREATE UNIQUE INDEX processes_pkey ON public.processes USING btree (id);

CREATE UNIQUE INDEX roles_code_key ON public.roles USING btree (code);

CREATE UNIQUE INDEX roles_pkey ON public.roles USING btree (id);

CREATE UNIQUE INDEX scheduled_workshops_pkey ON public.scheduled_workshops USING btree (id);

CREATE UNIQUE INDEX seasons_pkey ON public.seasons USING btree (id);

CREATE UNIQUE INDEX strapi_migrations_pkey ON public.strapi_migrations USING btree (id);

CREATE UNIQUE INDEX student_attendance_pkey ON public.student_attendance USING btree (id);

CREATE UNIQUE INDEX students_pkey ON public.students USING btree (id);

CREATE UNIQUE INDEX students_user_id_key ON public.students USING btree (user_id);

CREATE UNIQUE INDEX unique_season_name_per_hq ON public.seasons USING btree (name, headquarter_id);

CREATE UNIQUE INDEX uq_local_name_hq_season ON public.scheduled_workshops USING btree (local_name, headquarter_id, season_id);

CREATE UNIQUE INDEX uq_student_workshop_attendance ON public.student_attendance USING btree (scheduled_workshop_id, student_id);

CREATE UNIQUE INDEX user_search_index_pkey ON public.user_search_index USING btree (user_id);

CREATE UNIQUE INDEX workflow_action_history_pkey ON public.workflow_action_history USING btree (id);

CREATE UNIQUE INDEX workflow_action_role_assignme_template_stage_id_action_type_key ON public.workflow_action_role_assignments USING btree (template_stage_id, action_type);

CREATE UNIQUE INDEX workflow_action_role_assignments_pkey ON public.workflow_action_role_assignments USING btree (id);

CREATE UNIQUE INDEX workflow_actions_pkey ON public.workflow_actions USING btree (id);

CREATE UNIQUE INDEX workflow_instances_pkey ON public.workflow_instances USING btree (id);

CREATE UNIQUE INDEX workflow_notifications_pkey ON public.workflow_notifications USING btree (id);

CREATE UNIQUE INDEX workflow_stage_instances_pkey ON public.workflow_stage_instances USING btree (id);

CREATE UNIQUE INDEX workflow_stage_instances_workflow_instance_id_template_stag_key ON public.workflow_stage_instances USING btree (workflow_instance_id, template_stage_id);

CREATE UNIQUE INDEX workflow_template_permissions_pkey ON public.workflow_template_permissions USING btree (id);

CREATE UNIQUE INDEX workflow_template_permissions_template_id_key ON public.workflow_template_permissions USING btree (template_id);

CREATE UNIQUE INDEX workflow_template_stages_pkey ON public.workflow_template_stages USING btree (id);

CREATE UNIQUE INDEX workflow_template_stages_template_id_stage_number_key ON public.workflow_template_stages USING btree (template_id, stage_number);

CREATE UNIQUE INDEX workflow_templates_pkey ON public.workflow_templates USING btree (id);

CREATE UNIQUE INDEX workflow_transitions_pkey ON public.workflow_transitions USING btree (id);

alter table "public"."agreements" add constraint "agreements_pkey" PRIMARY KEY using index "agreements_pkey";

alter table "public"."audit_log" add constraint "audit_log_pkey" PRIMARY KEY using index "audit_log_pkey";

alter table "public"."collaborators" add constraint "collaborators_pkey" PRIMARY KEY using index "collaborators_pkey";

alter table "public"."companion_student_map" add constraint "companion_student_map_pkey" PRIMARY KEY using index "companion_student_map_pkey";

alter table "public"."countries" add constraint "countries_pkey" PRIMARY KEY using index "countries_pkey";

alter table "public"."event_types" add constraint "event_types_pkey" PRIMARY KEY using index "event_types_pkey";

alter table "public"."events" add constraint "events_pkey" PRIMARY KEY using index "events_pkey";

alter table "public"."facilitator_workshop_map" add constraint "facilitator_workshop_map_pkey" PRIMARY KEY using index "facilitator_workshop_map_pkey";

alter table "public"."headquarters" add constraint "headquarters_pkey" PRIMARY KEY using index "headquarters_pkey";

alter table "public"."master_workshop_types" add constraint "master_workshop_types_pkey" PRIMARY KEY using index "master_workshop_types_pkey";

alter table "public"."notification_deliveries" add constraint "notification_deliveries_pkey" PRIMARY KEY using index "notification_deliveries_pkey";

alter table "public"."notification_preferences" add constraint "notification_preferences_pkey" PRIMARY KEY using index "notification_preferences_pkey";

alter table "public"."notification_templates" add constraint "notification_templates_pkey" PRIMARY KEY using index "notification_templates_pkey";

alter table "public"."notifications" add constraint "notifications_pkey" PRIMARY KEY using index "notifications_pkey";

alter table "public"."processes" add constraint "processes_pkey" PRIMARY KEY using index "processes_pkey";

alter table "public"."roles" add constraint "roles_pkey" PRIMARY KEY using index "roles_pkey";

alter table "public"."scheduled_workshops" add constraint "scheduled_workshops_pkey" PRIMARY KEY using index "scheduled_workshops_pkey";

alter table "public"."seasons" add constraint "seasons_pkey" PRIMARY KEY using index "seasons_pkey";

alter table "public"."strapi_migrations" add constraint "strapi_migrations_pkey" PRIMARY KEY using index "strapi_migrations_pkey";

alter table "public"."student_attendance" add constraint "student_attendance_pkey" PRIMARY KEY using index "student_attendance_pkey";

alter table "public"."students" add constraint "students_pkey" PRIMARY KEY using index "students_pkey";

alter table "public"."user_search_index" add constraint "user_search_index_pkey" PRIMARY KEY using index "user_search_index_pkey";

alter table "public"."workflow_action_history" add constraint "workflow_action_history_pkey" PRIMARY KEY using index "workflow_action_history_pkey";

alter table "public"."workflow_action_role_assignments" add constraint "workflow_action_role_assignments_pkey" PRIMARY KEY using index "workflow_action_role_assignments_pkey";

alter table "public"."workflow_actions" add constraint "workflow_actions_pkey" PRIMARY KEY using index "workflow_actions_pkey";

alter table "public"."workflow_instances" add constraint "workflow_instances_pkey" PRIMARY KEY using index "workflow_instances_pkey";

alter table "public"."workflow_notifications" add constraint "workflow_notifications_pkey" PRIMARY KEY using index "workflow_notifications_pkey";

alter table "public"."workflow_stage_instances" add constraint "workflow_stage_instances_pkey" PRIMARY KEY using index "workflow_stage_instances_pkey";

alter table "public"."workflow_template_permissions" add constraint "workflow_template_permissions_pkey" PRIMARY KEY using index "workflow_template_permissions_pkey";

alter table "public"."workflow_template_stages" add constraint "workflow_template_stages_pkey" PRIMARY KEY using index "workflow_template_stages_pkey";

alter table "public"."workflow_templates" add constraint "workflow_templates_pkey" PRIMARY KEY using index "workflow_templates_pkey";

alter table "public"."workflow_transitions" add constraint "workflow_transitions_pkey" PRIMARY KEY using index "workflow_transitions_pkey";

alter table "public"."agreements" add constraint "agreements_gender_check" CHECK ((gender = ANY (ARRAY['male'::text, 'female'::text, 'other'::text, 'unknown'::text]))) not valid;

alter table "public"."agreements" validate constraint "agreements_gender_check";

alter table "public"."agreements" add constraint "agreements_headquarter_id_fkey" FOREIGN KEY (headquarter_id) REFERENCES headquarters(id) ON DELETE RESTRICT not valid;

alter table "public"."agreements" validate constraint "agreements_headquarter_id_fkey";

alter table "public"."agreements" add constraint "agreements_role_id_fkey" FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE RESTRICT not valid;

alter table "public"."agreements" validate constraint "agreements_role_id_fkey";

alter table "public"."agreements" add constraint "agreements_season_id_fkey" FOREIGN KEY (season_id) REFERENCES seasons(id) not valid;

alter table "public"."agreements" validate constraint "agreements_season_id_fkey";

alter table "public"."agreements" add constraint "agreements_status_check" CHECK ((status = ANY (ARRAY['active'::text, 'inactive'::text, 'prospect'::text, 'graduated'::text]))) not valid;

alter table "public"."agreements" validate constraint "agreements_status_check";

alter table "public"."agreements" add constraint "agreements_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE RESTRICT not valid;

alter table "public"."agreements" validate constraint "agreements_user_id_fkey";

alter table "public"."agreements" add constraint "agreements_user_id_season_id_key" UNIQUE using index "agreements_user_id_season_id_key";

alter table "public"."collaborators" add constraint "collaborators_headquarter_id_fkey" FOREIGN KEY (headquarter_id) REFERENCES headquarters(id) ON DELETE RESTRICT not valid;

alter table "public"."collaborators" validate constraint "collaborators_headquarter_id_fkey";

alter table "public"."collaborators" add constraint "collaborators_role_id_fkey" FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE RESTRICT not valid;

alter table "public"."collaborators" validate constraint "collaborators_role_id_fkey";

alter table "public"."collaborators" add constraint "collaborators_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE not valid;

alter table "public"."collaborators" validate constraint "collaborators_user_id_fkey";

alter table "public"."collaborators" add constraint "collaborators_user_id_key" UNIQUE using index "collaborators_user_id_key";

alter table "public"."companion_student_map" add constraint "companion_student_map_companion_id_fkey" FOREIGN KEY (companion_id) REFERENCES collaborators(user_id) ON DELETE CASCADE not valid;

alter table "public"."companion_student_map" validate constraint "companion_student_map_companion_id_fkey";

alter table "public"."companion_student_map" add constraint "companion_student_map_headquarter_id_fkey" FOREIGN KEY (headquarter_id) REFERENCES headquarters(id) ON DELETE RESTRICT not valid;

alter table "public"."companion_student_map" validate constraint "companion_student_map_headquarter_id_fkey";

alter table "public"."companion_student_map" add constraint "companion_student_map_season_id_fkey" FOREIGN KEY (season_id) REFERENCES seasons(id) ON DELETE CASCADE not valid;

alter table "public"."companion_student_map" validate constraint "companion_student_map_season_id_fkey";

alter table "public"."companion_student_map" add constraint "companion_student_map_student_id_fkey" FOREIGN KEY (student_id) REFERENCES students(user_id) ON DELETE CASCADE not valid;

alter table "public"."companion_student_map" validate constraint "companion_student_map_student_id_fkey";

alter table "public"."countries" add constraint "countries_code_key" UNIQUE using index "countries_code_key";

alter table "public"."countries" add constraint "countries_status_check" CHECK ((status = ANY (ARRAY['active'::text, 'inactive'::text]))) not valid;

alter table "public"."countries" validate constraint "countries_status_check";

alter table "public"."event_types" add constraint "event_types_name_key" UNIQUE using index "event_types_name_key";

alter table "public"."events" add constraint "events_event_type_id_fkey" FOREIGN KEY (event_type_id) REFERENCES event_types(id) ON DELETE RESTRICT not valid;

alter table "public"."events" validate constraint "events_event_type_id_fkey";

alter table "public"."events" add constraint "events_headquarter_id_fkey" FOREIGN KEY (headquarter_id) REFERENCES headquarters(id) ON DELETE RESTRICT not valid;

alter table "public"."events" validate constraint "events_headquarter_id_fkey";

alter table "public"."events" add constraint "events_season_id_fkey" FOREIGN KEY (season_id) REFERENCES seasons(id) ON DELETE RESTRICT not valid;

alter table "public"."events" validate constraint "events_season_id_fkey";

alter table "public"."events" add constraint "events_status_check" CHECK ((status = ANY (ARRAY['draft'::text, 'scheduled'::text, 'completed'::text, 'cancelled'::text]))) not valid;

alter table "public"."events" validate constraint "events_status_check";

alter table "public"."facilitator_workshop_map" add constraint "facilitator_workshop_map_facilitator_id_fkey" FOREIGN KEY (facilitator_id) REFERENCES collaborators(user_id) ON DELETE CASCADE not valid;

alter table "public"."facilitator_workshop_map" validate constraint "facilitator_workshop_map_facilitator_id_fkey";

alter table "public"."facilitator_workshop_map" add constraint "facilitator_workshop_map_headquarter_id_fkey" FOREIGN KEY (headquarter_id) REFERENCES headquarters(id) ON DELETE RESTRICT not valid;

alter table "public"."facilitator_workshop_map" validate constraint "facilitator_workshop_map_headquarter_id_fkey";

alter table "public"."facilitator_workshop_map" add constraint "facilitator_workshop_map_season_id_fkey" FOREIGN KEY (season_id) REFERENCES seasons(id) ON DELETE CASCADE not valid;

alter table "public"."facilitator_workshop_map" validate constraint "facilitator_workshop_map_season_id_fkey";

alter table "public"."facilitator_workshop_map" add constraint "facilitator_workshop_map_workshop_id_fkey" FOREIGN KEY (workshop_id) REFERENCES scheduled_workshops(id) ON DELETE CASCADE not valid;

alter table "public"."facilitator_workshop_map" validate constraint "facilitator_workshop_map_workshop_id_fkey";

alter table "public"."headquarters" add constraint "headquarters_country_id_fkey" FOREIGN KEY (country_id) REFERENCES countries(id) ON DELETE RESTRICT not valid;

alter table "public"."headquarters" validate constraint "headquarters_country_id_fkey";

alter table "public"."headquarters" add constraint "headquarters_status_check" CHECK ((status = ANY (ARRAY['active'::text, 'inactive'::text]))) not valid;

alter table "public"."headquarters" validate constraint "headquarters_status_check";

alter table "public"."master_workshop_types" add constraint "master_workshop_types_master_name_key" UNIQUE using index "master_workshop_types_master_name_key";

alter table "public"."notification_deliveries" add constraint "notification_deliveries_notification_id_channel_key" UNIQUE using index "notification_deliveries_notification_id_channel_key";

alter table "public"."notification_deliveries" add constraint "notification_deliveries_notification_id_fkey" FOREIGN KEY (notification_id) REFERENCES notifications(id) ON DELETE CASCADE not valid;

alter table "public"."notification_deliveries" validate constraint "notification_deliveries_notification_id_fkey";

alter table "public"."notification_preferences" add constraint "notification_preferences_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE not valid;

alter table "public"."notification_preferences" validate constraint "notification_preferences_user_id_fkey";

alter table "public"."notification_preferences" add constraint "notification_preferences_user_id_key" UNIQUE using index "notification_preferences_user_id_key";

alter table "public"."notification_templates" add constraint "notification_templates_code_key" UNIQUE using index "notification_templates_code_key";

alter table "public"."notifications" add constraint "notifications_recipient_id_fkey" FOREIGN KEY (recipient_id) REFERENCES auth.users(id) ON DELETE CASCADE not valid;

alter table "public"."notifications" validate constraint "notifications_recipient_id_fkey";

alter table "public"."notifications" add constraint "notifications_sender_id_fkey" FOREIGN KEY (sender_id) REFERENCES auth.users(id) ON DELETE SET NULL not valid;

alter table "public"."notifications" validate constraint "notifications_sender_id_fkey";

alter table "public"."processes" add constraint "processes_status_check" CHECK ((status = ANY (ARRAY['active'::text, 'inactive'::text]))) not valid;

alter table "public"."processes" validate constraint "processes_status_check";

alter table "public"."roles" add constraint "roles_code_key" UNIQUE using index "roles_code_key";

alter table "public"."roles" add constraint "roles_status_check" CHECK ((status = ANY (ARRAY['active'::text, 'inactive'::text]))) not valid;

alter table "public"."roles" validate constraint "roles_status_check";

alter table "public"."scheduled_workshops" add constraint "chk_workshop_times" CHECK ((end_datetime > start_datetime)) not valid;

alter table "public"."scheduled_workshops" validate constraint "chk_workshop_times";

alter table "public"."scheduled_workshops" add constraint "scheduled_workshops_facilitator_id_fkey" FOREIGN KEY (facilitator_id) REFERENCES collaborators(user_id) ON DELETE RESTRICT not valid;

alter table "public"."scheduled_workshops" validate constraint "scheduled_workshops_facilitator_id_fkey";

alter table "public"."scheduled_workshops" add constraint "scheduled_workshops_headquarter_id_fkey" FOREIGN KEY (headquarter_id) REFERENCES headquarters(id) ON DELETE RESTRICT not valid;

alter table "public"."scheduled_workshops" validate constraint "scheduled_workshops_headquarter_id_fkey";

alter table "public"."scheduled_workshops" add constraint "scheduled_workshops_master_workshop_type_id_fkey" FOREIGN KEY (master_workshop_type_id) REFERENCES master_workshop_types(id) ON DELETE RESTRICT not valid;

alter table "public"."scheduled_workshops" validate constraint "scheduled_workshops_master_workshop_type_id_fkey";

alter table "public"."scheduled_workshops" add constraint "scheduled_workshops_season_id_fkey" FOREIGN KEY (season_id) REFERENCES seasons(id) ON DELETE RESTRICT not valid;

alter table "public"."scheduled_workshops" validate constraint "scheduled_workshops_season_id_fkey";

alter table "public"."scheduled_workshops" add constraint "scheduled_workshops_status_check" CHECK ((status = ANY (ARRAY['scheduled'::text, 'completed'::text, 'cancelled'::text]))) not valid;

alter table "public"."scheduled_workshops" validate constraint "scheduled_workshops_status_check";

alter table "public"."scheduled_workshops" add constraint "uq_local_name_hq_season" UNIQUE using index "uq_local_name_hq_season";

alter table "public"."seasons" add constraint "check_season_dates" CHECK (((end_date IS NULL) OR (start_date IS NULL) OR (end_date >= start_date))) not valid;

alter table "public"."seasons" validate constraint "check_season_dates";

alter table "public"."seasons" add constraint "seasons_headquarter_id_fkey" FOREIGN KEY (headquarter_id) REFERENCES headquarters(id) ON DELETE RESTRICT not valid;

alter table "public"."seasons" validate constraint "seasons_headquarter_id_fkey";

alter table "public"."seasons" add constraint "seasons_manager_id_fkey" FOREIGN KEY (manager_id) REFERENCES collaborators(user_id) ON DELETE SET NULL not valid;

alter table "public"."seasons" validate constraint "seasons_manager_id_fkey";

alter table "public"."seasons" add constraint "seasons_status_check" CHECK ((status = ANY (ARRAY['active'::text, 'inactive'::text, 'completed'::text]))) not valid;

alter table "public"."seasons" validate constraint "seasons_status_check";

alter table "public"."seasons" add constraint "unique_season_name_per_hq" UNIQUE using index "unique_season_name_per_hq";

alter table "public"."strapi_migrations" add constraint "strapi_migrations_status_check" CHECK ((status = ANY (ARRAY['success'::text, 'failed'::text]))) not valid;

alter table "public"."strapi_migrations" validate constraint "strapi_migrations_status_check";

alter table "public"."student_attendance" add constraint "student_attendance_attendance_status_check" CHECK ((attendance_status = ANY (ARRAY['present'::text, 'absent'::text]))) not valid;

alter table "public"."student_attendance" validate constraint "student_attendance_attendance_status_check";

alter table "public"."student_attendance" add constraint "student_attendance_scheduled_workshop_id_fkey" FOREIGN KEY (scheduled_workshop_id) REFERENCES scheduled_workshops(id) ON DELETE CASCADE not valid;

alter table "public"."student_attendance" validate constraint "student_attendance_scheduled_workshop_id_fkey";

alter table "public"."student_attendance" add constraint "student_attendance_student_id_fkey" FOREIGN KEY (student_id) REFERENCES students(user_id) ON DELETE CASCADE not valid;

alter table "public"."student_attendance" validate constraint "student_attendance_student_id_fkey";

alter table "public"."student_attendance" add constraint "uq_student_workshop_attendance" UNIQUE using index "uq_student_workshop_attendance";

alter table "public"."students" add constraint "students_headquarter_id_fkey" FOREIGN KEY (headquarter_id) REFERENCES headquarters(id) ON DELETE RESTRICT not valid;

alter table "public"."students" validate constraint "students_headquarter_id_fkey";

alter table "public"."students" add constraint "students_season_id_fkey" FOREIGN KEY (season_id) REFERENCES seasons(id) ON DELETE RESTRICT not valid;

alter table "public"."students" validate constraint "students_season_id_fkey";

alter table "public"."students" add constraint "students_status_check" CHECK ((status = ANY (ARRAY['active'::text, 'prospect'::text, 'graduated'::text, 'inactive'::text]))) not valid;

alter table "public"."students" validate constraint "students_status_check";

alter table "public"."students" add constraint "students_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE not valid;

alter table "public"."students" validate constraint "students_user_id_fkey";

alter table "public"."students" add constraint "students_user_id_key" UNIQUE using index "students_user_id_key";

alter table "public"."user_search_index" add constraint "user_search_index_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE not valid;

alter table "public"."user_search_index" validate constraint "user_search_index_user_id_fkey";

alter table "public"."workflow_action_history" add constraint "workflow_action_history_action_id_fkey" FOREIGN KEY (action_id) REFERENCES workflow_actions(id) ON DELETE CASCADE not valid;

alter table "public"."workflow_action_history" validate constraint "workflow_action_history_action_id_fkey";

alter table "public"."workflow_action_history" add constraint "workflow_action_history_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL not valid;

alter table "public"."workflow_action_history" validate constraint "workflow_action_history_user_id_fkey";

alter table "public"."workflow_action_role_assignments" add constraint "workflow_action_role_assignme_template_stage_id_action_type_key" UNIQUE using index "workflow_action_role_assignme_template_stage_id_action_type_key";

alter table "public"."workflow_action_role_assignments" add constraint "workflow_action_role_assignments_template_stage_id_fkey" FOREIGN KEY (template_stage_id) REFERENCES workflow_template_stages(id) ON DELETE CASCADE not valid;

alter table "public"."workflow_action_role_assignments" validate constraint "workflow_action_role_assignments_template_stage_id_fkey";

alter table "public"."workflow_actions" add constraint "workflow_actions_action_type_check" CHECK ((action_type = ANY (ARRAY['approve'::text, 'review'::text, 'upload'::text, 'sign'::text, 'custom'::text]))) not valid;

alter table "public"."workflow_actions" validate constraint "workflow_actions_action_type_check";

alter table "public"."workflow_actions" add constraint "workflow_actions_assigned_by_fkey" FOREIGN KEY (assigned_by) REFERENCES auth.users(id) ON DELETE SET NULL not valid;

alter table "public"."workflow_actions" validate constraint "workflow_actions_assigned_by_fkey";

alter table "public"."workflow_actions" add constraint "workflow_actions_assigned_to_fkey" FOREIGN KEY (assigned_to) REFERENCES auth.users(id) ON DELETE SET NULL not valid;

alter table "public"."workflow_actions" validate constraint "workflow_actions_assigned_to_fkey";

alter table "public"."workflow_actions" add constraint "workflow_actions_completed_by_fkey" FOREIGN KEY (completed_by) REFERENCES auth.users(id) ON DELETE SET NULL not valid;

alter table "public"."workflow_actions" validate constraint "workflow_actions_completed_by_fkey";

alter table "public"."workflow_actions" add constraint "workflow_actions_priority_check" CHECK ((priority = ANY (ARRAY['high'::text, 'medium'::text, 'low'::text]))) not valid;

alter table "public"."workflow_actions" validate constraint "workflow_actions_priority_check";

alter table "public"."workflow_actions" add constraint "workflow_actions_rejected_by_fkey" FOREIGN KEY (rejected_by) REFERENCES auth.users(id) ON DELETE SET NULL not valid;

alter table "public"."workflow_actions" validate constraint "workflow_actions_rejected_by_fkey";

alter table "public"."workflow_actions" add constraint "workflow_actions_stage_instance_id_fkey" FOREIGN KEY (stage_instance_id) REFERENCES workflow_stage_instances(id) ON DELETE CASCADE not valid;

alter table "public"."workflow_actions" validate constraint "workflow_actions_stage_instance_id_fkey";

alter table "public"."workflow_actions" add constraint "workflow_actions_status_check" CHECK ((status = ANY (ARRAY['pending'::text, 'in_progress'::text, 'completed'::text, 'rejected'::text, 'cancelled'::text]))) not valid;

alter table "public"."workflow_actions" validate constraint "workflow_actions_status_check";

alter table "public"."workflow_instances" add constraint "workflow_instances_current_stage_id_fkey" FOREIGN KEY (current_stage_id) REFERENCES workflow_template_stages(id) not valid;

alter table "public"."workflow_instances" validate constraint "workflow_instances_current_stage_id_fkey";

alter table "public"."workflow_instances" add constraint "workflow_instances_initiated_by_fkey" FOREIGN KEY (initiated_by) REFERENCES auth.users(id) ON DELETE SET NULL not valid;

alter table "public"."workflow_instances" validate constraint "workflow_instances_initiated_by_fkey";

alter table "public"."workflow_instances" add constraint "workflow_instances_status_check" CHECK ((status = ANY (ARRAY['draft'::text, 'active'::text, 'completed'::text, 'cancelled'::text, 'failed'::text]))) not valid;

alter table "public"."workflow_instances" validate constraint "workflow_instances_status_check";

alter table "public"."workflow_instances" add constraint "workflow_instances_template_id_fkey" FOREIGN KEY (template_id) REFERENCES workflow_templates(id) ON DELETE RESTRICT not valid;

alter table "public"."workflow_instances" validate constraint "workflow_instances_template_id_fkey";

alter table "public"."workflow_notifications" add constraint "workflow_notifications_action_id_fkey" FOREIGN KEY (action_id) REFERENCES workflow_actions(id) ON DELETE CASCADE not valid;

alter table "public"."workflow_notifications" validate constraint "workflow_notifications_action_id_fkey";

alter table "public"."workflow_notifications" add constraint "workflow_notifications_channel_check" CHECK ((channel = ANY (ARRAY['email'::text, 'sms'::text, 'in_app'::text, 'webhook'::text]))) not valid;

alter table "public"."workflow_notifications" validate constraint "workflow_notifications_channel_check";

alter table "public"."workflow_notifications" add constraint "workflow_notifications_notification_type_check" CHECK ((notification_type = ANY (ARRAY['assignment'::text, 'reminder'::text, 'completion'::text, 'rejection'::text, 'escalation'::text]))) not valid;

alter table "public"."workflow_notifications" validate constraint "workflow_notifications_notification_type_check";

alter table "public"."workflow_notifications" add constraint "workflow_notifications_recipient_id_fkey" FOREIGN KEY (recipient_id) REFERENCES auth.users(id) ON DELETE CASCADE not valid;

alter table "public"."workflow_notifications" validate constraint "workflow_notifications_recipient_id_fkey";

alter table "public"."workflow_notifications" add constraint "workflow_notifications_workflow_instance_id_fkey" FOREIGN KEY (workflow_instance_id) REFERENCES workflow_instances(id) ON DELETE CASCADE not valid;

alter table "public"."workflow_notifications" validate constraint "workflow_notifications_workflow_instance_id_fkey";

alter table "public"."workflow_stage_instances" add constraint "workflow_stage_instances_status_check" CHECK ((status = ANY (ARRAY['pending'::text, 'active'::text, 'completed'::text, 'failed'::text, 'skipped'::text]))) not valid;

alter table "public"."workflow_stage_instances" validate constraint "workflow_stage_instances_status_check";

alter table "public"."workflow_stage_instances" add constraint "workflow_stage_instances_template_stage_id_fkey" FOREIGN KEY (template_stage_id) REFERENCES workflow_template_stages(id) ON DELETE RESTRICT not valid;

alter table "public"."workflow_stage_instances" validate constraint "workflow_stage_instances_template_stage_id_fkey";

alter table "public"."workflow_stage_instances" add constraint "workflow_stage_instances_workflow_instance_id_fkey" FOREIGN KEY (workflow_instance_id) REFERENCES workflow_instances(id) ON DELETE CASCADE not valid;

alter table "public"."workflow_stage_instances" validate constraint "workflow_stage_instances_workflow_instance_id_fkey";

alter table "public"."workflow_stage_instances" add constraint "workflow_stage_instances_workflow_instance_id_template_stag_key" UNIQUE using index "workflow_stage_instances_workflow_instance_id_template_stag_key";

alter table "public"."workflow_template_permissions" add constraint "workflow_template_permissions_template_id_fkey" FOREIGN KEY (template_id) REFERENCES workflow_templates(id) ON DELETE CASCADE not valid;

alter table "public"."workflow_template_permissions" validate constraint "workflow_template_permissions_template_id_fkey";

alter table "public"."workflow_template_permissions" add constraint "workflow_template_permissions_template_id_key" UNIQUE using index "workflow_template_permissions_template_id_key";

alter table "public"."workflow_template_stages" add constraint "workflow_template_stages_stage_type_check" CHECK ((stage_type = ANY (ARRAY['sequential'::text, 'parallel'::text]))) not valid;

alter table "public"."workflow_template_stages" validate constraint "workflow_template_stages_stage_type_check";

alter table "public"."workflow_template_stages" add constraint "workflow_template_stages_template_id_fkey" FOREIGN KEY (template_id) REFERENCES workflow_templates(id) ON DELETE CASCADE not valid;

alter table "public"."workflow_template_stages" validate constraint "workflow_template_stages_template_id_fkey";

alter table "public"."workflow_template_stages" add constraint "workflow_template_stages_template_id_stage_number_key" UNIQUE using index "workflow_template_stages_template_id_stage_number_key";

alter table "public"."workflow_templates" add constraint "workflow_templates_created_by_fkey" FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL not valid;

alter table "public"."workflow_templates" validate constraint "workflow_templates_created_by_fkey";

alter table "public"."workflow_transitions" add constraint "workflow_transitions_from_stage_id_fkey" FOREIGN KEY (from_stage_id) REFERENCES workflow_stage_instances(id) ON DELETE CASCADE not valid;

alter table "public"."workflow_transitions" validate constraint "workflow_transitions_from_stage_id_fkey";

alter table "public"."workflow_transitions" add constraint "workflow_transitions_to_stage_id_fkey" FOREIGN KEY (to_stage_id) REFERENCES workflow_stage_instances(id) ON DELETE CASCADE not valid;

alter table "public"."workflow_transitions" validate constraint "workflow_transitions_to_stage_id_fkey";

alter table "public"."workflow_transitions" add constraint "workflow_transitions_transition_type_check" CHECK ((transition_type = ANY (ARRAY['advance'::text, 'rollback'::text, 'skip'::text, 'restart'::text]))) not valid;

alter table "public"."workflow_transitions" validate constraint "workflow_transitions_transition_type_check";

alter table "public"."workflow_transitions" add constraint "workflow_transitions_triggered_by_fkey" FOREIGN KEY (triggered_by) REFERENCES auth.users(id) ON DELETE SET NULL not valid;

alter table "public"."workflow_transitions" validate constraint "workflow_transitions_triggered_by_fkey";

alter table "public"."workflow_transitions" add constraint "workflow_transitions_workflow_instance_id_fkey" FOREIGN KEY (workflow_instance_id) REFERENCES workflow_instances(id) ON DELETE CASCADE not valid;

alter table "public"."workflow_transitions" validate constraint "workflow_transitions_workflow_instance_id_fkey";

set check_function_bodies = off;

create or replace view "public"."agreement_with_role" as  SELECT a.id,
    a.user_id,
    a.headquarter_id,
    a.season_id,
    a.status,
    a.email,
    a.document_number,
    a.phone,
    a.name,
    a.last_name,
    a.fts_name_lastname,
    a.address,
    a.signature_data,
    a.volunteering_agreement,
    a.ethical_document_agreement,
    a.mailing_agreement,
    a.age_verification,
    a.created_at,
    a.updated_at,
    COALESCE(jsonb_build_object('role_id', r.id, 'role_name', r.name, 'role_description', r.description, 'role_code', r.code, 'role_level', r.level), '{}'::jsonb) AS role
   FROM (agreements a
     LEFT JOIN roles r ON ((a.role_id = r.id)));


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

CREATE OR REPLACE FUNCTION public.create_notification_from_template(p_template_code text, p_recipient_id uuid, p_variables jsonb DEFAULT '{}'::jsonb, p_sender_id uuid DEFAULT NULL::uuid, p_priority notification_priority DEFAULT NULL::notification_priority, p_related_entity_type text DEFAULT NULL::text, p_related_entity_id uuid DEFAULT NULL::uuid, p_action_url text DEFAULT NULL::text)
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

CREATE OR REPLACE FUNCTION public.get_agreement_by_role_id(role_id uuid)
 RETURNS SETOF agreement_with_role
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
BEGIN
  RETURN QUERY
  SELECT a.id,
         a.user_id,
         a.headquarter_id,
         a.season_id,
         a.status,
         a.email,
         a.document_number,
         a.phone,
         a.name,
         a.last_name,
         a.fts_name_lastname,
         a.address,
         a.signature_data,
         a.volunteering_agreement,
         a.ethical_document_agreement,
         a.mailing_agreement,
         a.age_verification,
         a.created_at,
         a.updated_at,
         COALESCE(jsonb_build_object('role_id', r.id, 'role_name', r.name, 'role_description', r.description, 'role_code', r.code, 'role_level', r.level), '{}'::jsonb) AS role
  FROM public.agreements a
  LEFT JOIN public.roles r ON a.role_id = r.id
  WHERE a.role_id = role_id
    AND public.fn_can_access_agreement(a.headquarter_id, a.user_id);
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_agreement_with_role_by_id(p_agreement_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE
  v_result JSONB;
BEGIN
  SELECT to_jsonb(row(
    a.id,
    a.user_id,
    a.headquarter_id,
    a.season_id,
    a.status,
    a.email,
    a.document_number,
    a.phone,
    a.name,
    a.last_name,
    a.fts_name_lastname,
    a.address,
    a.signature_data,
    a.volunteering_agreement,
    a.ethical_document_agreement,
    a.mailing_agreement,
    a.age_verification,
    a.created_at,
    a.updated_at,
    COALESCE(jsonb_build_object('role_id', r.id, 'role_name', r.name, 'role_description', r.description, 'role_code', r.code, 'role_level', r.level), '{}'::jsonb)
  )) INTO v_result
  FROM public.agreements a
  LEFT JOIN public.roles r ON a.role_id = r.id
  WHERE a.id = p_agreement_id
    AND public.fn_can_access_agreement(a.headquarter_id, a.user_id);

  IF v_result IS NULL THEN
    RETURN jsonb_build_object('error', 'Agreement not found or access denied');
  END IF;

  RETURN v_result;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_agreements_by_role(role_name text)
 RETURNS SETOF agreement_with_role
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
BEGIN
  RETURN QUERY
  SELECT a.id,
         a.user_id,
         a.headquarter_id,
         a.season_id,
         a.status,
         a.email,
         a.document_number,
         a.phone,
         a.name,
         a.last_name,
         a.fts_name_lastname,
         a.address,
         a.signature_data,
         a.volunteering_agreement,
         a.ethical_document_agreement,
         a.mailing_agreement,
         a.age_verification,
         a.created_at,
         a.updated_at,
         COALESCE(jsonb_build_object('role_id', r.id, 'role_name', r.name, 'role_description', r.description, 'role_code', r.code, 'role_level', r.level), '{}'::jsonb) AS role
  FROM public.agreements a
  LEFT JOIN public.roles r ON a.role_id = r.id
  WHERE r.name = role_name
    AND public.fn_can_access_agreement(a.headquarter_id, a.user_id);
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_agreements_by_role_string(role_string text)
 RETURNS SETOF agreement_with_role
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
BEGIN
  RETURN QUERY
  SELECT a.id,
         a.user_id,
         a.headquarter_id,
         a.season_id,
         a.status,
         a.email,
         a.document_number,
         a.phone,
         a.name,
         a.last_name,
         a.fts_name_lastname,
         a.address,
         a.signature_data,
         a.volunteering_agreement,
         a.ethical_document_agreement,
         a.mailing_agreement,
         a.age_verification,
         a.created_at,
         a.updated_at,
         COALESCE(jsonb_build_object('role_id', r.id, 'role_name', r.name, 'role_description', r.description, 'role_code', r.code, 'role_level', r.level), '{}'::jsonb) AS role
  FROM public.agreements a
  LEFT JOIN public.roles r ON a.role_id = r.id
  WHERE (r.name ILIKE '%' || role_string || '%' OR r.code ILIKE '%' || role_string || '%')
    AND public.fn_can_access_agreement(a.headquarter_id, a.user_id);
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_agreements_with_role()
 RETURNS SETOF agreement_with_role
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
BEGIN
  RETURN QUERY
  SELECT a.id,
         a.user_id,
         a.headquarter_id,
         a.season_id,
         a.status,
         a.email,
         a.document_number,
         a.phone,
         a.name,
         a.last_name,
         a.fts_name_lastname,
         a.address,
         a.signature_data,
         a.volunteering_agreement,
         a.ethical_document_agreement,
         a.mailing_agreement,
         a.age_verification,
         a.created_at,
         a.updated_at,
         COALESCE(jsonb_build_object('role_id', r.id, 'role_name', r.name, 'role_description', r.description, 'role_code', r.code, 'role_level', r.level), '{}'::jsonb) AS role
  FROM public.agreements a
  LEFT JOIN public.roles r ON a.role_id = r.id
  WHERE public.fn_can_access_agreement(a.headquarter_id, a.user_id);
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_agreements_with_role_paginated(p_limit integer DEFAULT 10, p_offset integer DEFAULT 0, p_status text DEFAULT NULL::text, p_headquarter_id uuid DEFAULT NULL::uuid, p_season_id uuid DEFAULT NULL::uuid, p_search text DEFAULT NULL::text, p_role_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE
  v_total BIGINT;
  v_results JSONB;
  v_data JSONB;
BEGIN
  -- Build the WHERE clause with access control
  SELECT COUNT(*) INTO v_total
  FROM public.agreements a
  LEFT JOIN public.roles r ON a.role_id = r.id
  WHERE 
    (p_status IS NULL OR a.status = p_status)
    AND (p_headquarter_id IS NULL OR a.headquarter_id = p_headquarter_id)
    AND (p_season_id IS NULL OR a.season_id = p_season_id)
    AND (p_search IS NULL OR 
         a.name ILIKE '%' || p_search || '%' OR 
         a.last_name ILIKE '%' || p_search || '%' OR
         a.email ILIKE '%' || p_search || '%' OR
         a.document_number ILIKE '%' || p_search || '%')
    AND (p_role_id IS NULL OR a.role_id = p_role_id)
    -- Apply access control based on role level and headquarter
    AND public.fn_can_access_agreement(a.headquarter_id, a.user_id);

  SELECT jsonb_agg(to_jsonb(awr)) INTO v_data
  FROM (
    SELECT a.id,
           a.user_id,
           a.headquarter_id,
           a.season_id,
           a.status,
           a.email,
           a.document_number,
           a.phone,
           a.name,
           a.last_name,
           a.fts_name_lastname,
           a.address,
           a.signature_data,
           a.volunteering_agreement,
           a.ethical_document_agreement,
           a.mailing_agreement,
           a.age_verification,
           a.created_at,
           a.updated_at,
           COALESCE(jsonb_build_object('role_id', r.id, 'role_name', r.name, 'role_description', r.description, 'role_code', r.code, 'role_level', r.level), '{}'::jsonb) AS role
    FROM public.agreements a
    LEFT JOIN public.roles r ON a.role_id = r.id
    WHERE 
      (p_status IS NULL OR a.status = p_status)
      AND (p_headquarter_id IS NULL OR a.headquarter_id = p_headquarter_id)
      AND (p_season_id IS NULL OR a.season_id = p_season_id)
      AND (p_search IS NULL OR 
           a.name ILIKE '%' || p_search || '%' OR 
           a.last_name ILIKE '%' || p_search || '%' OR
           a.email ILIKE '%' || p_search || '%' OR
           a.document_number ILIKE '%' || p_search || '%')
      AND (p_role_id IS NULL OR a.role_id = p_role_id)
      -- Apply access control based on role level and headquarter
      AND public.fn_can_access_agreement(a.headquarter_id, a.user_id)
    ORDER BY a.created_at DESC
    LIMIT p_limit
    OFFSET p_offset
  ) awr;

  IF v_data IS NULL THEN
    v_data := '[]'::jsonb;
  END IF;

  v_results := jsonb_build_object(
    'data', v_data,
    'pagination', jsonb_build_object(
      'total', v_total,
      'limit', p_limit,
      'offset', p_offset,
      'page', CASE WHEN p_limit > 0 THEN (p_offset / p_limit) + 1 ELSE 1 END,
      'pages', CASE WHEN p_limit > 0 THEN CEIL(v_total::numeric / p_limit::numeric) ELSE 1 END
    )
  );

  RETURN v_results;
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

CREATE OR REPLACE FUNCTION public.get_headquarter_quick_stats(p_headquarter_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE
    v_stats jsonb;
BEGIN
    SELECT jsonb_build_object(
        'active_agreements_count', (
            SELECT COUNT(*)
            FROM public.agreements
            WHERE headquarter_id = p_headquarter_id
              AND status IN ('active', 'signed')
        ),
        'facilitators_count', (
            SELECT COUNT(DISTINCT a.id)
            FROM public.agreements a
            JOIN public.roles r ON a.role_id = r.id
            WHERE a.headquarter_id = p_headquarter_id
              AND r.code = 'facilitator'
              AND a.status IN ('active', 'signed')
        ),
        'companions_count', (
            SELECT COUNT(DISTINCT a.id)
            FROM public.agreements a
            JOIN public.roles r ON a.role_id = r.id
            WHERE a.headquarter_id = p_headquarter_id
              AND r.code = 'companion'
              AND a.status IN ('active', 'signed')
        ),
        'students', jsonb_build_object(
            'active', (
                SELECT COUNT(*)
                FROM public.students s
                JOIN public.agreements a ON s.agreement_id = a.id
                WHERE a.headquarter_id = p_headquarter_id
                  AND s.status = 'active'
            ),
            'inactive', (
                SELECT COUNT(*)
                FROM public.students s
                JOIN public.agreements a ON s.agreement_id = a.id
                WHERE a.headquarter_id = p_headquarter_id
                  AND s.status = 'inactive'
            ),
            'prospects', (
                SELECT COUNT(*)
                FROM public.agreements a
                JOIN public.roles r ON a.role_id = r.id
                WHERE a.headquarter_id = p_headquarter_id
                  AND r.code = 'student'
                  AND a.status = 'prospect'
            )
        ),
        'upcoming_workshops', (
            SELECT COUNT(*)
            FROM public.scheduled_workshops
            WHERE headquarter_id = p_headquarter_id
              AND date >= CURRENT_DATE
              AND date <= CURRENT_DATE + INTERVAL '7 days'
        )
    ) INTO v_stats;

    RETURN v_stats;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_home_dashboard_stats(p_agreement_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE
    v_result jsonb;
    v_tier integer;
    v_role_level integer;
    v_hq_id uuid;
    v_season_id uuid;
BEGIN
    -- Get agreement details and role level
    SELECT 
        r.level,
        a.headquarter_id,
        a.season_id
    INTO v_role_level, v_hq_id, v_season_id
    FROM public.agreements a
    JOIN public.roles r ON a.role_id = r.id
    WHERE a.id = p_agreement_id;

    -- Return empty if agreement not found
    IF v_role_level IS NULL THEN
        RETURN '{}'::jsonb;
    END IF;

    -- Determine user tier based on role level
    -- Tier 3: Leadership (level 51+)
    -- Tier 2: Operational Staff (level 20-50)
    -- Tier 1: Students (level < 20)
    IF v_role_level >= 51 THEN
        v_tier := 3;
    ELSIF v_role_level >= 20 THEN
        v_tier := 2;
    ELSE
        v_tier := 1;
    END IF;

    -- Build response based on tier
    v_result := jsonb_build_object('tier', v_tier);

    -- Add tier-specific metrics
    IF v_tier = 3 THEN
        -- Leadership tier gets organization-wide metrics
        v_result := v_result || jsonb_build_object(
            'metrics', public.get_organization_overview(),
            'recent_agreements', (
                SELECT jsonb_agg(
                    jsonb_build_object(
                        'id', a.id,
                        'status', a.status,
                        'role_name', r.name,
                        'headquarter_name', h.name,
                        'created_at', a.created_at
                    )
                )
                FROM (
                    SELECT a.*, row_number() OVER (ORDER BY a.created_at DESC) as rn
                    FROM public.agreements a
                    WHERE a.created_at >= CURRENT_DATE - INTERVAL '7 days'
                ) a
                JOIN public.roles r ON a.role_id = r.id
                JOIN public.headquarters h ON a.headquarter_id = h.id
                WHERE a.rn <= 10
            )
        );
    ELSIF v_tier = 2 THEN
        -- Operational staff gets HQ-specific metrics
        v_result := v_result || jsonb_build_object(
            'metrics', public.get_headquarter_quick_stats(v_hq_id),
            'headquarter_info', (
                SELECT jsonb_build_object(
                    'id', h.id,
                    'name', h.name,
                    'city', h.city,
                    'country', c.name
                )
                FROM public.headquarters h
                LEFT JOIN public.countries c ON h.country_id = c.id
                WHERE h.id = v_hq_id
            )
        );
    ELSE
        -- Students get their agreement summary
        v_result := v_result || jsonb_build_object(
            'agreement', public.get_my_agreement_summary(p_agreement_id)
        );
    END IF;

    -- Add recent activities for all tiers
    v_result := v_result || jsonb_build_object(
        'recent_activities', public.get_recent_activities(p_agreement_id, v_role_level, 10)
    );

    RETURN v_result;
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

CREATE OR REPLACE FUNCTION public.get_my_agreement_summary(p_agreement_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE
    v_result jsonb;
BEGIN
    SELECT jsonb_build_object(
        'id', a.id,
        'status', a.status,
        'role', r.code,
        'role_name', r.name,
        'role_level', r.level,
        'headquarter_id', h.id,
        'headquarter_name', h.name,
        'season_id', s.id,
        'season_name', s.name,
        'name', a.name,
        'last_name', a.last_name,
        'email', a.email,
        'phone', a.phone,
        'activation_date', a.activation_date,
        'created_at', a.created_at
    )
    INTO v_result
    FROM public.agreements a
    JOIN public.roles r ON a.role_id = r.id
    JOIN public.headquarters h ON a.headquarter_id = h.id
    JOIN public.seasons s ON a.season_id = s.id
    WHERE a.id = p_agreement_id;

    RETURN COALESCE(v_result, '{}'::jsonb);
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

CREATE OR REPLACE FUNCTION public.get_organization_overview()
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE
    v_overview jsonb;
BEGIN
    SELECT jsonb_build_object(
        'total_headquarters', (
            SELECT COUNT(*)
            FROM public.headquarters
            WHERE active = true
        ),
        'total_active_agreements', (
            SELECT COUNT(*)
            FROM public.agreements
            WHERE status IN ('active', 'signed')
        ),
        'total_students', (
            SELECT COUNT(*)
            FROM public.students
            WHERE status = 'active'
        ),
        'agreements_by_status', (
            SELECT jsonb_object_agg(status, count)
            FROM (
                SELECT status, COUNT(*) as count
                FROM public.agreements
                GROUP BY status
            ) t
        ),
        'students_by_headquarter', (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'headquarter', h.name,
                    'count', student_count
                )
            )
            FROM (
                SELECT a.headquarter_id, COUNT(DISTINCT s.id) as student_count
                FROM public.students s
                JOIN public.agreements a ON s.agreement_id = a.id
                WHERE s.status = 'active'
                GROUP BY a.headquarter_id
                ORDER BY student_count DESC
                LIMIT 10
            ) t
            JOIN public.headquarters h ON t.headquarter_id = h.id
        ),
        'system_health', jsonb_build_object(
            'status', CASE
                WHEN (SELECT COUNT(*) FROM public.agreements WHERE created_at >= CURRENT_DATE - INTERVAL '1 day') > 0
                THEN 'healthy'
                ELSE 'warning'
            END,
            'message', 'System operational'
        )
    ) INTO v_overview;

    RETURN v_overview;
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

CREATE OR REPLACE FUNCTION public.get_recent_activities(p_agreement_id uuid, p_role_level integer, p_limit integer DEFAULT 10)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE
    v_activities jsonb;
    v_hq_id uuid;
BEGIN
    -- Get agreement's HQ ID
    SELECT headquarter_id
    INTO v_hq_id
    FROM public.agreements
    WHERE id = p_agreement_id;

    -- Role level 51+ sees all activities
    IF p_role_level >= 51 THEN
        SELECT jsonb_agg(activity)
        INTO v_activities
        FROM (
            SELECT jsonb_build_object(
                'id', e.id,
                'type', 'event',
                'title', et.name,
                'description', e.description,
                'timestamp', e.created_at,
                'headquarter', h.name
            ) as activity
            FROM public.events e
            JOIN public.event_types et ON e.event_type_id = et.id
            LEFT JOIN public.headquarters h ON e.headquarter_id = h.id
            ORDER BY e.created_at DESC
            LIMIT p_limit
        ) t;
    -- Role level 20-50 sees HQ-specific activities
    ELSIF p_role_level >= 20 THEN
        SELECT jsonb_agg(activity)
        INTO v_activities
        FROM (
            SELECT jsonb_build_object(
                'id', e.id,
                'type', 'event',
                'title', et.name,
                'description', e.description,
                'timestamp', e.created_at
            ) as activity
            FROM public.events e
            JOIN public.event_types et ON e.event_type_id = et.id
            WHERE e.headquarter_id = v_hq_id
            ORDER BY e.created_at DESC
            LIMIT p_limit
        ) t;
    -- Students see their own activities
    ELSE
        SELECT jsonb_agg(activity)
        INTO v_activities
        FROM (
            -- Workshop attendance
            SELECT jsonb_build_object(
                'id', sa.id,
                'type', 'attendance',
                'title', 'Workshop Attendance',
                'description', 'Attended workshop on ' || sw.date::text,
                'timestamp', sa.created_at
            ) as activity
            FROM public.student_attendance sa
            JOIN public.scheduled_workshops sw ON sa.scheduled_workshop_id = sw.id
            JOIN public.students s ON sa.student_id = s.id
            JOIN public.agreements a ON s.user_id = a.user_id
            WHERE a.id = p_agreement_id
            ORDER BY sa.created_at DESC
            LIMIT p_limit
        ) t;
    END IF;

    RETURN COALESCE(v_activities, '[]'::jsonb);
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

CREATE OR REPLACE FUNCTION public.get_user_notifications(p_limit integer DEFAULT 20, p_offset integer DEFAULT 0, p_type notification_type DEFAULT NULL::notification_type, p_priority notification_priority DEFAULT NULL::notification_priority, p_is_read boolean DEFAULT NULL::boolean, p_category text DEFAULT NULL::text)
 RETURNS TABLE(id uuid, type notification_type, priority notification_priority, sender_id uuid, sender_name text, title text, body text, data jsonb, is_read boolean, read_at timestamp with time zone, created_at timestamp with time zone, action_url text, total_count bigint)
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

CREATE OR REPLACE FUNCTION public.send_role_based_notification(p_role_codes text[], p_title text, p_body text, p_min_role_level integer DEFAULT NULL::integer, p_type notification_type DEFAULT 'role_based'::notification_type, p_priority notification_priority DEFAULT 'medium'::notification_priority, p_data jsonb DEFAULT '{}'::jsonb)
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
            to_tsvector('simple', coalesce(NEW.name, '') || ' ' || coalesce(NEW.last_name, ''));
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

grant delete on table "public"."agreements" to "anon";

grant insert on table "public"."agreements" to "anon";

grant references on table "public"."agreements" to "anon";

grant select on table "public"."agreements" to "anon";

grant trigger on table "public"."agreements" to "anon";

grant truncate on table "public"."agreements" to "anon";

grant update on table "public"."agreements" to "anon";

grant delete on table "public"."agreements" to "authenticated";

grant insert on table "public"."agreements" to "authenticated";

grant references on table "public"."agreements" to "authenticated";

grant select on table "public"."agreements" to "authenticated";

grant trigger on table "public"."agreements" to "authenticated";

grant truncate on table "public"."agreements" to "authenticated";

grant update on table "public"."agreements" to "authenticated";

grant delete on table "public"."agreements" to "service_role";

grant insert on table "public"."agreements" to "service_role";

grant references on table "public"."agreements" to "service_role";

grant select on table "public"."agreements" to "service_role";

grant trigger on table "public"."agreements" to "service_role";

grant truncate on table "public"."agreements" to "service_role";

grant update on table "public"."agreements" to "service_role";

grant delete on table "public"."audit_log" to "anon";

grant insert on table "public"."audit_log" to "anon";

grant references on table "public"."audit_log" to "anon";

grant select on table "public"."audit_log" to "anon";

grant trigger on table "public"."audit_log" to "anon";

grant truncate on table "public"."audit_log" to "anon";

grant update on table "public"."audit_log" to "anon";

grant delete on table "public"."audit_log" to "authenticated";

grant insert on table "public"."audit_log" to "authenticated";

grant references on table "public"."audit_log" to "authenticated";

grant select on table "public"."audit_log" to "authenticated";

grant trigger on table "public"."audit_log" to "authenticated";

grant truncate on table "public"."audit_log" to "authenticated";

grant update on table "public"."audit_log" to "authenticated";

grant delete on table "public"."audit_log" to "service_role";

grant insert on table "public"."audit_log" to "service_role";

grant references on table "public"."audit_log" to "service_role";

grant select on table "public"."audit_log" to "service_role";

grant trigger on table "public"."audit_log" to "service_role";

grant truncate on table "public"."audit_log" to "service_role";

grant update on table "public"."audit_log" to "service_role";

grant delete on table "public"."collaborators" to "anon";

grant insert on table "public"."collaborators" to "anon";

grant references on table "public"."collaborators" to "anon";

grant select on table "public"."collaborators" to "anon";

grant trigger on table "public"."collaborators" to "anon";

grant truncate on table "public"."collaborators" to "anon";

grant update on table "public"."collaborators" to "anon";

grant delete on table "public"."collaborators" to "authenticated";

grant insert on table "public"."collaborators" to "authenticated";

grant references on table "public"."collaborators" to "authenticated";

grant select on table "public"."collaborators" to "authenticated";

grant trigger on table "public"."collaborators" to "authenticated";

grant truncate on table "public"."collaborators" to "authenticated";

grant update on table "public"."collaborators" to "authenticated";

grant delete on table "public"."collaborators" to "service_role";

grant insert on table "public"."collaborators" to "service_role";

grant references on table "public"."collaborators" to "service_role";

grant select on table "public"."collaborators" to "service_role";

grant trigger on table "public"."collaborators" to "service_role";

grant truncate on table "public"."collaborators" to "service_role";

grant update on table "public"."collaborators" to "service_role";

grant delete on table "public"."companion_student_map" to "anon";

grant insert on table "public"."companion_student_map" to "anon";

grant references on table "public"."companion_student_map" to "anon";

grant select on table "public"."companion_student_map" to "anon";

grant trigger on table "public"."companion_student_map" to "anon";

grant truncate on table "public"."companion_student_map" to "anon";

grant update on table "public"."companion_student_map" to "anon";

grant delete on table "public"."companion_student_map" to "authenticated";

grant insert on table "public"."companion_student_map" to "authenticated";

grant references on table "public"."companion_student_map" to "authenticated";

grant select on table "public"."companion_student_map" to "authenticated";

grant trigger on table "public"."companion_student_map" to "authenticated";

grant truncate on table "public"."companion_student_map" to "authenticated";

grant update on table "public"."companion_student_map" to "authenticated";

grant delete on table "public"."companion_student_map" to "service_role";

grant insert on table "public"."companion_student_map" to "service_role";

grant references on table "public"."companion_student_map" to "service_role";

grant select on table "public"."companion_student_map" to "service_role";

grant trigger on table "public"."companion_student_map" to "service_role";

grant truncate on table "public"."companion_student_map" to "service_role";

grant update on table "public"."companion_student_map" to "service_role";

grant delete on table "public"."countries" to "anon";

grant insert on table "public"."countries" to "anon";

grant references on table "public"."countries" to "anon";

grant select on table "public"."countries" to "anon";

grant trigger on table "public"."countries" to "anon";

grant truncate on table "public"."countries" to "anon";

grant update on table "public"."countries" to "anon";

grant delete on table "public"."countries" to "authenticated";

grant insert on table "public"."countries" to "authenticated";

grant references on table "public"."countries" to "authenticated";

grant select on table "public"."countries" to "authenticated";

grant trigger on table "public"."countries" to "authenticated";

grant truncate on table "public"."countries" to "authenticated";

grant update on table "public"."countries" to "authenticated";

grant delete on table "public"."countries" to "service_role";

grant insert on table "public"."countries" to "service_role";

grant references on table "public"."countries" to "service_role";

grant select on table "public"."countries" to "service_role";

grant trigger on table "public"."countries" to "service_role";

grant truncate on table "public"."countries" to "service_role";

grant update on table "public"."countries" to "service_role";

grant delete on table "public"."event_types" to "anon";

grant insert on table "public"."event_types" to "anon";

grant references on table "public"."event_types" to "anon";

grant select on table "public"."event_types" to "anon";

grant trigger on table "public"."event_types" to "anon";

grant truncate on table "public"."event_types" to "anon";

grant update on table "public"."event_types" to "anon";

grant delete on table "public"."event_types" to "authenticated";

grant insert on table "public"."event_types" to "authenticated";

grant references on table "public"."event_types" to "authenticated";

grant select on table "public"."event_types" to "authenticated";

grant trigger on table "public"."event_types" to "authenticated";

grant truncate on table "public"."event_types" to "authenticated";

grant update on table "public"."event_types" to "authenticated";

grant delete on table "public"."event_types" to "service_role";

grant insert on table "public"."event_types" to "service_role";

grant references on table "public"."event_types" to "service_role";

grant select on table "public"."event_types" to "service_role";

grant trigger on table "public"."event_types" to "service_role";

grant truncate on table "public"."event_types" to "service_role";

grant update on table "public"."event_types" to "service_role";

grant delete on table "public"."events" to "anon";

grant insert on table "public"."events" to "anon";

grant references on table "public"."events" to "anon";

grant select on table "public"."events" to "anon";

grant trigger on table "public"."events" to "anon";

grant truncate on table "public"."events" to "anon";

grant update on table "public"."events" to "anon";

grant delete on table "public"."events" to "authenticated";

grant insert on table "public"."events" to "authenticated";

grant references on table "public"."events" to "authenticated";

grant select on table "public"."events" to "authenticated";

grant trigger on table "public"."events" to "authenticated";

grant truncate on table "public"."events" to "authenticated";

grant update on table "public"."events" to "authenticated";

grant delete on table "public"."events" to "service_role";

grant insert on table "public"."events" to "service_role";

grant references on table "public"."events" to "service_role";

grant select on table "public"."events" to "service_role";

grant trigger on table "public"."events" to "service_role";

grant truncate on table "public"."events" to "service_role";

grant update on table "public"."events" to "service_role";

grant delete on table "public"."facilitator_workshop_map" to "anon";

grant insert on table "public"."facilitator_workshop_map" to "anon";

grant references on table "public"."facilitator_workshop_map" to "anon";

grant select on table "public"."facilitator_workshop_map" to "anon";

grant trigger on table "public"."facilitator_workshop_map" to "anon";

grant truncate on table "public"."facilitator_workshop_map" to "anon";

grant update on table "public"."facilitator_workshop_map" to "anon";

grant delete on table "public"."facilitator_workshop_map" to "authenticated";

grant insert on table "public"."facilitator_workshop_map" to "authenticated";

grant references on table "public"."facilitator_workshop_map" to "authenticated";

grant select on table "public"."facilitator_workshop_map" to "authenticated";

grant trigger on table "public"."facilitator_workshop_map" to "authenticated";

grant truncate on table "public"."facilitator_workshop_map" to "authenticated";

grant update on table "public"."facilitator_workshop_map" to "authenticated";

grant delete on table "public"."facilitator_workshop_map" to "service_role";

grant insert on table "public"."facilitator_workshop_map" to "service_role";

grant references on table "public"."facilitator_workshop_map" to "service_role";

grant select on table "public"."facilitator_workshop_map" to "service_role";

grant trigger on table "public"."facilitator_workshop_map" to "service_role";

grant truncate on table "public"."facilitator_workshop_map" to "service_role";

grant update on table "public"."facilitator_workshop_map" to "service_role";

grant delete on table "public"."headquarters" to "anon";

grant insert on table "public"."headquarters" to "anon";

grant references on table "public"."headquarters" to "anon";

grant select on table "public"."headquarters" to "anon";

grant trigger on table "public"."headquarters" to "anon";

grant truncate on table "public"."headquarters" to "anon";

grant update on table "public"."headquarters" to "anon";

grant delete on table "public"."headquarters" to "authenticated";

grant insert on table "public"."headquarters" to "authenticated";

grant references on table "public"."headquarters" to "authenticated";

grant select on table "public"."headquarters" to "authenticated";

grant trigger on table "public"."headquarters" to "authenticated";

grant truncate on table "public"."headquarters" to "authenticated";

grant update on table "public"."headquarters" to "authenticated";

grant delete on table "public"."headquarters" to "service_role";

grant insert on table "public"."headquarters" to "service_role";

grant references on table "public"."headquarters" to "service_role";

grant select on table "public"."headquarters" to "service_role";

grant trigger on table "public"."headquarters" to "service_role";

grant truncate on table "public"."headquarters" to "service_role";

grant update on table "public"."headquarters" to "service_role";

grant delete on table "public"."master_workshop_types" to "anon";

grant insert on table "public"."master_workshop_types" to "anon";

grant references on table "public"."master_workshop_types" to "anon";

grant select on table "public"."master_workshop_types" to "anon";

grant trigger on table "public"."master_workshop_types" to "anon";

grant truncate on table "public"."master_workshop_types" to "anon";

grant update on table "public"."master_workshop_types" to "anon";

grant delete on table "public"."master_workshop_types" to "authenticated";

grant insert on table "public"."master_workshop_types" to "authenticated";

grant references on table "public"."master_workshop_types" to "authenticated";

grant select on table "public"."master_workshop_types" to "authenticated";

grant trigger on table "public"."master_workshop_types" to "authenticated";

grant truncate on table "public"."master_workshop_types" to "authenticated";

grant update on table "public"."master_workshop_types" to "authenticated";

grant delete on table "public"."master_workshop_types" to "service_role";

grant insert on table "public"."master_workshop_types" to "service_role";

grant references on table "public"."master_workshop_types" to "service_role";

grant select on table "public"."master_workshop_types" to "service_role";

grant trigger on table "public"."master_workshop_types" to "service_role";

grant truncate on table "public"."master_workshop_types" to "service_role";

grant update on table "public"."master_workshop_types" to "service_role";

grant delete on table "public"."notification_deliveries" to "anon";

grant insert on table "public"."notification_deliveries" to "anon";

grant references on table "public"."notification_deliveries" to "anon";

grant select on table "public"."notification_deliveries" to "anon";

grant trigger on table "public"."notification_deliveries" to "anon";

grant truncate on table "public"."notification_deliveries" to "anon";

grant update on table "public"."notification_deliveries" to "anon";

grant delete on table "public"."notification_deliveries" to "authenticated";

grant insert on table "public"."notification_deliveries" to "authenticated";

grant references on table "public"."notification_deliveries" to "authenticated";

grant select on table "public"."notification_deliveries" to "authenticated";

grant trigger on table "public"."notification_deliveries" to "authenticated";

grant truncate on table "public"."notification_deliveries" to "authenticated";

grant update on table "public"."notification_deliveries" to "authenticated";

grant delete on table "public"."notification_deliveries" to "service_role";

grant insert on table "public"."notification_deliveries" to "service_role";

grant references on table "public"."notification_deliveries" to "service_role";

grant select on table "public"."notification_deliveries" to "service_role";

grant trigger on table "public"."notification_deliveries" to "service_role";

grant truncate on table "public"."notification_deliveries" to "service_role";

grant update on table "public"."notification_deliveries" to "service_role";

grant delete on table "public"."notification_preferences" to "anon";

grant insert on table "public"."notification_preferences" to "anon";

grant references on table "public"."notification_preferences" to "anon";

grant select on table "public"."notification_preferences" to "anon";

grant trigger on table "public"."notification_preferences" to "anon";

grant truncate on table "public"."notification_preferences" to "anon";

grant update on table "public"."notification_preferences" to "anon";

grant delete on table "public"."notification_preferences" to "authenticated";

grant insert on table "public"."notification_preferences" to "authenticated";

grant references on table "public"."notification_preferences" to "authenticated";

grant select on table "public"."notification_preferences" to "authenticated";

grant trigger on table "public"."notification_preferences" to "authenticated";

grant truncate on table "public"."notification_preferences" to "authenticated";

grant update on table "public"."notification_preferences" to "authenticated";

grant delete on table "public"."notification_preferences" to "service_role";

grant insert on table "public"."notification_preferences" to "service_role";

grant references on table "public"."notification_preferences" to "service_role";

grant select on table "public"."notification_preferences" to "service_role";

grant trigger on table "public"."notification_preferences" to "service_role";

grant truncate on table "public"."notification_preferences" to "service_role";

grant update on table "public"."notification_preferences" to "service_role";

grant delete on table "public"."notification_templates" to "anon";

grant insert on table "public"."notification_templates" to "anon";

grant references on table "public"."notification_templates" to "anon";

grant select on table "public"."notification_templates" to "anon";

grant trigger on table "public"."notification_templates" to "anon";

grant truncate on table "public"."notification_templates" to "anon";

grant update on table "public"."notification_templates" to "anon";

grant delete on table "public"."notification_templates" to "authenticated";

grant insert on table "public"."notification_templates" to "authenticated";

grant references on table "public"."notification_templates" to "authenticated";

grant select on table "public"."notification_templates" to "authenticated";

grant trigger on table "public"."notification_templates" to "authenticated";

grant truncate on table "public"."notification_templates" to "authenticated";

grant update on table "public"."notification_templates" to "authenticated";

grant delete on table "public"."notification_templates" to "service_role";

grant insert on table "public"."notification_templates" to "service_role";

grant references on table "public"."notification_templates" to "service_role";

grant select on table "public"."notification_templates" to "service_role";

grant trigger on table "public"."notification_templates" to "service_role";

grant truncate on table "public"."notification_templates" to "service_role";

grant update on table "public"."notification_templates" to "service_role";

grant delete on table "public"."notifications" to "anon";

grant insert on table "public"."notifications" to "anon";

grant references on table "public"."notifications" to "anon";

grant select on table "public"."notifications" to "anon";

grant trigger on table "public"."notifications" to "anon";

grant truncate on table "public"."notifications" to "anon";

grant update on table "public"."notifications" to "anon";

grant delete on table "public"."notifications" to "authenticated";

grant insert on table "public"."notifications" to "authenticated";

grant references on table "public"."notifications" to "authenticated";

grant select on table "public"."notifications" to "authenticated";

grant trigger on table "public"."notifications" to "authenticated";

grant truncate on table "public"."notifications" to "authenticated";

grant update on table "public"."notifications" to "authenticated";

grant delete on table "public"."notifications" to "service_role";

grant insert on table "public"."notifications" to "service_role";

grant references on table "public"."notifications" to "service_role";

grant select on table "public"."notifications" to "service_role";

grant trigger on table "public"."notifications" to "service_role";

grant truncate on table "public"."notifications" to "service_role";

grant update on table "public"."notifications" to "service_role";

grant delete on table "public"."processes" to "anon";

grant insert on table "public"."processes" to "anon";

grant references on table "public"."processes" to "anon";

grant select on table "public"."processes" to "anon";

grant trigger on table "public"."processes" to "anon";

grant truncate on table "public"."processes" to "anon";

grant update on table "public"."processes" to "anon";

grant delete on table "public"."processes" to "authenticated";

grant insert on table "public"."processes" to "authenticated";

grant references on table "public"."processes" to "authenticated";

grant select on table "public"."processes" to "authenticated";

grant trigger on table "public"."processes" to "authenticated";

grant truncate on table "public"."processes" to "authenticated";

grant update on table "public"."processes" to "authenticated";

grant delete on table "public"."processes" to "service_role";

grant insert on table "public"."processes" to "service_role";

grant references on table "public"."processes" to "service_role";

grant select on table "public"."processes" to "service_role";

grant trigger on table "public"."processes" to "service_role";

grant truncate on table "public"."processes" to "service_role";

grant update on table "public"."processes" to "service_role";

grant delete on table "public"."roles" to "anon";

grant insert on table "public"."roles" to "anon";

grant references on table "public"."roles" to "anon";

grant select on table "public"."roles" to "anon";

grant trigger on table "public"."roles" to "anon";

grant truncate on table "public"."roles" to "anon";

grant update on table "public"."roles" to "anon";

grant delete on table "public"."roles" to "authenticated";

grant insert on table "public"."roles" to "authenticated";

grant references on table "public"."roles" to "authenticated";

grant select on table "public"."roles" to "authenticated";

grant trigger on table "public"."roles" to "authenticated";

grant truncate on table "public"."roles" to "authenticated";

grant update on table "public"."roles" to "authenticated";

grant delete on table "public"."roles" to "service_role";

grant insert on table "public"."roles" to "service_role";

grant references on table "public"."roles" to "service_role";

grant select on table "public"."roles" to "service_role";

grant trigger on table "public"."roles" to "service_role";

grant truncate on table "public"."roles" to "service_role";

grant update on table "public"."roles" to "service_role";

grant delete on table "public"."scheduled_workshops" to "anon";

grant insert on table "public"."scheduled_workshops" to "anon";

grant references on table "public"."scheduled_workshops" to "anon";

grant select on table "public"."scheduled_workshops" to "anon";

grant trigger on table "public"."scheduled_workshops" to "anon";

grant truncate on table "public"."scheduled_workshops" to "anon";

grant update on table "public"."scheduled_workshops" to "anon";

grant delete on table "public"."scheduled_workshops" to "authenticated";

grant insert on table "public"."scheduled_workshops" to "authenticated";

grant references on table "public"."scheduled_workshops" to "authenticated";

grant select on table "public"."scheduled_workshops" to "authenticated";

grant trigger on table "public"."scheduled_workshops" to "authenticated";

grant truncate on table "public"."scheduled_workshops" to "authenticated";

grant update on table "public"."scheduled_workshops" to "authenticated";

grant delete on table "public"."scheduled_workshops" to "service_role";

grant insert on table "public"."scheduled_workshops" to "service_role";

grant references on table "public"."scheduled_workshops" to "service_role";

grant select on table "public"."scheduled_workshops" to "service_role";

grant trigger on table "public"."scheduled_workshops" to "service_role";

grant truncate on table "public"."scheduled_workshops" to "service_role";

grant update on table "public"."scheduled_workshops" to "service_role";

grant delete on table "public"."seasons" to "anon";

grant insert on table "public"."seasons" to "anon";

grant references on table "public"."seasons" to "anon";

grant select on table "public"."seasons" to "anon";

grant trigger on table "public"."seasons" to "anon";

grant truncate on table "public"."seasons" to "anon";

grant update on table "public"."seasons" to "anon";

grant delete on table "public"."seasons" to "authenticated";

grant insert on table "public"."seasons" to "authenticated";

grant references on table "public"."seasons" to "authenticated";

grant select on table "public"."seasons" to "authenticated";

grant trigger on table "public"."seasons" to "authenticated";

grant truncate on table "public"."seasons" to "authenticated";

grant update on table "public"."seasons" to "authenticated";

grant delete on table "public"."seasons" to "service_role";

grant insert on table "public"."seasons" to "service_role";

grant references on table "public"."seasons" to "service_role";

grant select on table "public"."seasons" to "service_role";

grant trigger on table "public"."seasons" to "service_role";

grant truncate on table "public"."seasons" to "service_role";

grant update on table "public"."seasons" to "service_role";

grant delete on table "public"."strapi_migrations" to "anon";

grant insert on table "public"."strapi_migrations" to "anon";

grant references on table "public"."strapi_migrations" to "anon";

grant select on table "public"."strapi_migrations" to "anon";

grant trigger on table "public"."strapi_migrations" to "anon";

grant truncate on table "public"."strapi_migrations" to "anon";

grant update on table "public"."strapi_migrations" to "anon";

grant delete on table "public"."strapi_migrations" to "authenticated";

grant insert on table "public"."strapi_migrations" to "authenticated";

grant references on table "public"."strapi_migrations" to "authenticated";

grant select on table "public"."strapi_migrations" to "authenticated";

grant trigger on table "public"."strapi_migrations" to "authenticated";

grant truncate on table "public"."strapi_migrations" to "authenticated";

grant update on table "public"."strapi_migrations" to "authenticated";

grant delete on table "public"."strapi_migrations" to "service_role";

grant insert on table "public"."strapi_migrations" to "service_role";

grant references on table "public"."strapi_migrations" to "service_role";

grant select on table "public"."strapi_migrations" to "service_role";

grant trigger on table "public"."strapi_migrations" to "service_role";

grant truncate on table "public"."strapi_migrations" to "service_role";

grant update on table "public"."strapi_migrations" to "service_role";

grant delete on table "public"."student_attendance" to "anon";

grant insert on table "public"."student_attendance" to "anon";

grant references on table "public"."student_attendance" to "anon";

grant select on table "public"."student_attendance" to "anon";

grant trigger on table "public"."student_attendance" to "anon";

grant truncate on table "public"."student_attendance" to "anon";

grant update on table "public"."student_attendance" to "anon";

grant delete on table "public"."student_attendance" to "authenticated";

grant insert on table "public"."student_attendance" to "authenticated";

grant references on table "public"."student_attendance" to "authenticated";

grant select on table "public"."student_attendance" to "authenticated";

grant trigger on table "public"."student_attendance" to "authenticated";

grant truncate on table "public"."student_attendance" to "authenticated";

grant update on table "public"."student_attendance" to "authenticated";

grant delete on table "public"."student_attendance" to "service_role";

grant insert on table "public"."student_attendance" to "service_role";

grant references on table "public"."student_attendance" to "service_role";

grant select on table "public"."student_attendance" to "service_role";

grant trigger on table "public"."student_attendance" to "service_role";

grant truncate on table "public"."student_attendance" to "service_role";

grant update on table "public"."student_attendance" to "service_role";

grant delete on table "public"."students" to "anon";

grant insert on table "public"."students" to "anon";

grant references on table "public"."students" to "anon";

grant select on table "public"."students" to "anon";

grant trigger on table "public"."students" to "anon";

grant truncate on table "public"."students" to "anon";

grant update on table "public"."students" to "anon";

grant delete on table "public"."students" to "authenticated";

grant insert on table "public"."students" to "authenticated";

grant references on table "public"."students" to "authenticated";

grant select on table "public"."students" to "authenticated";

grant trigger on table "public"."students" to "authenticated";

grant truncate on table "public"."students" to "authenticated";

grant update on table "public"."students" to "authenticated";

grant delete on table "public"."students" to "service_role";

grant insert on table "public"."students" to "service_role";

grant references on table "public"."students" to "service_role";

grant select on table "public"."students" to "service_role";

grant trigger on table "public"."students" to "service_role";

grant truncate on table "public"."students" to "service_role";

grant update on table "public"."students" to "service_role";

grant delete on table "public"."user_search_index" to "anon";

grant insert on table "public"."user_search_index" to "anon";

grant references on table "public"."user_search_index" to "anon";

grant select on table "public"."user_search_index" to "anon";

grant trigger on table "public"."user_search_index" to "anon";

grant truncate on table "public"."user_search_index" to "anon";

grant update on table "public"."user_search_index" to "anon";

grant delete on table "public"."user_search_index" to "authenticated";

grant insert on table "public"."user_search_index" to "authenticated";

grant references on table "public"."user_search_index" to "authenticated";

grant select on table "public"."user_search_index" to "authenticated";

grant trigger on table "public"."user_search_index" to "authenticated";

grant truncate on table "public"."user_search_index" to "authenticated";

grant update on table "public"."user_search_index" to "authenticated";

grant delete on table "public"."user_search_index" to "service_role";

grant insert on table "public"."user_search_index" to "service_role";

grant references on table "public"."user_search_index" to "service_role";

grant select on table "public"."user_search_index" to "service_role";

grant trigger on table "public"."user_search_index" to "service_role";

grant truncate on table "public"."user_search_index" to "service_role";

grant update on table "public"."user_search_index" to "service_role";

grant delete on table "public"."workflow_action_history" to "anon";

grant insert on table "public"."workflow_action_history" to "anon";

grant references on table "public"."workflow_action_history" to "anon";

grant select on table "public"."workflow_action_history" to "anon";

grant trigger on table "public"."workflow_action_history" to "anon";

grant truncate on table "public"."workflow_action_history" to "anon";

grant update on table "public"."workflow_action_history" to "anon";

grant delete on table "public"."workflow_action_history" to "authenticated";

grant insert on table "public"."workflow_action_history" to "authenticated";

grant references on table "public"."workflow_action_history" to "authenticated";

grant select on table "public"."workflow_action_history" to "authenticated";

grant trigger on table "public"."workflow_action_history" to "authenticated";

grant truncate on table "public"."workflow_action_history" to "authenticated";

grant update on table "public"."workflow_action_history" to "authenticated";

grant delete on table "public"."workflow_action_history" to "service_role";

grant insert on table "public"."workflow_action_history" to "service_role";

grant references on table "public"."workflow_action_history" to "service_role";

grant select on table "public"."workflow_action_history" to "service_role";

grant trigger on table "public"."workflow_action_history" to "service_role";

grant truncate on table "public"."workflow_action_history" to "service_role";

grant update on table "public"."workflow_action_history" to "service_role";

grant delete on table "public"."workflow_action_role_assignments" to "anon";

grant insert on table "public"."workflow_action_role_assignments" to "anon";

grant references on table "public"."workflow_action_role_assignments" to "anon";

grant select on table "public"."workflow_action_role_assignments" to "anon";

grant trigger on table "public"."workflow_action_role_assignments" to "anon";

grant truncate on table "public"."workflow_action_role_assignments" to "anon";

grant update on table "public"."workflow_action_role_assignments" to "anon";

grant delete on table "public"."workflow_action_role_assignments" to "authenticated";

grant insert on table "public"."workflow_action_role_assignments" to "authenticated";

grant references on table "public"."workflow_action_role_assignments" to "authenticated";

grant select on table "public"."workflow_action_role_assignments" to "authenticated";

grant trigger on table "public"."workflow_action_role_assignments" to "authenticated";

grant truncate on table "public"."workflow_action_role_assignments" to "authenticated";

grant update on table "public"."workflow_action_role_assignments" to "authenticated";

grant delete on table "public"."workflow_action_role_assignments" to "service_role";

grant insert on table "public"."workflow_action_role_assignments" to "service_role";

grant references on table "public"."workflow_action_role_assignments" to "service_role";

grant select on table "public"."workflow_action_role_assignments" to "service_role";

grant trigger on table "public"."workflow_action_role_assignments" to "service_role";

grant truncate on table "public"."workflow_action_role_assignments" to "service_role";

grant update on table "public"."workflow_action_role_assignments" to "service_role";

grant delete on table "public"."workflow_actions" to "anon";

grant insert on table "public"."workflow_actions" to "anon";

grant references on table "public"."workflow_actions" to "anon";

grant select on table "public"."workflow_actions" to "anon";

grant trigger on table "public"."workflow_actions" to "anon";

grant truncate on table "public"."workflow_actions" to "anon";

grant update on table "public"."workflow_actions" to "anon";

grant delete on table "public"."workflow_actions" to "authenticated";

grant insert on table "public"."workflow_actions" to "authenticated";

grant references on table "public"."workflow_actions" to "authenticated";

grant select on table "public"."workflow_actions" to "authenticated";

grant trigger on table "public"."workflow_actions" to "authenticated";

grant truncate on table "public"."workflow_actions" to "authenticated";

grant update on table "public"."workflow_actions" to "authenticated";

grant delete on table "public"."workflow_actions" to "service_role";

grant insert on table "public"."workflow_actions" to "service_role";

grant references on table "public"."workflow_actions" to "service_role";

grant select on table "public"."workflow_actions" to "service_role";

grant trigger on table "public"."workflow_actions" to "service_role";

grant truncate on table "public"."workflow_actions" to "service_role";

grant update on table "public"."workflow_actions" to "service_role";

grant delete on table "public"."workflow_instances" to "anon";

grant insert on table "public"."workflow_instances" to "anon";

grant references on table "public"."workflow_instances" to "anon";

grant select on table "public"."workflow_instances" to "anon";

grant trigger on table "public"."workflow_instances" to "anon";

grant truncate on table "public"."workflow_instances" to "anon";

grant update on table "public"."workflow_instances" to "anon";

grant delete on table "public"."workflow_instances" to "authenticated";

grant insert on table "public"."workflow_instances" to "authenticated";

grant references on table "public"."workflow_instances" to "authenticated";

grant select on table "public"."workflow_instances" to "authenticated";

grant trigger on table "public"."workflow_instances" to "authenticated";

grant truncate on table "public"."workflow_instances" to "authenticated";

grant update on table "public"."workflow_instances" to "authenticated";

grant delete on table "public"."workflow_instances" to "service_role";

grant insert on table "public"."workflow_instances" to "service_role";

grant references on table "public"."workflow_instances" to "service_role";

grant select on table "public"."workflow_instances" to "service_role";

grant trigger on table "public"."workflow_instances" to "service_role";

grant truncate on table "public"."workflow_instances" to "service_role";

grant update on table "public"."workflow_instances" to "service_role";

grant delete on table "public"."workflow_notifications" to "anon";

grant insert on table "public"."workflow_notifications" to "anon";

grant references on table "public"."workflow_notifications" to "anon";

grant select on table "public"."workflow_notifications" to "anon";

grant trigger on table "public"."workflow_notifications" to "anon";

grant truncate on table "public"."workflow_notifications" to "anon";

grant update on table "public"."workflow_notifications" to "anon";

grant delete on table "public"."workflow_notifications" to "authenticated";

grant insert on table "public"."workflow_notifications" to "authenticated";

grant references on table "public"."workflow_notifications" to "authenticated";

grant select on table "public"."workflow_notifications" to "authenticated";

grant trigger on table "public"."workflow_notifications" to "authenticated";

grant truncate on table "public"."workflow_notifications" to "authenticated";

grant update on table "public"."workflow_notifications" to "authenticated";

grant delete on table "public"."workflow_notifications" to "service_role";

grant insert on table "public"."workflow_notifications" to "service_role";

grant references on table "public"."workflow_notifications" to "service_role";

grant select on table "public"."workflow_notifications" to "service_role";

grant trigger on table "public"."workflow_notifications" to "service_role";

grant truncate on table "public"."workflow_notifications" to "service_role";

grant update on table "public"."workflow_notifications" to "service_role";

grant delete on table "public"."workflow_stage_instances" to "anon";

grant insert on table "public"."workflow_stage_instances" to "anon";

grant references on table "public"."workflow_stage_instances" to "anon";

grant select on table "public"."workflow_stage_instances" to "anon";

grant trigger on table "public"."workflow_stage_instances" to "anon";

grant truncate on table "public"."workflow_stage_instances" to "anon";

grant update on table "public"."workflow_stage_instances" to "anon";

grant delete on table "public"."workflow_stage_instances" to "authenticated";

grant insert on table "public"."workflow_stage_instances" to "authenticated";

grant references on table "public"."workflow_stage_instances" to "authenticated";

grant select on table "public"."workflow_stage_instances" to "authenticated";

grant trigger on table "public"."workflow_stage_instances" to "authenticated";

grant truncate on table "public"."workflow_stage_instances" to "authenticated";

grant update on table "public"."workflow_stage_instances" to "authenticated";

grant delete on table "public"."workflow_stage_instances" to "service_role";

grant insert on table "public"."workflow_stage_instances" to "service_role";

grant references on table "public"."workflow_stage_instances" to "service_role";

grant select on table "public"."workflow_stage_instances" to "service_role";

grant trigger on table "public"."workflow_stage_instances" to "service_role";

grant truncate on table "public"."workflow_stage_instances" to "service_role";

grant update on table "public"."workflow_stage_instances" to "service_role";

grant delete on table "public"."workflow_template_permissions" to "anon";

grant insert on table "public"."workflow_template_permissions" to "anon";

grant references on table "public"."workflow_template_permissions" to "anon";

grant select on table "public"."workflow_template_permissions" to "anon";

grant trigger on table "public"."workflow_template_permissions" to "anon";

grant truncate on table "public"."workflow_template_permissions" to "anon";

grant update on table "public"."workflow_template_permissions" to "anon";

grant delete on table "public"."workflow_template_permissions" to "authenticated";

grant insert on table "public"."workflow_template_permissions" to "authenticated";

grant references on table "public"."workflow_template_permissions" to "authenticated";

grant select on table "public"."workflow_template_permissions" to "authenticated";

grant trigger on table "public"."workflow_template_permissions" to "authenticated";

grant truncate on table "public"."workflow_template_permissions" to "authenticated";

grant update on table "public"."workflow_template_permissions" to "authenticated";

grant delete on table "public"."workflow_template_permissions" to "service_role";

grant insert on table "public"."workflow_template_permissions" to "service_role";

grant references on table "public"."workflow_template_permissions" to "service_role";

grant select on table "public"."workflow_template_permissions" to "service_role";

grant trigger on table "public"."workflow_template_permissions" to "service_role";

grant truncate on table "public"."workflow_template_permissions" to "service_role";

grant update on table "public"."workflow_template_permissions" to "service_role";

grant delete on table "public"."workflow_template_stages" to "anon";

grant insert on table "public"."workflow_template_stages" to "anon";

grant references on table "public"."workflow_template_stages" to "anon";

grant select on table "public"."workflow_template_stages" to "anon";

grant trigger on table "public"."workflow_template_stages" to "anon";

grant truncate on table "public"."workflow_template_stages" to "anon";

grant update on table "public"."workflow_template_stages" to "anon";

grant delete on table "public"."workflow_template_stages" to "authenticated";

grant insert on table "public"."workflow_template_stages" to "authenticated";

grant references on table "public"."workflow_template_stages" to "authenticated";

grant select on table "public"."workflow_template_stages" to "authenticated";

grant trigger on table "public"."workflow_template_stages" to "authenticated";

grant truncate on table "public"."workflow_template_stages" to "authenticated";

grant update on table "public"."workflow_template_stages" to "authenticated";

grant delete on table "public"."workflow_template_stages" to "service_role";

grant insert on table "public"."workflow_template_stages" to "service_role";

grant references on table "public"."workflow_template_stages" to "service_role";

grant select on table "public"."workflow_template_stages" to "service_role";

grant trigger on table "public"."workflow_template_stages" to "service_role";

grant truncate on table "public"."workflow_template_stages" to "service_role";

grant update on table "public"."workflow_template_stages" to "service_role";

grant delete on table "public"."workflow_templates" to "anon";

grant insert on table "public"."workflow_templates" to "anon";

grant references on table "public"."workflow_templates" to "anon";

grant select on table "public"."workflow_templates" to "anon";

grant trigger on table "public"."workflow_templates" to "anon";

grant truncate on table "public"."workflow_templates" to "anon";

grant update on table "public"."workflow_templates" to "anon";

grant delete on table "public"."workflow_templates" to "authenticated";

grant insert on table "public"."workflow_templates" to "authenticated";

grant references on table "public"."workflow_templates" to "authenticated";

grant select on table "public"."workflow_templates" to "authenticated";

grant trigger on table "public"."workflow_templates" to "authenticated";

grant truncate on table "public"."workflow_templates" to "authenticated";

grant update on table "public"."workflow_templates" to "authenticated";

grant delete on table "public"."workflow_templates" to "service_role";

grant insert on table "public"."workflow_templates" to "service_role";

grant references on table "public"."workflow_templates" to "service_role";

grant select on table "public"."workflow_templates" to "service_role";

grant trigger on table "public"."workflow_templates" to "service_role";

grant truncate on table "public"."workflow_templates" to "service_role";

grant update on table "public"."workflow_templates" to "service_role";

grant delete on table "public"."workflow_transitions" to "anon";

grant insert on table "public"."workflow_transitions" to "anon";

grant references on table "public"."workflow_transitions" to "anon";

grant select on table "public"."workflow_transitions" to "anon";

grant trigger on table "public"."workflow_transitions" to "anon";

grant truncate on table "public"."workflow_transitions" to "anon";

grant update on table "public"."workflow_transitions" to "anon";

grant delete on table "public"."workflow_transitions" to "authenticated";

grant insert on table "public"."workflow_transitions" to "authenticated";

grant references on table "public"."workflow_transitions" to "authenticated";

grant select on table "public"."workflow_transitions" to "authenticated";

grant trigger on table "public"."workflow_transitions" to "authenticated";

grant truncate on table "public"."workflow_transitions" to "authenticated";

grant update on table "public"."workflow_transitions" to "authenticated";

grant delete on table "public"."workflow_transitions" to "service_role";

grant insert on table "public"."workflow_transitions" to "service_role";

grant references on table "public"."workflow_transitions" to "service_role";

grant select on table "public"."workflow_transitions" to "service_role";

grant trigger on table "public"."workflow_transitions" to "service_role";

grant truncate on table "public"."workflow_transitions" to "service_role";

grant update on table "public"."workflow_transitions" to "service_role";

create policy "agreements_delete_admin"
on "public"."agreements"
as permissive
for delete
to public
using (fn_is_general_director_or_higher());


create policy "agreements_insert_anon_prospect"
on "public"."agreements"
as permissive
for insert
to anon, authenticated
with check ((status = 'prospect'::text));


create policy "agreements_select_own_hq_high"
on "public"."agreements"
as permissive
for select
to public
using (((user_id = ( SELECT auth.uid() AS uid)) OR fn_is_local_manager_or_higher()));


create policy "agreements_update_permissions"
on "public"."agreements"
as permissive
for update
to public
using (((user_id = ( SELECT auth.uid() AS uid)) OR fn_is_general_director_or_higher() OR (fn_is_local_manager_or_higher() AND fn_is_current_user_hq_equal_to(headquarter_id))))
with check ((((user_id = user_id) AND (headquarter_id = headquarter_id) AND (email = email) AND fn_is_general_director_or_higher()) OR ((user_id = ( SELECT auth.uid() AS uid)) AND (NOT fn_is_general_director_or_higher()) AND (role_id = role_id)) OR ((user_id <> ( SELECT auth.uid() AS uid)) AND fn_is_local_manager_or_higher() AND (NOT fn_is_general_director_or_higher()) AND (NOT (EXISTS ( SELECT 1
   FROM roles
  WHERE ((roles.id = agreements.role_id) AND (roles.level >= 95))))))));


create policy "audit_delete_high_level"
on "public"."audit_log"
as permissive
for delete
to authenticated
using (fn_is_general_director_or_higher());


create policy "audit_insert_high_level"
on "public"."audit_log"
as permissive
for insert
to authenticated
with check (fn_is_general_director_or_higher());


create policy "audit_select_high_level"
on "public"."audit_log"
as permissive
for select
to authenticated
using (fn_is_general_director_or_higher());


create policy "audit_update_high_level"
on "public"."audit_log"
as permissive
for update
to authenticated
using (fn_is_general_director_or_higher())
with check (fn_is_general_director_or_higher());


create policy "collaborators_insert_manager_director"
on "public"."collaborators"
as permissive
for insert
to public
with check (((fn_is_local_manager_or_higher() AND fn_is_current_user_hq_equal_to(headquarter_id)) OR fn_is_general_director_or_higher()));


create policy "collaborators_select_self_hq_high"
on "public"."collaborators"
as permissive
for select
to public
using (((user_id = ( SELECT auth.uid() AS uid)) OR (fn_is_local_manager_or_higher() AND fn_is_current_user_hq_equal_to(headquarter_id)) OR fn_is_general_director_or_higher()));


create policy "collaborators_update_self_manager_director"
on "public"."collaborators"
as permissive
for update
to public
using (((user_id = ( SELECT auth.uid() AS uid)) OR (fn_is_local_manager_or_higher() AND fn_is_current_user_hq_equal_to(headquarter_id)) OR fn_is_general_director_or_higher()))
with check (((user_id = ( SELECT auth.uid() AS uid)) OR (fn_is_local_manager_or_higher() AND fn_is_current_user_hq_equal_to(headquarter_id) AND (( SELECT roles.level
   FROM roles
  WHERE (roles.id = collaborators.role_id)) < 95)) OR fn_is_general_director_or_higher()));


create policy "general_director_can_delete_collaborators"
on "public"."collaborators"
as permissive
for delete
to public
using (fn_is_general_director_or_higher());


create policy "delete_companion_map"
on "public"."companion_student_map"
as permissive
for delete
to public
using (((fn_is_manager_assistant_or_higher() AND (headquarter_id = fn_get_current_hq_id())) OR fn_is_general_director_or_higher()));


create policy "insert_companion_map"
on "public"."companion_student_map"
as permissive
for insert
to public
with check (((fn_is_manager_assistant_or_higher() AND (headquarter_id = fn_get_current_hq_id())) OR fn_is_general_director_or_higher()));


create policy "select_companion_map"
on "public"."companion_student_map"
as permissive
for select
to public
using (((( SELECT auth.uid() AS uid) = companion_id) OR (fn_is_manager_assistant_or_higher() AND (headquarter_id = fn_get_current_hq_id())) OR fn_is_general_director_or_higher()));


create policy "update_companion_map"
on "public"."companion_student_map"
as permissive
for update
to public
using (((fn_is_manager_assistant_or_higher() AND (headquarter_id = fn_get_current_hq_id())) OR fn_is_general_director_or_higher()))
with check ((((headquarter_id = headquarter_id) AND (season_id = season_id)) OR fn_is_general_director_or_higher()));


create policy "Allow authenticated users to view countries"
on "public"."countries"
as permissive
for select
to authenticated
using (true);


create policy "Allow super admin to delete countries"
on "public"."countries"
as permissive
for delete
to authenticated
using (fn_is_super_admin());


create policy "Allow super admin to insert countries"
on "public"."countries"
as permissive
for insert
to authenticated
with check (fn_is_super_admin());


create policy "Allow super admin to update countries"
on "public"."countries"
as permissive
for update
to authenticated
using (fn_is_super_admin())
with check (fn_is_super_admin());


create policy "event_types_delete_high_level"
on "public"."event_types"
as permissive
for delete
to public
using (fn_is_konsejo_member_or_higher());


create policy "event_types_insert_high_level"
on "public"."event_types"
as permissive
for insert
to public
with check (fn_is_konsejo_member_or_higher());


create policy "event_types_select_authenticated"
on "public"."event_types"
as permissive
for select
to authenticated
using (true);


create policy "event_types_update_high_level"
on "public"."event_types"
as permissive
for update
to public
using (fn_is_konsejo_member_or_higher())
with check (fn_is_konsejo_member_or_higher());


create policy "events_delete_director"
on "public"."events"
as permissive
for delete
to public
using (fn_is_general_director_or_higher());


create policy "events_insert_collaborator_konsejo"
on "public"."events"
as permissive
for insert
to public
with check (((fn_is_collaborator_or_higher() AND (headquarter_id = fn_get_current_hq_id())) OR fn_is_konsejo_member_or_higher()));


create policy "events_select_auth_hq"
on "public"."events"
as permissive
for select
to authenticated
using (((headquarter_id = fn_get_current_hq_id()) OR fn_is_konsejo_member_or_higher()));


create policy "events_update_collaborator_konsejo"
on "public"."events"
as permissive
for update
to public
using (((fn_is_collaborator_or_higher() AND (headquarter_id = fn_get_current_hq_id())) OR fn_is_konsejo_member_or_higher()))
with check ((((headquarter_id = headquarter_id) AND (season_id = season_id)) OR fn_is_konsejo_member_or_higher()));


create policy "delete_facilitator_map"
on "public"."facilitator_workshop_map"
as permissive
for delete
to public
using (((fn_is_manager_assistant_or_higher() AND (headquarter_id = fn_get_current_hq_id())) OR fn_is_general_director_or_higher()));


create policy "insert_facilitator_map"
on "public"."facilitator_workshop_map"
as permissive
for insert
to public
with check (((fn_is_manager_assistant_or_higher() AND (headquarter_id = fn_get_current_hq_id())) OR fn_is_general_director_or_higher()));


create policy "select_facilitator_map"
on "public"."facilitator_workshop_map"
as permissive
for select
to public
using (((( SELECT auth.uid() AS uid) = facilitator_id) OR (fn_is_manager_assistant_or_higher() AND (headquarter_id = fn_get_current_hq_id())) OR fn_is_general_director_or_higher()));


create policy "update_facilitator_map"
on "public"."facilitator_workshop_map"
as permissive
for update
to public
using (((fn_is_manager_assistant_or_higher() AND (headquarter_id = fn_get_current_hq_id())) OR fn_is_general_director_or_higher()))
with check ((((headquarter_id = headquarter_id) AND (season_id = season_id)) OR fn_is_general_director_or_higher()));


create policy "hq_delete_high_level"
on "public"."headquarters"
as permissive
for delete
to authenticated
using (fn_is_general_director_or_higher());


create policy "hq_insert_high_level"
on "public"."headquarters"
as permissive
for insert
to authenticated
with check (fn_is_general_director_or_higher());


create policy "hq_select_auth"
on "public"."headquarters"
as permissive
for select
to authenticated
using ((true OR fn_is_general_director_or_higher()));


create policy "hq_update_high_level"
on "public"."headquarters"
as permissive
for update
to authenticated
using (fn_is_general_director_or_higher())
with check (fn_is_general_director_or_higher());


create policy "master_workshop_types_delete_superadmin"
on "public"."master_workshop_types"
as permissive
for delete
to authenticated
using (fn_is_general_director_or_higher());


create policy "master_workshop_types_insert_superadmin"
on "public"."master_workshop_types"
as permissive
for insert
to authenticated
with check (fn_is_general_director_or_higher());


create policy "master_workshop_types_select_auth"
on "public"."master_workshop_types"
as permissive
for select
to authenticated
using (true);


create policy "master_workshop_types_update_superadmin"
on "public"."master_workshop_types"
as permissive
for update
to authenticated
using (fn_is_general_director_or_higher())
with check (fn_is_general_director_or_higher());


create policy "Users can manage their preferences"
on "public"."notification_preferences"
as permissive
for all
to authenticated
using ((user_id = auth.uid()))
with check ((user_id = auth.uid()));


create policy "Admins can manage notification templates"
on "public"."notification_templates"
as permissive
for all
to authenticated
using (fn_is_konsejo_member_or_higher())
with check (fn_is_konsejo_member_or_higher());


create policy "Users can view active templates"
on "public"."notification_templates"
as permissive
for select
to authenticated
using ((is_active = true));


create policy "System can create notifications"
on "public"."notifications"
as permissive
for insert
to authenticated
with check ((((type = 'direct_message'::notification_type) AND (sender_id = auth.uid())) OR (fn_get_current_role_level() >= 80)));


create policy "Users can update their own notifications"
on "public"."notifications"
as permissive
for update
to authenticated
using ((recipient_id = auth.uid()))
with check ((recipient_id = auth.uid()));


create policy "Users can view their own notifications"
on "public"."notifications"
as permissive
for select
to authenticated
using ((recipient_id = auth.uid()));


create policy "Allow authenticated users to view processes"
on "public"."processes"
as permissive
for select
to authenticated
using (true);


create policy "processes_delete_high_level"
on "public"."processes"
as permissive
for delete
to authenticated
using (fn_is_general_director_or_higher());


create policy "processes_insert_high_level"
on "public"."processes"
as permissive
for insert
to authenticated
with check (fn_is_general_director_or_higher());


create policy "processes_update_high_level"
on "public"."processes"
as permissive
for update
to authenticated
using (fn_is_general_director_or_higher())
with check (fn_is_general_director_or_higher());


create policy "roles_delete_superadmin"
on "public"."roles"
as permissive
for delete
to authenticated
using ((fn_get_current_role_level() >= 100));


create policy "roles_insert_superadmin"
on "public"."roles"
as permissive
for insert
to authenticated
with check ((fn_get_current_role_level() >= 100));


create policy "roles_select_auth"
on "public"."roles"
as permissive
for select
to authenticated
using (true);


create policy "roles_update_superadmin"
on "public"."roles"
as permissive
for update
to authenticated
using ((fn_get_current_role_level() >= 100))
with check ((fn_get_current_role_level() >= 100));


create policy "scheduled_workshops_delete_policy"
on "public"."scheduled_workshops"
as permissive
for delete
to authenticated
using (((fn_is_manager_assistant_or_higher() AND (headquarter_id = fn_get_current_hq_id())) OR fn_is_general_director_or_higher()));


create policy "scheduled_workshops_insert_policy"
on "public"."scheduled_workshops"
as permissive
for insert
to authenticated
with check (((fn_is_manager_assistant_or_higher() AND (headquarter_id = fn_get_current_hq_id())) OR fn_is_general_director_or_higher()));


create policy "scheduled_workshops_select_policy"
on "public"."scheduled_workshops"
as permissive
for select
to authenticated
using (((facilitator_id = ( SELECT auth.uid() AS uid)) OR (fn_is_manager_assistant_or_higher() AND (headquarter_id = fn_get_current_hq_id())) OR fn_is_general_director_or_higher()));


create policy "scheduled_workshops_update_policy"
on "public"."scheduled_workshops"
as permissive
for update
to authenticated
using (((fn_is_manager_assistant_or_higher() AND (headquarter_id = fn_get_current_hq_id())) OR fn_is_general_director_or_higher()))
with check ((((headquarter_id = headquarter_id) AND (season_id = season_id) AND fn_is_manager_assistant_or_higher()) OR fn_is_general_director_or_higher()));


create policy "seasons_delete_policy"
on "public"."seasons"
as permissive
for delete
to authenticated
using (fn_is_general_director_or_higher());


create policy "seasons_insert_policy"
on "public"."seasons"
as permissive
for insert
to authenticated
with check (((fn_is_konsejo_member_or_higher() AND (headquarter_id = fn_get_current_hq_id())) OR fn_is_general_director_or_higher()));


create policy "seasons_select_policy"
on "public"."seasons"
as permissive
for select
to authenticated
using (((headquarter_id = fn_get_current_hq_id()) OR fn_is_konsejo_member_or_higher()));


create policy "seasons_update_policy"
on "public"."seasons"
as permissive
for update
to authenticated
using (((fn_is_konsejo_member_or_higher() AND (headquarter_id = fn_get_current_hq_id())) OR fn_is_general_director_or_higher()))
with check ((((headquarter_id = headquarter_id) AND fn_is_konsejo_member_or_higher()) OR fn_is_general_director_or_higher()));


create policy "Allow authenticated users to view migration history"
on "public"."strapi_migrations"
as permissive
for select
to authenticated
using (true);


create policy "Allow service role to insert migration records"
on "public"."strapi_migrations"
as permissive
for insert
to service_role
with check (true);


create policy "student_attendance_delete_policy"
on "public"."student_attendance"
as permissive
for delete
to authenticated
using (((EXISTS ( SELECT 1
   FROM scheduled_workshops sw
  WHERE ((sw.id = student_attendance.scheduled_workshop_id) AND (sw.facilitator_id = ( SELECT auth.uid() AS uid))))) OR (fn_is_manager_assistant_or_higher() AND (EXISTS ( SELECT 1
   FROM scheduled_workshops sw
  WHERE ((sw.id = student_attendance.scheduled_workshop_id) AND (sw.headquarter_id = fn_get_current_hq_id()))))) OR fn_is_general_director_or_higher()));


create policy "student_attendance_insert_policy"
on "public"."student_attendance"
as permissive
for insert
to authenticated
with check (((EXISTS ( SELECT 1
   FROM scheduled_workshops sw
  WHERE ((sw.id = student_attendance.scheduled_workshop_id) AND (sw.facilitator_id = ( SELECT auth.uid() AS uid))))) OR (fn_is_manager_assistant_or_higher() AND (EXISTS ( SELECT 1
   FROM scheduled_workshops sw
  WHERE ((sw.id = student_attendance.scheduled_workshop_id) AND (sw.headquarter_id = fn_get_current_hq_id()))))) OR fn_is_general_director_or_higher()));


create policy "student_attendance_select_policy"
on "public"."student_attendance"
as permissive
for select
to authenticated
using (((student_id = ( SELECT auth.uid() AS uid)) OR (EXISTS ( SELECT 1
   FROM scheduled_workshops sw
  WHERE ((sw.id = student_attendance.scheduled_workshop_id) AND (sw.facilitator_id = ( SELECT auth.uid() AS uid))))) OR (fn_is_manager_assistant_or_higher() AND (EXISTS ( SELECT 1
   FROM scheduled_workshops sw
  WHERE ((sw.id = student_attendance.scheduled_workshop_id) AND (sw.headquarter_id = fn_get_current_hq_id()))))) OR fn_is_general_director_or_higher()));


create policy "student_attendance_update_policy"
on "public"."student_attendance"
as permissive
for update
to authenticated
using (((EXISTS ( SELECT 1
   FROM scheduled_workshops sw
  WHERE ((sw.id = student_attendance.scheduled_workshop_id) AND (sw.facilitator_id = ( SELECT auth.uid() AS uid))))) OR (fn_is_manager_assistant_or_higher() AND (EXISTS ( SELECT 1
   FROM scheduled_workshops sw
  WHERE ((sw.id = student_attendance.scheduled_workshop_id) AND (sw.headquarter_id = fn_get_current_hq_id()))))) OR fn_is_general_director_or_higher()))
with check (((EXISTS ( SELECT 1
   FROM scheduled_workshops sw
  WHERE ((sw.id = student_attendance.scheduled_workshop_id) AND (sw.facilitator_id = ( SELECT auth.uid() AS uid))))) OR (fn_is_manager_assistant_or_higher() AND (EXISTS ( SELECT 1
   FROM scheduled_workshops sw
  WHERE ((sw.id = student_attendance.scheduled_workshop_id) AND (sw.headquarter_id = fn_get_current_hq_id()))))) OR fn_is_general_director_or_higher()));


create policy "students_delete_admin"
on "public"."students"
as permissive
for delete
to public
using ((fn_get_current_role_level() >= 100));


create policy "students_insert_manager"
on "public"."students"
as permissive
for insert
to public
with check ((fn_get_current_role_level() >= 40));


create policy "students_select_own_hq_high_mentor"
on "public"."students"
as permissive
for select
to public
using (((user_id = ( SELECT auth.uid() AS uid)) OR (fn_get_current_role_level() >= 80) OR (headquarter_id = fn_get_current_hq_id())));


create policy "students_update_manager_mentor"
on "public"."students"
as permissive
for update
to public
using ((fn_get_current_role_level() >= 40))
with check ((fn_get_current_role_level() >= 40));


create policy "Authenticated users can search users"
on "public"."user_search_index"
as permissive
for select
to authenticated
using ((is_active = true));


create policy "System can insert history records"
on "public"."workflow_action_history"
as permissive
for insert
to public
with check (true);


create policy "Users can view history of their actions"
on "public"."workflow_action_history"
as permissive
for select
to public
using ((EXISTS ( SELECT 1
   FROM workflow_actions wa
  WHERE ((wa.id = workflow_action_history.action_id) AND (wa.assigned_to = auth.uid())))));


create policy "Workflow admins can view all history"
on "public"."workflow_action_history"
as permissive
for select
to public
using (is_workflow_admin());


create policy "Workflow admins can manage role assignments"
on "public"."workflow_action_role_assignments"
as permissive
for all
to public
using (is_workflow_admin())
with check (is_workflow_admin());


create policy "Users can update their assigned actions"
on "public"."workflow_actions"
as permissive
for update
to public
using (((assigned_to = auth.uid()) AND (status = ANY (ARRAY['pending'::text, 'in_progress'::text]))))
with check ((assigned_to = auth.uid()));


create policy "Users can view actions assigned to them"
on "public"."workflow_actions"
as permissive
for select
to public
using ((assigned_to = auth.uid()));


create policy "Users can view actions in their workflows"
on "public"."workflow_actions"
as permissive
for select
to public
using ((EXISTS ( SELECT 1
   FROM (workflow_stage_instances wsi
     JOIN workflow_instances wi ON ((wsi.workflow_instance_id = wi.id)))
  WHERE ((wsi.id = workflow_actions.stage_instance_id) AND (wi.initiated_by = auth.uid())))));


create policy "Workflow admins can manage all actions"
on "public"."workflow_actions"
as permissive
for all
to public
using (is_workflow_admin())
with check (is_workflow_admin());


create policy "Users can create workflow instances with permission"
on "public"."workflow_instances"
as permissive
for insert
to authenticated
with check (((initiated_by = auth.uid()) AND can_create_workflow_from_template(template_id)));


create policy "Users can view workflows they initiated"
on "public"."workflow_instances"
as permissive
for select
to public
using ((initiated_by = auth.uid()));


create policy "Users can view workflows they participate in"
on "public"."workflow_instances"
as permissive
for select
to public
using (is_workflow_participant(id));


create policy "Workflow admins can manage all instances"
on "public"."workflow_instances"
as permissive
for all
to public
using (is_workflow_admin())
with check (is_workflow_admin());


create policy "System can create notifications"
on "public"."workflow_notifications"
as permissive
for insert
to public
with check (true);


create policy "Users can update their notifications (mark as read)"
on "public"."workflow_notifications"
as permissive
for update
to public
using ((recipient_id = auth.uid()))
with check ((recipient_id = auth.uid()));


create policy "Users can view their notifications"
on "public"."workflow_notifications"
as permissive
for select
to public
using ((recipient_id = auth.uid()));


create policy "Users can view stages of their workflows"
on "public"."workflow_stage_instances"
as permissive
for select
to public
using ((EXISTS ( SELECT 1
   FROM workflow_instances wi
  WHERE ((wi.id = workflow_stage_instances.workflow_instance_id) AND ((wi.initiated_by = auth.uid()) OR is_workflow_participant(wi.id))))));


create policy "Workflow admins can manage all stage instances"
on "public"."workflow_stage_instances"
as permissive
for all
to public
using (is_workflow_admin())
with check (is_workflow_admin());


create policy "Workflow admins can manage template permissions"
on "public"."workflow_template_permissions"
as permissive
for all
to public
using (is_workflow_admin())
with check (is_workflow_admin());


create policy "Users can view stages of active templates"
on "public"."workflow_template_stages"
as permissive
for select
to public
using ((EXISTS ( SELECT 1
   FROM workflow_templates wt
  WHERE ((wt.id = workflow_template_stages.template_id) AND (wt.is_active = true)))));


create policy "Workflow admins can manage template stages"
on "public"."workflow_template_stages"
as permissive
for all
to public
using (is_workflow_admin())
with check (is_workflow_admin());


create policy "Users can view active templates"
on "public"."workflow_templates"
as permissive
for select
to public
using ((is_active = true));


create policy "Workflow admins can manage templates"
on "public"."workflow_templates"
as permissive
for all
to public
using (is_workflow_admin())
with check (is_workflow_admin());


create policy "System can insert transition records"
on "public"."workflow_transitions"
as permissive
for insert
to public
with check (true);


create policy "Users can view transitions of their workflows"
on "public"."workflow_transitions"
as permissive
for select
to public
using ((EXISTS ( SELECT 1
   FROM workflow_instances wi
  WHERE ((wi.id = workflow_transitions.workflow_instance_id) AND ((wi.initiated_by = auth.uid()) OR is_workflow_participant(wi.id))))));


create policy "Workflow admins can view all transitions"
on "public"."workflow_transitions"
as permissive
for select
to public
using (is_workflow_admin());


CREATE TRIGGER audit_agreements AFTER INSERT OR DELETE OR UPDATE ON public.agreements FOR EACH ROW EXECUTE FUNCTION trg_audit();

CREATE TRIGGER handle_activation_date BEFORE UPDATE ON public.agreements FOR EACH ROW WHEN ((old.status IS DISTINCT FROM new.status)) EXECUTE FUNCTION set_activation_date_on_update();

CREATE TRIGGER handle_fts_name_lastname_update BEFORE INSERT OR UPDATE OF name, last_name ON public.agreements FOR EACH ROW EXECUTE FUNCTION update_fts_name_lastname();

CREATE TRIGGER handle_updated_at_agreements BEFORE UPDATE ON public.agreements FOR EACH ROW EXECUTE FUNCTION moddatetime('updated_at');

CREATE TRIGGER notify_on_user_creation AFTER UPDATE ON public.agreements FOR EACH ROW EXECUTE FUNCTION notify_user_created();

CREATE TRIGGER update_search_index_on_agreement_change AFTER INSERT OR UPDATE ON public.agreements FOR EACH ROW WHEN (((new.user_id IS NOT NULL) AND (new.status = 'active'::text))) EXECUTE FUNCTION update_user_search_index();

CREATE TRIGGER audit_collaborators AFTER INSERT OR DELETE OR UPDATE ON public.collaborators FOR EACH ROW EXECUTE FUNCTION trg_audit();

CREATE TRIGGER ensure_companion_student_hq_consistency BEFORE INSERT OR UPDATE ON public.companion_student_map FOR EACH ROW EXECUTE FUNCTION check_companion_student_hq_consistency();

CREATE TRIGGER handle_updated_at BEFORE UPDATE ON public.companion_student_map FOR EACH ROW EXECUTE FUNCTION moddatetime('updated_at');

CREATE TRIGGER audit_countries AFTER INSERT OR DELETE OR UPDATE ON public.countries FOR EACH ROW EXECUTE FUNCTION trg_audit();

CREATE TRIGGER handle_updated_at_countries BEFORE UPDATE ON public.countries FOR EACH ROW EXECUTE FUNCTION moddatetime('updated_at');

CREATE TRIGGER handle_updated_at_event_types BEFORE UPDATE ON public.event_types FOR EACH ROW EXECUTE FUNCTION moddatetime('updated_at');

CREATE TRIGGER handle_updated_at_events BEFORE UPDATE ON public.events FOR EACH ROW EXECUTE FUNCTION moddatetime('updated_at');

CREATE TRIGGER ensure_facilitator_workshop_map_consistency BEFORE INSERT OR UPDATE ON public.facilitator_workshop_map FOR EACH ROW EXECUTE FUNCTION check_facilitator_workshop_map_consistency();

CREATE TRIGGER handle_updated_at BEFORE UPDATE ON public.facilitator_workshop_map FOR EACH ROW EXECUTE FUNCTION moddatetime('updated_at');

CREATE TRIGGER audit_headquarters AFTER INSERT OR DELETE OR UPDATE ON public.headquarters FOR EACH ROW EXECUTE FUNCTION trg_audit();

CREATE TRIGGER handle_updated_at_headquarters BEFORE UPDATE ON public.headquarters FOR EACH ROW EXECUTE FUNCTION moddatetime('updated_at');

CREATE TRIGGER handle_updated_at_master_workshop_types BEFORE UPDATE ON public.master_workshop_types FOR EACH ROW EXECUTE FUNCTION moddatetime('updated_at');

CREATE TRIGGER handle_updated_at_notification_preferences BEFORE UPDATE ON public.notification_preferences FOR EACH ROW EXECUTE FUNCTION moddatetime('updated_at');

CREATE TRIGGER handle_updated_at_notification_templates BEFORE UPDATE ON public.notification_templates FOR EACH ROW EXECUTE FUNCTION moddatetime('updated_at');

CREATE TRIGGER handle_updated_at_notifications BEFORE UPDATE ON public.notifications FOR EACH ROW EXECUTE FUNCTION moddatetime('updated_at');

CREATE TRIGGER handle_updated_at_processes BEFORE UPDATE ON public.processes FOR EACH ROW EXECUTE FUNCTION moddatetime('updated_at');

CREATE TRIGGER handle_updated_at_roles BEFORE UPDATE ON public.roles FOR EACH ROW EXECUTE FUNCTION moddatetime('updated_at');

CREATE TRIGGER audit_scheduled_workshops AFTER INSERT OR DELETE OR UPDATE ON public.scheduled_workshops FOR EACH ROW EXECUTE FUNCTION trg_audit();

CREATE TRIGGER handle_updated_at_scheduled_workshops BEFORE UPDATE ON public.scheduled_workshops FOR EACH ROW EXECUTE FUNCTION moddatetime('updated_at');

CREATE TRIGGER notify_on_workshop_scheduling AFTER UPDATE ON public.scheduled_workshops FOR EACH ROW EXECUTE FUNCTION notify_workshop_reminder();

CREATE TRIGGER validate_facilitator_before_insert_update BEFORE INSERT OR UPDATE ON public.scheduled_workshops FOR EACH ROW EXECUTE FUNCTION trigger_validate_workshop_facilitator();

CREATE TRIGGER audit_seasons AFTER INSERT OR DELETE OR UPDATE ON public.seasons FOR EACH ROW EXECUTE FUNCTION trg_audit();

CREATE TRIGGER handle_updated_at_seasons BEFORE UPDATE ON public.seasons FOR EACH ROW EXECUTE FUNCTION moddatetime('updated_at');

CREATE TRIGGER handle_updated_at_student_attendance BEFORE UPDATE ON public.student_attendance FOR EACH ROW EXECUTE FUNCTION moddatetime('updated_at');

CREATE TRIGGER audit_students AFTER INSERT OR DELETE OR UPDATE ON public.students FOR EACH ROW EXECUTE FUNCTION trg_audit();

CREATE TRIGGER handle_updated_at_user_search_index BEFORE UPDATE ON public.user_search_index FOR EACH ROW EXECUTE FUNCTION moddatetime('updated_at');

CREATE TRIGGER handle_updated_at_workflow_action_role_assignments BEFORE UPDATE ON public.workflow_action_role_assignments FOR EACH ROW EXECUTE FUNCTION moddatetime('updated_at');

CREATE TRIGGER audit_workflow_actions AFTER INSERT OR DELETE OR UPDATE ON public.workflow_actions FOR EACH ROW EXECUTE FUNCTION audit_workflow_action_change();

CREATE TRIGGER handle_updated_at_workflow_actions BEFORE UPDATE ON public.workflow_actions FOR EACH ROW EXECUTE FUNCTION moddatetime('updated_at');

CREATE TRIGGER notify_on_workflow_action_assignment AFTER INSERT OR UPDATE ON public.workflow_actions FOR EACH ROW EXECUTE FUNCTION notify_workflow_action_assigned();

CREATE TRIGGER notify_on_workflow_action_completion AFTER UPDATE ON public.workflow_actions FOR EACH ROW EXECUTE FUNCTION notify_workflow_action_completed();

CREATE TRIGGER track_action_completion_state BEFORE UPDATE ON public.workflow_actions FOR EACH ROW EXECUTE FUNCTION track_action_completion();

CREATE TRIGGER handle_updated_at_workflow_instances BEFORE UPDATE ON public.workflow_instances FOR EACH ROW EXECUTE FUNCTION moddatetime('updated_at');

CREATE TRIGGER track_workflow_instance_state BEFORE UPDATE ON public.workflow_instances FOR EACH ROW EXECUTE FUNCTION track_workflow_instance_change();

CREATE TRIGGER auto_advance_workflow_stage AFTER UPDATE ON public.workflow_stage_instances FOR EACH ROW EXECUTE FUNCTION auto_advance_workflow();

CREATE TRIGGER auto_assign_actions_on_stage_activation AFTER UPDATE ON public.workflow_stage_instances FOR EACH ROW EXECUTE FUNCTION auto_assign_workflow_actions();

CREATE TRIGGER handle_updated_at_workflow_stage_instances BEFORE UPDATE ON public.workflow_stage_instances FOR EACH ROW EXECUTE FUNCTION moddatetime('updated_at');

CREATE TRIGGER track_stage_instance_state BEFORE UPDATE ON public.workflow_stage_instances FOR EACH ROW EXECUTE FUNCTION track_stage_instance_change();

CREATE TRIGGER handle_updated_at_workflow_template_permissions BEFORE UPDATE ON public.workflow_template_permissions FOR EACH ROW EXECUTE FUNCTION moddatetime('updated_at');

CREATE TRIGGER handle_updated_at_workflow_template_stages BEFORE UPDATE ON public.workflow_template_stages FOR EACH ROW EXECUTE FUNCTION moddatetime('updated_at');

CREATE TRIGGER handle_updated_at_workflow_templates BEFORE UPDATE ON public.workflow_templates FOR EACH ROW EXECUTE FUNCTION moddatetime('updated_at');


