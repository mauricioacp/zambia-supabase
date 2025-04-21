create extension if not exists "moddatetime" with schema "extensions";


create table "public"."agreements" (
    "id" uuid not null default uuid_generate_v4(),
    "role_id" uuid,
    "user_id" uuid,
    "headquarter_id" uuid,
    "season_id" uuid,
    "status" text default 'prospect'::text,
    "email" text not null,
    "document_number" text,
    "phone" text,
    "created_at" timestamp with time zone default now(),
    "updated_at" timestamp with time zone default now(),
    "name" text,
    "last_name" text,
    "address" text,
    "volunteering_agreement" boolean default false,
    "ethical_document_agreement" boolean default false,
    "mailing_agreement" boolean default false,
    "age_verification" boolean default false,
    "signature_data" text
);


alter table "public"."agreements" enable row level security;

create table "public"."collaborators" (
    "id" uuid not null default uuid_generate_v4(),
    "user_id" uuid,
    "agreement_id" uuid,
    "role_id" uuid,
    "headquarter_id" uuid,
    "status" text default 'inactive'::text,
    "start_date" date,
    "end_date" date
);


alter table "public"."collaborators" enable row level security;

create table "public"."countries" (
    "id" uuid not null default uuid_generate_v4(),
    "name" text not null,
    "code" text not null,
    "status" text default 'active'::text,
    "created_at" timestamp with time zone default now(),
    "updated_at" timestamp with time zone default now()
);


alter table "public"."countries" enable row level security;

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
    "location" jsonb,
    "status" text default 'draft'::text
);


alter table "public"."events" enable row level security;

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

create table "public"."processes" (
    "id" uuid not null default uuid_generate_v4(),
    "created_at" timestamp with time zone default now(),
    "updated_at" timestamp with time zone default now(),
    "name" text not null,
    "description" text,
    "type" text,
    "status" text default 'active'::text,
    "version" text,
    "content" jsonb,
    "applicable_roles" text[]
);


alter table "public"."processes" enable row level security;

create table "public"."roles" (
    "id" uuid not null default uuid_generate_v4(),
    "code" text not null,
    "name" text not null,
    "description" text,
    "status" text default 'active'::text,
    "created_at" timestamp with time zone default now(),
    "updated_at" timestamp with time zone default now(),
    "permissions" jsonb default '{}'::jsonb
);


alter table "public"."roles" enable row level security;

create table "public"."seasons" (
    "id" uuid not null default uuid_generate_v4(),
    "name" text not null,
    "headquarter_id" uuid,
    "manager_id" uuid,
    "start_date" date,
    "end_date" date,
    "status" text default 'planning'::text,
    "created_at" timestamp with time zone default now(),
    "updated_at" timestamp with time zone default now()
);


alter table "public"."seasons" enable row level security;

create table "public"."students" (
    "id" uuid not null default uuid_generate_v4(),
    "user_id" uuid,
    "agreement_id" uuid,
    "headquarter_id" uuid,
    "season_id" uuid,
    "enrollment_date" date,
    "status" text default 'prospect'::text,
    "program_progress_comments" jsonb
);


alter table "public"."students" enable row level security;

create table "public"."workshops" (
    "id" uuid not null default uuid_generate_v4(),
    "name" text not null,
    "description" text,
    "headquarter_id" uuid,
    "season_id" uuid,
    "start_datetime" timestamp with time zone,
    "end_datetime" timestamp with time zone,
    "facilitator_id" uuid,
    "capacity" integer,
    "status" text default 'draft'::text,
    "created_at" timestamp with time zone default now(),
    "updated_at" timestamp with time zone default now()
);


alter table "public"."workshops" enable row level security;

CREATE UNIQUE INDEX agreements_pkey ON public.agreements USING btree (id);

CREATE UNIQUE INDEX agreements_user_id_season_id_role_id_key ON public.agreements USING btree (user_id, season_id, role_id);

CREATE UNIQUE INDEX collaborators_pkey ON public.collaborators USING btree (id);

CREATE UNIQUE INDEX countries_code_key ON public.countries USING btree (code);

CREATE UNIQUE INDEX countries_pkey ON public.countries USING btree (id);

CREATE UNIQUE INDEX events_pkey ON public.events USING btree (id);

CREATE UNIQUE INDEX headquarters_pkey ON public.headquarters USING btree (id);

CREATE INDEX idx_agreements_document_number ON public.agreements USING btree (document_number);

CREATE INDEX idx_agreements_email ON public.agreements USING btree (email);

CREATE INDEX idx_agreements_headquarter_id ON public.agreements USING btree (headquarter_id);

