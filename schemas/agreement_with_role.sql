/*
 * 
 * Functions:
 * - get_agreements_with_role(): Returns all agreements with their role
 * - get_agreements_by_role(role_name TEXT): Returns agreements filtered by role name
 * - get_agreement_by_role_id(role_id UUID): Returns agreements filtered by role ID
 * - get_agreements_by_role_string(role_string TEXT): Returns agreements filtered by a string that matches role name or code
 * - get_agreements_with_role_paginated(...): Returns paginated and filtered agreements with pagination metadata
 * - get_agreement_with_role_by_id(p_agreement_id UUID): Returns a single agreement by ID
 * 
 * Usage examples:
 * - SELECT * FROM get_agreements_with_role();
 * - SELECT * FROM get_agreements_by_role('Student');
 * - SELECT * FROM get_agreement_by_role_id('123e4567-e89b-12d3-a456-426614174000');
 * - SELECT * FROM get_agreements_by_role_string('admin');
 * - SELECT get_agreements_with_role_paginated(10, 0, 'active', NULL, NULL, 'john', NULL);
 * - SELECT get_agreement_with_role_by_id('123e4567-e89b-12d3-a456-426614174000');
 */

create view public.agreement_with_role WITH (security_invoker = on) as
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
FROM agreements a
         LEFT JOIN roles r ON a.role_id = r.id;

CREATE OR REPLACE FUNCTION get_agreements_with_role()
RETURNS SETOF agreement_with_role
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
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
$$;

CREATE OR REPLACE FUNCTION get_agreements_by_role(role_name TEXT)
RETURNS SETOF agreement_with_role
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
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
$$;

CREATE OR REPLACE FUNCTION get_agreement_by_role_id(role_id UUID)
RETURNS SETOF agreement_with_role
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
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
$$;

CREATE OR REPLACE FUNCTION get_agreements_by_role_string(role_string TEXT)
RETURNS SETOF agreement_with_role
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
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
$$;

CREATE OR REPLACE FUNCTION get_agreements_with_role_paginated(
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
$$;

CREATE OR REPLACE FUNCTION get_agreement_with_role_by_id(p_agreement_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
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
$$;
