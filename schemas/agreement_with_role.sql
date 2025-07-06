/*
 * 
 * Comprehensive Agreement Search Function:
 * - search_agreements(): Single function to search and filter agreements with full-text search capabilities
 * 
 * Features:
 * - Full-text search across names, role names, headquarter names, and countries
 * - Individual field filtering (status, headquarter_id, season_id, role_id)
 * - Pagination with metadata
 * - Relevance ranking for search results
 * - Access control integration
 * 
 * Usage examples:
 * - SELECT search_agreements('juan', 10, 0);  -- Search for "juan" across all text fields
 * - SELECT search_agreements(NULL, 10, 0, 'active', NULL, NULL, NULL, 'developer');  -- Filter by role name
 * - SELECT search_agreements('madrid', 10, 0, NULL, NULL, NULL, NULL, NULL, 'Spain');  -- Search and filter by country
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

CREATE OR REPLACE FUNCTION search_agreements(
  p_search_query TEXT DEFAULT NULL,           -- General search query (searches across names, roles, headquarters, countries)
  p_limit INTEGER DEFAULT 10,                -- Results per page
  p_offset INTEGER DEFAULT 0,                -- Offset for pagination
  p_status TEXT DEFAULT NULL,                 -- Filter by agreement status
  p_headquarter_id UUID DEFAULT NULL,         -- Filter by specific headquarter
  p_season_id UUID DEFAULT NULL,             -- Filter by specific season
  p_role_id UUID DEFAULT NULL,               -- Filter by specific role ID
  p_role_name TEXT DEFAULT NULL,             -- Filter by role name (partial match)
  p_country TEXT DEFAULT NULL,               -- Filter by country
  p_use_fts BOOLEAN DEFAULT TRUE             -- Enable/disable full-text search
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
  v_tsquery tsquery;
  v_combined_tsvector tsvector;
BEGIN
  -- Prepare tsquery if using full-text search
  IF p_use_fts AND p_search_query IS NOT NULL THEN
    v_tsquery := plainto_tsquery('spanish', p_search_query);
  END IF;

  -- Count total results
  SELECT COUNT(*) INTO v_total
  FROM public.agreements a
  LEFT JOIN public.roles r ON a.role_id = r.id
  LEFT JOIN public.headquarters h ON a.headquarter_id = h.id
  LEFT JOIN public.countries c ON h.country_id = c.id
  WHERE 
    -- General search across multiple fields
    (p_search_query IS NULL OR (
      (p_use_fts AND (
        a.fts_name_lastname @@ v_tsquery OR
        to_tsvector('spanish', coalesce(r.name, '')) @@ v_tsquery OR
        to_tsvector('spanish', coalesce(h.name, '')) @@ v_tsquery OR
        to_tsvector('spanish', coalesce(c.name, '')) @@ v_tsquery
      )) OR
      (NOT p_use_fts AND (
        a.name ILIKE '%' || p_search_query || '%' OR 
        a.last_name ILIKE '%' || p_search_query || '%' OR
        a.email ILIKE '%' || p_search_query || '%' OR
        a.document_number ILIKE '%' || p_search_query || '%' OR
        r.name ILIKE '%' || p_search_query || '%' OR
        h.name ILIKE '%' || p_search_query || '%' OR
        c.name ILIKE '%' || p_search_query || '%'
      ))
    ))
    -- Specific field filters
    AND (p_status IS NULL OR a.status = p_status)
    AND (p_headquarter_id IS NULL OR a.headquarter_id = p_headquarter_id)
    AND (p_season_id IS NULL OR a.season_id = p_season_id)
    AND (p_role_id IS NULL OR a.role_id = p_role_id)
    AND (p_role_name IS NULL OR r.name ILIKE '%' || p_role_name || '%')
    AND (p_country IS NULL OR c.name ILIKE '%' || p_country || '%')
    -- Access control
    AND public.fn_can_access_agreement(a.headquarter_id, a.user_id);

  -- Get paginated results with relevance ranking
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
           COALESCE(jsonb_build_object(
             'role_id', r.id, 
             'role_name', r.name, 
             'role_description', r.description, 
             'role_code', r.code, 
             'role_level', r.level
           ), '{}'::jsonb) AS role,
           COALESCE(jsonb_build_object(
             'headquarter_id', h.id,
             'headquarter_name', h.name,
             'headquarter_address', h.address,
             'country_id', c.id,
             'country_name', c.name
           ), '{}'::jsonb) AS headquarter,
           -- Calculate relevance score for search results
           CASE 
             WHEN p_use_fts AND p_search_query IS NOT NULL THEN 
               GREATEST(
                 ts_rank(a.fts_name_lastname, v_tsquery),
                 ts_rank(to_tsvector('spanish', coalesce(r.name, '')), v_tsquery),
                 ts_rank(to_tsvector('spanish', coalesce(h.name, '')), v_tsquery),
                 ts_rank(to_tsvector('spanish', coalesce(c.name, '')), v_tsquery)
               )
             ELSE 0
           END AS search_rank
    FROM public.agreements a
    LEFT JOIN public.roles r ON a.role_id = r.id
    LEFT JOIN public.headquarters h ON a.headquarter_id = h.id
    LEFT JOIN public.countries c ON h.country_id = c.id
    WHERE 
      -- General search across multiple fields
      (p_search_query IS NULL OR (
        (p_use_fts AND (
          a.fts_name_lastname @@ v_tsquery OR
          to_tsvector('spanish', coalesce(r.name, '')) @@ v_tsquery OR
          to_tsvector('spanish', coalesce(h.name, '')) @@ v_tsquery OR
          to_tsvector('spanish', coalesce(c.name, '')) @@ v_tsquery
        )) OR
        (NOT p_use_fts AND (
          a.name ILIKE '%' || p_search_query || '%' OR 
          a.last_name ILIKE '%' || p_search_query || '%' OR
          a.email ILIKE '%' || p_search_query || '%' OR
          a.document_number ILIKE '%' || p_search_query || '%' OR
          r.name ILIKE '%' || p_search_query || '%' OR
          h.name ILIKE '%' || p_search_query || '%' OR
          c.name ILIKE '%' || p_search_query || '%'
        ))
      ))
      -- Specific field filters
      AND (p_status IS NULL OR a.status = p_status)
      AND (p_headquarter_id IS NULL OR a.headquarter_id = p_headquarter_id)
      AND (p_season_id IS NULL OR a.season_id = p_season_id)
      AND (p_role_id IS NULL OR a.role_id = p_role_id)
      AND (p_role_name IS NULL OR r.name ILIKE '%' || p_role_name || '%')
      AND (p_country IS NULL OR c.name ILIKE '%' || p_country || '%')
      -- Access control
      AND public.fn_can_access_agreement(a.headquarter_id, a.user_id)
    ORDER BY 
      -- Relevance ranking for search queries
      CASE WHEN p_use_fts AND p_search_query IS NOT NULL THEN 
        GREATEST(
          ts_rank(a.fts_name_lastname, v_tsquery),
          ts_rank(to_tsvector('spanish', coalesce(r.name, '')), v_tsquery),
          ts_rank(to_tsvector('spanish', coalesce(h.name, '')), v_tsquery),
          ts_rank(to_tsvector('spanish', coalesce(c.name, '')), v_tsquery)
        )
      END DESC,
      a.created_at DESC
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
    ),
    'filters', jsonb_build_object(
      'search_query', p_search_query,
      'status', p_status,
      'headquarter_id', p_headquarter_id,
      'season_id', p_season_id,
      'role_id', p_role_id,
      'role_name', p_role_name,
      'country', p_country,
      'use_fts', p_use_fts
    )
  );

  RETURN v_results;
END;
$$;

-- Convenience function to get a single agreement by ID
CREATE OR REPLACE FUNCTION get_agreement_by_id(p_agreement_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  v_result JSONB;
BEGIN
  -- Use the main search function with ID filter
  SELECT jsonb_extract_path(search_agreements(NULL, 1, 0), 'data', '0') INTO v_result;
  
  -- Alternative direct query for better performance on single ID lookup
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
    COALESCE(jsonb_build_object(
      'role_id', r.id, 
      'role_name', r.name, 
      'role_description', r.description, 
      'role_code', r.code, 
      'role_level', r.level
    ), '{}'::jsonb),
    COALESCE(jsonb_build_object(
      'headquarter_id', h.id,
      'headquarter_name', h.name,
      'headquarter_address', h.address,
      'country_id', c.id,
      'country_name', c.name
    ), '{}'::jsonb)
  )) INTO v_result
  FROM public.agreements a
  LEFT JOIN public.roles r ON a.role_id = r.id
  LEFT JOIN public.headquarters h ON a.headquarter_id = h.id
  LEFT JOIN public.countries c ON h.country_id = c.id
  WHERE a.id = p_agreement_id
    AND public.fn_can_access_agreement(a.headquarter_id, a.user_id);

  IF v_result IS NULL THEN
    RETURN jsonb_build_object('error', 'Agreement not found or access denied');
  END IF;

  RETURN v_result;
END;
$$;
