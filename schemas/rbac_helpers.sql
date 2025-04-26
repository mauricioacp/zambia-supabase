-- Helper functions for Role-Based Access Control (RBAC)

-- Function to safely get the entire metadata object for the current user
CREATE OR REPLACE FUNCTION fn_get_current_user_metadata()
RETURNS jsonb
LANGUAGE sql STABLE SECURITY INVOKER
AS $$
  SELECT COALESCE(raw_user_meta_data, '{}'::jsonb) FROM auth.users WHERE id = auth.uid();
$$;

-- Function to get the current user's role code
CREATE OR REPLACE FUNCTION fn_get_current_role_code()
RETURNS text
LANGUAGE sql STABLE SECURITY INVOKER
AS $$
  SELECT fn_get_current_user_metadata() ->> 'role';
$$;

-- Function to get the current user's role level
CREATE OR REPLACE FUNCTION fn_get_current_role_level()
RETURNS integer
LANGUAGE sql STABLE SECURITY INVOKER
AS $$
  SELECT COALESCE((fn_get_current_user_metadata() ->> 'role_level')::integer, 0);
$$;

-- Function to get the current user's role ID
CREATE OR REPLACE FUNCTION fn_get_current_role_id()
RETURNS uuid
LANGUAGE sql STABLE SECURITY INVOKER
AS $$
  SELECT NULLIF(fn_get_current_user_metadata() ->> 'role_id', '')::uuid;
$$;

-- Function to get the current user's headquarter ID
CREATE OR REPLACE FUNCTION fn_get_current_hq_id()
RETURNS uuid
LANGUAGE sql STABLE SECURITY INVOKER
AS $$
  SELECT NULLIF(fn_get_current_user_metadata() ->> 'hq_id', '')::uuid;
$$;

-- Function to get the current user's season ID
CREATE OR REPLACE FUNCTION fn_get_current_season_id()
RETURNS uuid
LANGUAGE sql STABLE SECURITY INVOKER
AS $$
  SELECT NULLIF(fn_get_current_user_metadata() ->> 'season_id', '')::uuid;
$$;

-- Function to get the current user's agreement ID
CREATE OR REPLACE FUNCTION fn_get_current_agreement_id()
RETURNS uuid
LANGUAGE sql STABLE SECURITY INVOKER
AS $$
  SELECT NULLIF(fn_get_current_user_metadata() ->> 'agreement_id', '')::uuid;
$$;
