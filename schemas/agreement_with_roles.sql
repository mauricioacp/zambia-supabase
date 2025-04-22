/*
 * Agreement with Roles View and Functions
 * 
 * This schema creates a view that joins agreements with their associated roles,
 * and provides several functions to query this view efficiently.
 * 
 * The view:
 * - agreement_with_roles: Joins agreements with their roles as a JSONB array
 * 
 * Functions:
 * - get_agreements_with_roles(): Returns all agreements with their roles
 * - get_agreements_by_role(role_name TEXT): Returns agreements filtered by role name
 * - get_agreements_by_role_id(role_id UUID): Returns agreements filtered by role ID
 * - get_agreements_by_role_string(role_string TEXT): Returns agreements filtered by a string that matches role name or code
 * - get_agreements_with_roles_paginated(...): Returns paginated and filtered agreements with pagination metadata
 * - get_agreement_with_roles_by_id(p_agreement_id UUID): Returns a single agreement by ID
 * 
 * Usage examples:
 * - SELECT * FROM get_agreements_with_roles();
 * - SELECT * FROM get_agreements_by_role('Student');
 * - SELECT * FROM get_agreements_by_role_id('123e4567-e89b-12d3-a456-426614174000');
 * - SELECT * FROM get_agreements_by_role_string('admin');
 * - SELECT get_agreements_with_roles_paginated(10, 0, 'active', NULL, NULL, 'john', NULL);
 * - SELECT get_agreement_with_roles_by_id('123e4567-e89b-12d3-a456-426614174000');
 */

-- Create view that joins agreements with their roles
CREATE OR REPLACE VIEW agreement_with_roles AS
WITH roles_array AS (
    SELECT 
        ar.agreement_id,
        jsonb_agg(
            jsonb_build_object(
                'role_id', r.id,
                'role_name', r.name,
                'role_description', r.description
            )
        ) as roles
    FROM 
        agreement_roles ar
    JOIN 
        roles r ON ar.role_id = r.id
    GROUP BY 
        ar.agreement_id
)
SELECT 
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
    a.address,
    a.signature_data,
    a.volunteering_agreement,
    a.ethical_document_agreement,
    a.mailing_agreement,
    a.age_verification,
    a.created_at,
    a.updated_at,
    COALESCE(ra.roles, '[]'::jsonb) as roles
FROM 
    agreements a
LEFT JOIN 
    roles_array ra ON a.id = ra.agreement_id;

-- Set security for the view to be the same as the invoker
-- This ensures the view respects the RLS policies of the underlying tables
ALTER VIEW agreement_with_roles SET (security_invoker = true);

CREATE OR REPLACE FUNCTION get_agreements_with_roles()
RETURNS SETOF agreement_with_roles
LANGUAGE sql
SECURITY INVOKER
SET search_path = ''
AS $$
  SELECT * FROM public.agreement_with_roles;
$$;

CREATE OR REPLACE FUNCTION get_agreements_by_role(role_name TEXT)
RETURNS SETOF agreement_with_roles
LANGUAGE sql
SECURITY INVOKER
SET search_path = ''
AS $$
  SELECT awr.*
  FROM public.agreement_with_roles awr
  WHERE EXISTS (
    SELECT 1
    FROM jsonb_array_elements(awr.roles) as role_obj
    WHERE role_obj->>'role_name' = role_name
  );
$$;

CREATE OR REPLACE FUNCTION get_agreements_by_role_id(role_id UUID)
RETURNS SETOF agreement_with_roles
LANGUAGE sql
SECURITY INVOKER
SET search_path = ''
AS $$
  SELECT awr.*
  FROM public.agreement_with_roles awr
  WHERE EXISTS (
    SELECT 1
    FROM jsonb_array_elements(awr.roles) as role_obj
    WHERE role_obj->>'role_id' = role_id::text
  );
$$;

CREATE OR REPLACE FUNCTION get_agreements_by_role_string(role_string TEXT)
RETURNS SETOF agreement_with_roles
LANGUAGE sql
SECURITY INVOKER
SET search_path = ''
AS $$
  SELECT awr.*
  FROM public.agreement_with_roles awr
  WHERE EXISTS (
    SELECT 1
    FROM jsonb_array_elements(awr.roles) as role_obj
    WHERE role_obj->>'role_name' ILIKE '%' || role_string || '%'
  )
  OR EXISTS (
    SELECT 1
    FROM jsonb_array_elements(awr.roles) as role_obj, public.roles r
    WHERE role_obj->>'role_id' = r.id::text
    AND r.code ILIKE '%' || role_string || '%'
  );
$$;

CREATE OR REPLACE FUNCTION get_agreements_with_roles_paginated(
  p_limit INTEGER DEFAULT 10,
  p_offset INTEGER DEFAULT 0,
  p_status TEXT DEFAULT NULL,
  p_headquarter_id UUID DEFAULT NULL,
  p_season_id UUID DEFAULT NULL,
  p_search TEXT DEFAULT NULL,
  p_role_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  v_total BIGINT;
  v_results JSONB;
  v_data JSONB;
BEGIN
  SELECT COUNT(*) INTO v_total
  FROM public.agreement_with_roles awr
  WHERE 
    (p_status IS NULL OR awr.status = p_status)
    AND (p_headquarter_id IS NULL OR awr.headquarter_id = p_headquarter_id)
    AND (p_season_id IS NULL OR awr.season_id = p_season_id)
    AND (p_search IS NULL OR 
         awr.name ILIKE '%' || p_search || '%' OR 
         awr.last_name ILIKE '%' || p_search || '%' OR
         awr.email ILIKE '%' || p_search || '%' OR
         awr.document_number ILIKE '%' || p_search || '%')
    AND (p_role_id IS NULL OR EXISTS (
      SELECT 1
      FROM jsonb_array_elements(awr.roles) as role_obj
      WHERE role_obj->>'role_id' = p_role_id::text
    ));

  SELECT jsonb_agg(to_jsonb(awr)) INTO v_data
  FROM (
    SELECT *
    FROM public.agreement_with_roles awr
    WHERE 
      (p_status IS NULL OR awr.status = p_status)
      AND (p_headquarter_id IS NULL OR awr.headquarter_id = p_headquarter_id)
      AND (p_season_id IS NULL OR awr.season_id = p_season_id)
      AND (p_search IS NULL OR 
           awr.name ILIKE '%' || p_search || '%' OR 
           awr.last_name ILIKE '%' || p_search || '%' OR
           awr.email ILIKE '%' || p_search || '%' OR
           awr.document_number ILIKE '%' || p_search || '%')
      AND (p_role_id IS NULL OR EXISTS (
        SELECT 1
        FROM jsonb_array_elements(awr.roles) as role_obj
        WHERE role_obj->>'role_id' = p_role_id::text
      ))
    ORDER BY awr.created_at DESC
    LIMIT p_limit
    OFFSET p_offset
  ) awr;

  -- Handle case when no results are found
  IF v_data IS NULL THEN
    v_data := '[]'::jsonb;
  END IF;

  -- Construct the final result object
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
$$;

CREATE OR REPLACE FUNCTION get_agreement_with_roles_by_id(p_agreement_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  v_result JSONB;
BEGIN
  SELECT to_jsonb(awr) INTO v_result
  FROM public.agreement_with_roles awr
  WHERE awr.id = p_agreement_id;

  IF v_result IS NULL THEN
    RETURN jsonb_build_object('error', 'Agreement not found');
  END IF;

  RETURN v_result;
END;
$$;
