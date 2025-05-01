-- Helper functions for Role-Based Access Control (RBAC)
-- Super administrador	100
-- Director General	95
-- Líder Ejecutivo	90
-- Líder Pedagógico	90
-- Líder de Comunicación	90
-- Líder de Koordinación	90
-- Líder de Innovación	80
-- Líder de Komunidad	80
-- Fundación Utópika	80
-- Koordinador	80
-- Asesor Legal	80
-- Miembro del Konsejo de Dirección	80
-- Director/a Local	50
-- Director/a Pedagógico Local	50
-- Director/a de Comunicación Local	50
-- Director/a de Acompañantes Local	50
-- Asistente a la dirección	30
-- Acompañante	20
-- Facilitador	20
-- Alumno	1

-- Function to safely get the entire metadata object for the current user
CREATE OR REPLACE FUNCTION fn_get_current_user_metadata()
RETURNS jsonb
LANGUAGE sql STABLE SECURITY INVOKER SET search_path = ''
AS $$
  SELECT COALESCE(raw_user_meta_data, '{}'::jsonb) FROM auth.users WHERE id = auth.uid();
$$;

-- Function to get the current user's role code
CREATE OR REPLACE FUNCTION fn_get_current_role_code()
RETURNS text
LANGUAGE sql STABLE SECURITY INVOKER SET search_path = ''
AS $$
  SELECT fn_get_current_user_metadata() ->> 'role';
$$;

-- Function to get the current user's role level
CREATE OR REPLACE FUNCTION fn_get_current_role_level()
RETURNS integer
LANGUAGE sql STABLE SECURITY INVOKER SET search_path = ''
AS $$
  SELECT COALESCE((fn_get_current_user_metadata() ->> 'role_level')::integer, 0);
$$;

-- Function to get the current user's role ID
CREATE OR REPLACE FUNCTION fn_get_current_role_id()
RETURNS uuid
LANGUAGE sql STABLE SECURITY INVOKER SET search_path = ''
AS $$
SELECT NULLIF(fn_get_current_user_metadata() ->> 'role_id', '')::uuid;
$$;

-- Function to get the current user's headquarter ID
CREATE OR REPLACE FUNCTION fn_get_current_hq_id()
RETURNS uuid
LANGUAGE sql STABLE SECURITY INVOKER SET search_path = ''
AS $$
SELECT NULLIF(fn_get_current_user_metadata() ->> 'hq_id', '')::uuid;
$$;

-- Function to get the current user's season ID
CREATE OR REPLACE FUNCTION fn_get_current_season_id()
RETURNS uuid
LANGUAGE sql STABLE SECURITY INVOKER SET search_path = ''
AS $$
SELECT NULLIF(fn_get_current_user_metadata() ->> 'season_id', '')::uuid;
$$;

-- Function to get the current user's agreement ID
CREATE OR REPLACE FUNCTION fn_get_current_agreement_id()
RETURNS uuid
LANGUAGE sql STABLE SECURITY INVOKER SET search_path = ''
AS $$
SELECT NULLIF(fn_get_current_user_metadata() ->> 'agreement_id', '')::uuid;
$$;

--Is super admin
CREATE OR REPLACE FUNCTION fn_is_super_admin()
RETURNS boolean
LANGUAGE sql STABLE SECURITY INVOKER SET search_path = ''
AS $$
SELECT fn_get_current_role_level() >= 100;
$$;

-- Function that returns true if role is General Director (95+) or higher
CREATE OR REPLACE FUNCTION fn_is_general_director_or_higher()
RETURNS boolean
LANGUAGE sql STABLE SECURITY INVOKER SET search_path = ''
AS $$
SELECT fn_get_current_role_level() >= 95;
$$;

-- Function that returns true if role is Konsejo member or higher (80+)
CREATE OR REPLACE FUNCTION fn_is_konsejo_member_or_higher()
RETURNS boolean
LANGUAGE sql STABLE SECURITY INVOKER SET search_path = ''
AS $$
SELECT fn_get_current_role_level() >= 80;
$$;

-- Function that returns true if role is local manager (50+) or higher
CREATE OR REPLACE FUNCTION fn_is_local_manager_or_higher()
RETURNS boolean
LANGUAGE sql STABLE SECURITY INVOKER SET search_path = ''
AS $$
SELECT fn_get_current_role_level() >= 50;
$$;

-- Function that returns true if role is manager assistant (30+) or higher
CREATE OR REPLACE FUNCTION fn_is_manager_assistant_or_higher()
RETURNS boolean
LANGUAGE sql STABLE SECURITY INVOKER SET search_path = ''
AS $$
SELECT fn_get_current_role_level() >= 30;
$$;

-- Function that returns true if role is collaborator (20+) or higher
CREATE OR REPLACE FUNCTION fn_is_collaborator_or_higher()
RETURNS boolean
LANGUAGE sql STABLE SECURITY INVOKER SET search_path = ''
AS $$
SELECT fn_get_current_role_level() >= 20;
$$;

-- Function that returns true if role is student (1+) or higher
CREATE OR REPLACE FUNCTION fn_is_student_or_higher()
RETURNS boolean
LANGUAGE sql STABLE SECURITY INVOKER SET search_path = ''
AS $$
SELECT fn_get_current_role_level() >= 1;
$$;


-- Function that returns true if the current user hq is the same as the provided hq id
CREATE OR REPLACE FUNCTION fn_is_current_user_hq_equal_to(hq_id uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY INVOKER SET search_path = ''
AS $$
SELECT fn_get_current_hq_id() = hq_id;
$$;
