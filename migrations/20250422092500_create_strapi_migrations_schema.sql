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

CREATE UNIQUE INDEX strapi_migrations_pkey ON public.strapi_migrations USING btree (id);

alter table "public"."strapi_migrations" add constraint "strapi_migrations_pkey" PRIMARY KEY using index "strapi_migrations_pkey";

alter table "public"."strapi_migrations" add constraint "strapi_migrations_status_check" CHECK ((status = ANY (ARRAY['success'::text, 'failed'::text]))) not valid;

alter table "public"."strapi_migrations" validate constraint "strapi_migrations_status_check";

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