CREATE INDEX idx_agreements_last_name ON public.agreements USING btree (last_name);

CREATE INDEX idx_agreements_name ON public.agreements USING btree (name);

CREATE INDEX idx_agreements_phone ON public.agreements USING btree (phone);

CREATE INDEX idx_agreements_role_id ON public.agreements USING btree (role_id);

CREATE INDEX idx_agreements_season_id ON public.agreements USING btree (season_id);

CREATE INDEX idx_agreements_user_id ON public.agreements USING btree (user_id);

CREATE INDEX idx_collaborators_agreement_id ON public.collaborators USING btree (agreement_id);

CREATE INDEX idx_collaborators_headquarter_id ON public.collaborators USING btree (headquarter_id);

CREATE INDEX idx_collaborators_role_id ON public.collaborators USING btree (role_id);

CREATE INDEX idx_collaborators_user_id ON public.collaborators USING btree (user_id);

CREATE INDEX idx_countries_code ON public.countries USING btree (code);

CREATE INDEX idx_events_headquarter_id ON public.events USING btree (headquarter_id);

CREATE INDEX idx_events_start_datetime ON public.events USING btree (start_datetime);

CREATE INDEX idx_events_status ON public.events USING btree (status);

CREATE INDEX idx_headquarters_country_id ON public.headquarters USING btree (country_id);

CREATE INDEX idx_processes_status ON public.processes USING btree (status);

CREATE INDEX idx_roles_code ON public.roles USING btree (code);

CREATE INDEX idx_seasons_headquarter_id ON public.seasons USING btree (headquarter_id);

CREATE INDEX idx_seasons_manager_id ON public.seasons USING btree (manager_id);

CREATE INDEX idx_students_agreement_id ON public.students USING btree (agreement_id);

CREATE INDEX idx_students_headquarter_id ON public.students USING btree (headquarter_id);

CREATE INDEX idx_students_season_id ON public.students USING btree (season_id);

CREATE INDEX idx_students_user_id ON public.students USING btree (user_id);

CREATE INDEX idx_workshops_headquarter_id ON public.workshops USING btree (headquarter_id);

CREATE UNIQUE INDEX processes_pkey ON public.processes USING btree (id);

CREATE UNIQUE INDEX roles_code_key ON public.roles USING btree (code);

CREATE UNIQUE INDEX roles_pkey ON public.roles USING btree (id);

CREATE UNIQUE INDEX seasons_pkey ON public.seasons USING btree (id);

CREATE UNIQUE INDEX students_pkey ON public.students USING btree (id);

CREATE UNIQUE INDEX workshops_pkey ON public.workshops USING btree (id);

alter table "public"."agreements" add constraint "agreements_pkey" PRIMARY KEY using index "agreements_pkey";

alter table "public"."collaborators" add constraint "collaborators_pkey" PRIMARY KEY using index "collaborators_pkey";

alter table "public"."countries" add constraint "countries_pkey" PRIMARY KEY using index "countries_pkey";

alter table "public"."events" add constraint "events_pkey" PRIMARY KEY using index "events_pkey";

alter table "public"."headquarters" add constraint "headquarters_pkey" PRIMARY KEY using index "headquarters_pkey";

alter table "public"."processes" add constraint "processes_pkey" PRIMARY KEY using index "processes_pkey";

alter table "public"."roles" add constraint "roles_pkey" PRIMARY KEY using index "roles_pkey";

alter table "public"."seasons" add constraint "seasons_pkey" PRIMARY KEY using index "seasons_pkey";

alter table "public"."students" add constraint "students_pkey" PRIMARY KEY using index "students_pkey";

alter table "public"."workshops" add constraint "workshops_pkey" PRIMARY KEY using index "workshops_pkey";

alter table "public"."agreements" add constraint "agreements_headquarter_id_fkey" FOREIGN KEY (headquarter_id) REFERENCES headquarters(id) ON DELETE RESTRICT not valid;

alter table "public"."agreements" validate constraint "agreements_headquarter_id_fkey";

alter table "public"."agreements" add constraint "agreements_role_id_fkey" FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE RESTRICT not valid;

alter table "public"."agreements" validate constraint "agreements_role_id_fkey";

alter table "public"."agreements" add constraint "agreements_season_id_fkey" FOREIGN KEY (season_id) REFERENCES seasons(id) ON DELETE SET NULL not valid;

alter table "public"."agreements" validate constraint "agreements_season_id_fkey";

alter table "public"."agreements" add constraint "agreements_status_check" CHECK ((status = ANY (ARRAY['active'::text, 'inactive'::text, 'prospect'::text]))) not valid;

