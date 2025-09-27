# Role Change Guard: Preventing Privilege Escalation

Goal: when changing a user’s role, the executor of the change must not assign a role with a level higher than their own.

This document describes the database-side solution (SQL functions and optional RLS policy), the migration SQL to add it, and concrete steps to verify the behavior in production safely.

## Context and assumptions

- Role hierarchy lives in `public.roles(level INT, code TEXT, ...)`.
- Agreements link a user to their current role: `public.agreements(id, user_id, role_id, ...)`.
- We already expose helpers that read the current user’s role from JWT/auth metadata:
  - `public.fn_get_current_role_level()` defined in `schemas/rbac_helpers.sql`.
- Application code may continue to update auth metadata via admin APIs. The SQL function below focuses on safely updating the agreement’s `role_id` and enforcing the “no escalation” rule inside the database.

## What we add

1) A lightweight checker to validate a target role can be assigned by the current executor.

```sql
CREATE OR REPLACE FUNCTION public.can_assign_role(p_new_role_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_executor_level integer := public.fn_get_current_role_level();
  v_target_level   integer;
BEGIN
  -- If unauthenticated, deny
  IF auth.uid() IS NULL THEN
    RETURN false;
  END IF;

  SELECT level INTO v_target_level
  FROM public.roles
  WHERE id = p_new_role_id
    AND status = 'active';

  IF v_target_level IS NULL THEN
    RETURN false; -- non-existent or inactive role cannot be assigned
  END IF;

  RETURN v_executor_level >= v_target_level;
END;
$$;

GRANT EXECUTE ON FUNCTION public.can_assign_role(uuid) TO authenticated;
```

2) A safe mutator to change the agreement role with the precondition enforced. It also returns a compact audit payload that the caller can log.

```sql
CREATE OR REPLACE FUNCTION public.change_agreement_role(
  p_agreement_id uuid,
  p_new_role_id  uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_executor_id     uuid := auth.uid();
  v_executor_level  integer := public.fn_get_current_role_level();
  v_target_level    integer;
  v_old_role_id     uuid;
  v_user_id         uuid;
BEGIN
  IF v_executor_id IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated';
  END IF;

  -- Validate target role
  SELECT level INTO v_target_level
  FROM public.roles
  WHERE id = p_new_role_id
    AND status = 'active';
  IF v_target_level IS NULL THEN
    RAISE EXCEPTION 'Target role not found or inactive';
  END IF;

  -- Enforce: executor must have level >= target role level
  IF v_executor_level < v_target_level THEN
    RAISE EXCEPTION 'Insufficient role level: executor %, target %', v_executor_level, v_target_level
      USING ERRCODE = '42501';
  END IF;

  -- Load agreement and lock for update
  SELECT role_id, user_id
    INTO v_old_role_id, v_user_id
  FROM public.agreements
  WHERE id = p_agreement_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Agreement not found';
  END IF;

  IF v_old_role_id = p_new_role_id THEN
    RAISE EXCEPTION 'User already has this role';
  END IF;

  -- Perform update
  UPDATE public.agreements
     SET role_id = p_new_role_id,
         updated_at = timezone('utc', now())
   WHERE id = p_agreement_id;

  RETURN jsonb_build_object(
    'agreement_id', p_agreement_id,
    'user_id',      v_user_id,
    'old_role_id',  v_old_role_id,
    'new_role_id',  p_new_role_id,
    'executor_id',  v_executor_id,
    'executor_level', v_executor_level,
    'target_role_level', v_target_level,
    'changed_at', timezone('utc', now())
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.change_agreement_role(uuid, uuid) TO authenticated;
```

3) Optional defense-in-depth RLS policy to prevent direct updates that bypass the function. If you already have strict UPDATE policies on `agreements`, keep them; otherwise consider adding this policy.

```sql
-- Prevent raising someone above your own level when changing agreement role directly
CREATE POLICY agreements_prevent_role_escalation
ON public.agreements
FOR UPDATE TO authenticated
USING (true)
WITH CHECK (
  CASE
    WHEN new.role_id IS DISTINCT FROM old.role_id THEN
      public.fn_get_current_role_level() >= (
        SELECT level FROM public.roles WHERE id = new.role_id
      )
    ELSE true
  END
);
```

Notes:
- All functions use `SECURITY DEFINER` with `search_path` pinned to `''` for safety and to make the check reliable even with RLS. Ensure the owner of these functions is a trusted role (typically `postgres`).
- The function intentionally does not attempt to update `auth.users` metadata. Keep using your admin API (as you already do in `functions/akademy-app/change-role.ts`) to update Supabase Auth metadata after the DB update succeeds.

## Migration: file contents

Create a new migration file (example name): `migrations/20250907070000_role_change_guard.sql` with the following content:

