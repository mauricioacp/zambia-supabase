alter table "public"."agreements" drop constraint "agreements_status_check";

alter table "public"."agreements" add constraint "agreements_status_check" CHECK ((status = ANY (ARRAY['active'::text, 'graduated'::text, 'inactive'::text, 'prospect'::text]))) not valid;

alter table "public"."agreements" validate constraint "agreements_status_check";