alter table "public"."agreements" validate constraint "agreements_status_check";

alter table "public"."agreements" add constraint "agreements_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL not valid;

alter table "public"."agreements" validate constraint "agreements_user_id_fkey";

alter table "public"."agreements" add constraint "agreements_user_id_season_id_role_id_key" UNIQUE using index "agreements_user_id_season_id_role_id_key";

alter table "public"."collaborators" add constraint "collaborators_agreement_id_fkey" FOREIGN KEY (agreement_id) REFERENCES agreements(id) ON DELETE CASCADE not valid;

alter table "public"."collaborators" validate constraint "collaborators_agreement_id_fkey";

alter table "public"."collaborators" add constraint "collaborators_headquarter_id_fkey" FOREIGN KEY (headquarter_id) REFERENCES headquarters(id) ON DELETE RESTRICT not valid;

alter table "public"."collaborators" validate constraint "collaborators_headquarter_id_fkey";

alter table "public"."collaborators" add constraint "collaborators_role_id_fkey" FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE RESTRICT not valid;

alter table "public"."collaborators" validate constraint "collaborators_role_id_fkey";

alter table "public"."collaborators" add constraint "collaborators_status_check" CHECK ((status = ANY (ARRAY['active'::text, 'inactive'::text, 'standby'::text]))) not valid;

alter table "public"."collaborators" validate constraint "collaborators_status_check";

alter table "public"."collaborators" add constraint "collaborators_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE not valid;

alter table "public"."collaborators" validate constraint "collaborators_user_id_fkey";

alter table "public"."countries" add constraint "countries_code_key" UNIQUE using index "countries_code_key";

alter table "public"."countries" add constraint "countries_status_check" CHECK ((status = ANY (ARRAY['active'::text, 'inactive'::text]))) not valid;

alter table "public"."countries" validate constraint "countries_status_check";

alter table "public"."events" add constraint "events_headquarter_id_fkey" FOREIGN KEY (headquarter_id) REFERENCES headquarters(id) ON DELETE SET NULL not valid;

alter table "public"."events" validate constraint "events_headquarter_id_fkey";

alter table "public"."events" add constraint "events_season_id_fkey" FOREIGN KEY (season_id) REFERENCES seasons(id) ON DELETE SET NULL not valid;

alter table "public"."events" validate constraint "events_season_id_fkey";

alter table "public"."events" add constraint "events_status_check" CHECK ((status = ANY (ARRAY['draft'::text, 'scheduled'::text, 'completed'::text, 'cancelled'::text]))) not valid;

alter table "public"."events" validate constraint "events_status_check";

alter table "public"."headquarters" add constraint "headquarters_country_id_fkey" FOREIGN KEY (country_id) REFERENCES countries(id) ON DELETE RESTRICT not valid;

alter table "public"."headquarters" validate constraint "headquarters_country_id_fkey";

alter table "public"."headquarters" add constraint "headquarters_status_check" CHECK ((status = ANY (ARRAY['active'::text, 'inactive'::text]))) not valid;

alter table "public"."headquarters" validate constraint "headquarters_status_check";

alter table "public"."processes" add constraint "processes_status_check" CHECK ((status = ANY (ARRAY['active'::text, 'inactive'::text]))) not valid;

alter table "public"."processes" validate constraint "processes_status_check";

alter table "public"."roles" add constraint "roles_code_key" UNIQUE using index "roles_code_key";

alter table "public"."roles" add constraint "roles_status_check" CHECK ((status = ANY (ARRAY['active'::text, 'inactive'::text]))) not valid;

alter table "public"."roles" validate constraint "roles_status_check";

alter table "public"."seasons" add constraint "seasons_headquarter_id_fkey" FOREIGN KEY (headquarter_id) REFERENCES headquarters(id) ON DELETE CASCADE not valid;

alter table "public"."seasons" validate constraint "seasons_headquarter_id_fkey";

alter table "public"."seasons" add constraint "seasons_status_check" CHECK ((status = ANY (ARRAY['active'::text, 'inactive'::text, 'planning'::text, 'completed'::text]))) not valid;

alter table "public"."seasons" validate constraint "seasons_status_check";

alter table "public"."students" add constraint "students_agreement_id_fkey" FOREIGN KEY (agreement_id) REFERENCES agreements(id) ON DELETE CASCADE not valid;

alter table "public"."students" validate constraint "students_agreement_id_fkey";

alter table "public"."students" add constraint "students_headquarter_id_fkey" FOREIGN KEY (headquarter_id) REFERENCES headquarters(id) ON DELETE RESTRICT not valid;

alter table "public"."students" validate constraint "students_headquarter_id_fkey";