```sql
-- Up
-- 1) function to check assignment
CREATE OR REPLACE FUNCTION public.can_assign_role(p_new_role_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_executor_level integer := public.fn_get_current_role_level();
  v_target_level   integer;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN false;
  END IF;
  SELECT level INTO v_target_level FROM public.roles WHERE id = p_new_role_id AND status = 'active';
  IF v_target_level IS NULL THEN RETURN false; END IF;
  RETURN v_executor_level >= v_target_level;
END;
$$;
GRANT EXECUTE ON FUNCTION public.can_assign_role(uuid) TO authenticated;

-- 2) function to perform the change
CREATE OR REPLACE FUNCTION public.change_agreement_role(
  p_agreement_id uuid,
  p_new_role_id  uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_executor_id     uuid := auth.uid();
  v_executor_level  integer := public.fn_get_current_role_level();
  v_target_level    integer;
  v_old_role_id     uuid;
  v_user_id         uuid;
BEGIN
  IF v_executor_id IS NULL THEN RAISE EXCEPTION 'Unauthenticated'; END IF;

  SELECT level INTO v_target_level FROM public.roles WHERE id = p_new_role_id AND status = 'active';
  IF v_target_level IS NULL THEN RAISE EXCEPTION 'Target role not found or inactive'; END IF;

  IF v_executor_level < v_target_level THEN
    RAISE EXCEPTION 'Insufficient role level: executor %, target %', v_executor_level, v_target_level USING ERRCODE = '42501';
  END IF;

  SELECT role_id, user_id INTO v_old_role_id, v_user_id FROM public.agreements WHERE id = p_agreement_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Agreement not found'; END IF;
  IF v_old_role_id = p_new_role_id THEN RAISE EXCEPTION 'User already has this role'; END IF;

  UPDATE public.agreements SET role_id = p_new_role_id, updated_at = timezone('utc', now()) WHERE id = p_agreement_id;

  RETURN jsonb_build_object(
    'agreement_id', p_agreement_id,
    'user_id',      v_user_id,
    'old_role_id',  v_old_role_id,
    'new_role_id',  p_new_role_id,
    'executor_id',  v_executor_id,
    'executor_level', v_executor_level,
    'target_role_level', v_target_level,
    'changed_at', timezone('utc', now())
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.change_agreement_role(uuid, uuid) TO authenticated;

-- 3) Optional RLS policy (defense in depth)
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'agreements' AND policyname = 'agreements_prevent_role_escalation'
  ) THEN
    EXECUTE $$
      CREATE POLICY agreements_prevent_role_escalation
      ON public.agreements
      FOR UPDATE TO authenticated
      USING (true)
      WITH CHECK (
        CASE WHEN new.role_id IS DISTINCT FROM old.role_id THEN
          public.fn_get_current_role_level() >= (SELECT level FROM public.roles WHERE id = new.role_id)
        ELSE true END
      )
    $$;
  END IF;
END $$;

-- Down (optional, if you maintain down migrations)
-- REVOKE EXECUTE ON FUNCTION public.change_agreement_role(uuid, uuid) FROM authenticated;
-- DROP FUNCTION IF EXISTS public.change_agreement_role(uuid, uuid);
-- REVOKE EXECUTE ON FUNCTION public.can_assign_role(uuid) FROM authenticated;
-- DROP FUNCTION IF EXISTS public.can_assign_role(uuid);
-- DROP POLICY IF EXISTS agreements_prevent_role_escalation ON public.agreements;
```

## How to integrate in app code

- Prefer calling `SELECT public.change_agreement_role(:agreement_id, :new_role_id);` rather than updating `agreements.role_id` directly.
- Keep your existing backend step that updates the user’s `auth.users.raw_user_meta_data` (role, role_level, etc.) after the DB update succeeds. If the metadata update fails, roll back or compensate (your existing TypeScript already performs a DB revert on failure).

## How to verify in production (safe, rollback testing)

These checks assume you can connect with an admin psql role. Never paste secrets inline; store them in env vars first.

1) Verify the function exists and is executable by `authenticated`:

```bash
psql "$PROD_DATABASE_URL" -v ON_ERROR_STOP=1 -c "\
SELECT n.nspname AS schema, p.proname AS function, pg_catalog.pg_get_function_identity_arguments(p.oid) AS args, r.rolname AS owner\n\
FROM pg_proc p\n\
JOIN pg_namespace n ON n.oid = p.pronamespace\n\
JOIN pg_roles r ON r.oid = p.proowner\n\
WHERE n.nspname = 'public' AND p.proname IN ('can_assign_role','change_agreement_role');\
" && \
psql "$PROD_DATABASE_URL" -v ON_ERROR_STOP=1 -c "\
SELECT grantee, privilege_type\n\
FROM information_schema.role_routine_grants\n\
WHERE routine_schema='public' AND routine_name IN ('can_assign_role','change_agreement_role');\
"
```

