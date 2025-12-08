drop policy "hq_update_high_level" on "public"."headquarters";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.fn_is_coordinator_or_higher()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
SELECT public.fn_get_current_role_level() >= 80;
$function$
;


  create policy "hq_update_high_level"
  on "public"."headquarters"
  as permissive
  for update
  to authenticated
using (public.fn_is_coordinator_or_higher())
with check (public.fn_is_coordinator_or_higher());


CREATE TRIGGER update_search_index_on_user_change AFTER INSERT OR DELETE OR UPDATE ON auth.users FOR EACH ROW EXECUTE FUNCTION public.update_user_search_index();