alter table "public"."students" add constraint "students_season_id_fkey" FOREIGN KEY (season_id) REFERENCES seasons(id) ON DELETE RESTRICT not valid;

alter table "public"."students" validate constraint "students_season_id_fkey";

alter table "public"."students" add constraint "students_status_check" CHECK ((status = ANY (ARRAY['active'::text, 'prospect'::text, 'graduated'::text, 'inactive'::text]))) not valid;

alter table "public"."students" validate constraint "students_status_check";

alter table "public"."students" add constraint "students_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE not valid;

alter table "public"."students" validate constraint "students_user_id_fkey";

alter table "public"."workshops" add constraint "workshops_facilitator_id_fkey" FOREIGN KEY (facilitator_id) REFERENCES collaborators(id) ON DELETE SET NULL not valid;

alter table "public"."workshops" validate constraint "workshops_facilitator_id_fkey";

alter table "public"."workshops" add constraint "workshops_headquarter_id_fkey" FOREIGN KEY (headquarter_id) REFERENCES headquarters(id) ON DELETE SET NULL not valid;

alter table "public"."workshops" validate constraint "workshops_headquarter_id_fkey";

alter table "public"."workshops" add constraint "workshops_season_id_fkey" FOREIGN KEY (season_id) REFERENCES seasons(id) ON DELETE SET NULL not valid;

alter table "public"."workshops" validate constraint "workshops_season_id_fkey";

alter table "public"."workshops" add constraint "workshops_status_check" CHECK ((status = ANY (ARRAY['draft'::text, 'scheduled'::text, 'completed'::text, 'cancelled'::text]))) not valid;

alter table "public"."workshops" validate constraint "workshops_status_check";

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

grant delete on table "public"."workshops" to "anon";

grant insert on table "public"."workshops" to "anon";

grant references on table "public"."workshops" to "anon";

grant select on table "public"."workshops" to "anon";

grant trigger on table "public"."workshops" to "anon";

grant truncate on table "public"."workshops" to "anon";

grant update on table "public"."workshops" to "anon";

grant delete on table "public"."workshops" to "authenticated";

grant insert on table "public"."workshops" to "authenticated";

grant references on table "public"."workshops" to "authenticated";

grant select on table "public"."workshops" to "authenticated";

grant trigger on table "public"."workshops" to "authenticated";

grant truncate on table "public"."workshops" to "authenticated";

grant update on table "public"."workshops" to "authenticated";

grant delete on table "public"."workshops" to "service_role";

grant insert on table "public"."workshops" to "service_role";

grant references on table "public"."workshops" to "service_role";

grant select on table "public"."workshops" to "service_role";

grant trigger on table "public"."workshops" to "service_role";

grant truncate on table "public"."workshops" to "service_role";

grant update on table "public"."workshops" to "service_role";

create policy "Allow authenticated users to delete agreements"
on "public"."agreements"
as permissive
for delete
to authenticated
using (true);


create policy "Allow authenticated users to insert agreements"
on "public"."agreements"
as permissive
for insert
to authenticated
with check (true);


create policy "Allow authenticated users to update agreements"
on "public"."agreements"
as permissive
for update
to authenticated
using (true)
with check (true);


create policy "Allow authenticated users to view agreements"
on "public"."agreements"
as permissive
for select
to authenticated
using (true);


create policy "Allow authenticated users to delete collaborators"
on "public"."collaborators"
as permissive
for delete
to authenticated
using (true);


create policy "Allow authenticated users to insert collaborators"
on "public"."collaborators"
as permissive
for insert
to authenticated
with check (true);


create policy "Allow authenticated users to update collaborators"
on "public"."collaborators"
as permissive
for update
to authenticated
using (true)
with check (true);


create policy "Allow authenticated users to view collaborators"
on "public"."collaborators"
as permissive
for select
to authenticated
using (true);


create policy "Allow authenticated users to delete countries"
on "public"."countries"
as permissive
for delete
to authenticated
using (true);


create policy "Allow authenticated users to insert countries"
on "public"."countries"
as permissive
for insert
to authenticated
with check (true);


create policy "Allow authenticated users to update countries"
on "public"."countries"
as permissive
for update
to authenticated
using (true)
with check (true);


create policy "Allow authenticated users to view countries"
on "public"."countries"
as permissive
for select
to authenticated
using (true);


create policy "Allow authenticated users to delete events"
on "public"."events"
as permissive
for delete
to authenticated
using (true);


create policy "Allow authenticated users to insert events"
on "public"."events"
as permissive
for insert
to authenticated
with check (true);