2) Pick a real production user to impersonate (their JWT would normally set `auth.uid()`). We can simulate this in psql by setting PostgREST claims for the session.

- Find a user with a specific role level (example: manager level 50):

```sql
SELECT id, email, raw_user_meta_data->>'role' AS role_code, (raw_user_meta_data->>'role_level')::int AS role_level
FROM auth.users
WHERE (raw_user_meta_data->>'role_level')::int = 50
LIMIT 1;
```

- Pick two role IDs for testing (one above level 50, one below):

```sql
SELECT id AS high_role_id, name, level FROM public.roles WHERE level > 50 ORDER BY level DESC LIMIT 1;
SELECT id AS low_role_id,  name, level FROM public.roles WHERE level <= 50 ORDER BY level DESC LIMIT 1;
```

- Pick a target agreement to test against (avoid critical users; you can run inside a transaction and roll back):

```sql
SELECT id AS agreement_id, user_id, role_id FROM public.agreements LIMIT 1;
```

3) Simulate the executor in psql and test both allow and deny paths inside a transaction:

```sql
BEGIN; -- everything is rolled back at the end

-- Replace with real values from the queries above
-- Simulate the JWT claims for PostgREST-compatible helpers (auth.uid())
SET LOCAL "request.jwt.claims" = json_build_object(
  'sub',      '00000000-0000-0000-0000-000000000000', -- replace with chosen user id
  'role',     'authenticated',
  'email',    'executor@example.com'
)::text;

-- Sanity check: what does the database think our level is?
SELECT public.fn_get_current_role_level() AS executor_level;

-- Expect: false (cannot assign higher level than ourselves)
SELECT public.can_assign_role('{{HIGH_ROLE_ID}}') AS can_assign_high;

-- Expect: true (can assign role at or below our level)
SELECT public.can_assign_role('{{LOW_ROLE_ID}}')  AS can_assign_low;

-- Attempt actual change with a higher role (should raise exception)
-- Replace {{AGREEMENT_ID}} and {{HIGH_ROLE_ID}} with real values
DO $$ BEGIN
  PERFORM public.change_agreement_role('{{AGREEMENT_ID}}'::uuid, '{{HIGH_ROLE_ID}}'::uuid);
EXCEPTION WHEN others THEN
  RAISE NOTICE 'Expected failure: %', SQLERRM;
END $$;

-- Attempt actual change with an allowed lower/equal role (should succeed)
-- This will be rolled back when we ROLLBACK.
SELECT public.change_agreement_role('{{AGREEMENT_ID}}'::uuid, '{{LOW_ROLE_ID}}'::uuid);

ROLLBACK; -- ensure no persistent change in production
```

4) Optional: verify the RLS policy works (if you added it). This is a rough check that a direct UPDATE would be blocked if trying to escalate above the executor’s level. Still inside a transaction and with the same simulated user claims:

```sql
BEGIN;

-- Expect this to fail if it escalates beyond executor level
UPDATE public.agreements SET role_id = '{{HIGH_ROLE_ID}}'::uuid WHERE id = '{{AGREEMENT_ID}}'::uuid;

ROLLBACK;
```

## Verifying via REST (Supabase RPC)

If you expose `change_agreement_role` via PostgREST, you can verify with curl using a user JWT. Do not paste secrets; export them first.

```bash
# Example (replace env var values securely beforehand):
# export SUPABASE_URL=...
# export SUPABASE_ANON_KEY=...
# export USER_JWT=...  # JWT for a real user in production

curl -sS \
  -X POST "$SUPABASE_URL/rest/v1/rpc/change_agreement_role" \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H "Authorization: Bearer $USER_JWT" \
  -H "Content-Type: application/json" \
  -d '{
    "p_agreement_id": "{{AGREEMENT_ID}}",
    "p_new_role_id":  "{{LOW_OR_HIGH_ROLE_ID}}"
  }'
```

- Expect HTTP 403/400 on violation, 200 with a JSON body on success.
- When testing in production, target a non-critical agreement and revert the change immediately after, or perform the call against a staging environment first.

## Rollout notes

- Ensure the functions’ owner is `postgres` (or a controlled DBA role), and that only `authenticated` (and higher) can EXECUTE them.
- Keep app code changes minimal: call the function first; if it succeeds, then update auth metadata. If the metadata update fails, revert the agreement change (current code path already does this).
- Consider adding an audit trail (e.g., insert into `workflow_audit` or `audit`) inside `change_agreement_role` if you need persistent logs.

## Related files

- `schemas/rbac_helpers.sql` (already in repo): provides `fn_get_current_role_level()`
- `schemas/roles.sql`: role definitions and levels
- `functions/akademy-app/change-role.ts`: backend endpoint already checking levels and updating auth metadata

