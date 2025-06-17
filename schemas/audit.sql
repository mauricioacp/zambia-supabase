/* ---------- 1)  Generic audit table ---------- */
CREATE TABLE audit_log (
  id            bigserial PRIMARY KEY,
  table_name    text,
  action        text,          -- 'INSERT' | 'UPDATE' | 'DELETE'
  record_id     uuid,
  changed_by    uuid,
  user_name     text,
  changed_at    timestamptz DEFAULT now(),
  diff          jsonb
);

/* ---------- 2)  Re-usable trigger function ---------- */
-- SECURITY DEFINER: This function runs with elevated privileges. It is required for audit logging but must be maintained with care.
CREATE OR REPLACE FUNCTION trg_audit()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
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
$$;

GRANT EXECUTE ON FUNCTION trg_audit() TO authenticated;

/* ---------- 3)  Attach trigger to critical tables ---------- */
DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['agreements','students','collaborators','headquarters','countries','seasons','scheduled_workshops']
  LOOP
    EXECUTE format('
      DROP TRIGGER IF EXISTS audit_%I ON %I;
      CREATE TRIGGER audit_%I
      AFTER INSERT OR UPDATE OR DELETE ON %I
      FOR EACH ROW EXECUTE PROCEDURE trg_audit();',
      t, t, t, t);
  END LOOP;
END;
$$;


ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;

-- SELECT: Allow only General Director+ (95+)
CREATE POLICY audit_select_high_level
ON audit_log FOR SELECT
TO authenticated
USING ( fn_is_general_director_or_higher() );

-- INSERT: Allow only General Director+ (95+)
CREATE POLICY audit_insert_high_level
ON audit_log FOR INSERT
TO authenticated
WITH CHECK ( fn_is_general_director_or_higher() );

-- UPDATE: Allow only General Director+ (95+)
CREATE POLICY audit_update_high_level
ON audit_log FOR UPDATE
TO authenticated
USING ( fn_is_general_director_or_higher() )
WITH CHECK ( fn_is_general_director_or_higher() );

-- DELETE: Allow only General Director+ (95+)
CREATE POLICY audit_delete_high_level
ON audit_log FOR DELETE
TO authenticated
USING ( fn_is_general_director_or_higher() );