create policy "Allow authenticated users to update events"
on "public"."events"
as permissive
for update
to authenticated
using (true)
with check (true);


create policy "Allow authenticated users to view events"
on "public"."events"
as permissive
for select
to authenticated
using (true);


create policy "Allow authenticated users to delete headquarters"
on "public"."headquarters"
as permissive
for delete
to authenticated
using (true);


create policy "Allow authenticated users to insert headquarters"
on "public"."headquarters"
as permissive
for insert
to authenticated
with check (true);


create policy "Allow authenticated users to update headquarters"
on "public"."headquarters"
as permissive
for update
to authenticated
using (true)
with check (true);


create policy "Allow authenticated users to view headquarters"
on "public"."headquarters"
as permissive
for select
to authenticated
using (true);


create policy "Allow authenticated users to delete processes"
on "public"."processes"
as permissive
for delete
to authenticated
using (true);


create policy "Allow authenticated users to insert processes"
on "public"."processes"
as permissive
for insert
to authenticated
with check (true);


create policy "Allow authenticated users to update processes"
on "public"."processes"
as permissive
for update
to authenticated
using (true)
with check (true);


create policy "Allow authenticated users to view processes"
on "public"."processes"
as permissive
for select
to authenticated
using (true);


create policy "Allow authenticated users to delete roles"
on "public"."roles"
as permissive
for delete
to authenticated
using (true);


create policy "Allow authenticated users to insert roles"
on "public"."roles"
as permissive
for insert
to authenticated
with check (true);


create policy "Allow authenticated users to update roles"
on "public"."roles"
as permissive
for update
to authenticated
using (true)
with check (true);


create policy "Allow authenticated users to view roles"
on "public"."roles"
as permissive
for select
to authenticated
using (true);


create policy "Allow authenticated users to delete seasons"
on "public"."seasons"
as permissive
for delete
to authenticated
using (true);


create policy "Allow authenticated users to insert seasons"
on "public"."seasons"
as permissive
for insert
to authenticated
with check (true);


create policy "Allow authenticated users to update seasons"
on "public"."seasons"
as permissive
for update
to authenticated
using (true)
with check (true);


create policy "Allow authenticated users to view seasons"
on "public"."seasons"
as permissive
for select
to authenticated
using (true);


create policy "Allow authenticated users to delete students"
on "public"."students"
as permissive
for delete
to authenticated
using (true);


create policy "Allow authenticated users to insert students"
on "public"."students"
as permissive
for insert
to authenticated
with check (true);


create policy "Allow authenticated users to update students"
on "public"."students"
as permissive
for update
to authenticated
using (true)
with check (true);


create policy "Allow authenticated users to view students"
on "public"."students"
as permissive
for select
to authenticated
using (true);


create policy "Allow authenticated users to delete workshops"
on "public"."workshops"
as permissive
for delete
to authenticated
using (true);


create policy "Allow authenticated users to insert workshops"
on "public"."workshops"
as permissive
for insert
to authenticated
with check (true);


create policy "Allow authenticated users to update workshops"
on "public"."workshops"
as permissive
for update
to authenticated
using (true)
with check (true);


create policy "Allow authenticated users to view workshops"
on "public"."workshops"
as permissive
for select
to authenticated
using (true);


CREATE TRIGGER handle_updated_at_agreements BEFORE UPDATE ON public.agreements FOR EACH ROW EXECUTE FUNCTION moddatetime('updated_at');

CREATE TRIGGER handle_updated_at_countries BEFORE UPDATE ON public.countries FOR EACH ROW EXECUTE FUNCTION moddatetime('updated_at');

CREATE TRIGGER handle_updated_at_events BEFORE UPDATE ON public.events FOR EACH ROW EXECUTE FUNCTION moddatetime('updated_at');

CREATE TRIGGER handle_updated_at_headquarters BEFORE UPDATE ON public.headquarters FOR EACH ROW EXECUTE FUNCTION moddatetime('updated_at');

CREATE TRIGGER handle_updated_at_processes BEFORE UPDATE ON public.processes FOR EACH ROW EXECUTE FUNCTION moddatetime('updated_at');

CREATE TRIGGER handle_updated_at_roles BEFORE UPDATE ON public.roles FOR EACH ROW EXECUTE FUNCTION moddatetime('updated_at');

CREATE TRIGGER handle_updated_at_seasons BEFORE UPDATE ON public.seasons FOR EACH ROW EXECUTE FUNCTION moddatetime('updated_at');

CREATE TRIGGER handle_updated_at_workshops BEFORE UPDATE ON public.workshops FOR EACH ROW EXECUTE FUNCTION moddatetime('updated_at');


