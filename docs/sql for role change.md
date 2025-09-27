-- Change user role by agreement ID
-- Replace the placeholder values with actual IDs
DO $$
DECLARE
v_agreement_id UUID := 'YOUR_AGREEMENT_ID_HERE';
v_new_role_id UUID := 'YOUR_NEW_ROLE_ID_HERE';
v_user_id UUID;
v_role_record RECORD;
v_agreement_record RECORD;
BEGIN
-- Get agreement and user details
SELECT * INTO v_agreement_record
FROM agreements
WHERE id = v_agreement_id;

      IF NOT FOUND THEN
          RAISE EXCEPTION 'Agreement not found';
      END IF;

      v_user_id := v_agreement_record.user_id;

      IF v_user_id IS NULL THEN
          RAISE EXCEPTION 'Agreement has no associated user';
      END IF;

      -- Get new role details
      SELECT * INTO v_role_record
      FROM roles
      WHERE id = v_new_role_id AND status = 'active';

      IF NOT FOUND THEN
          RAISE EXCEPTION 'Role not found or inactive';
      END IF;

      -- Update agreement
      UPDATE agreements
      SET role_id = v_new_role_id,
          updated_at = NOW()
      WHERE id = v_agreement_id;

      -- Update user metadata
      UPDATE auth.users
      SET raw_user_meta_data = jsonb_set(
          jsonb_set(
              jsonb_set(
                  raw_user_meta_data,
                  '{role}', to_jsonb(v_role_record.code)
              ),
              '{role_level}', to_jsonb(v_role_record.level)
          ),
          '{role_id}', to_jsonb(v_role_record.id::text)
      )
      WHERE id = v_user_id;

      RAISE NOTICE 'Successfully changed role for user % to %', v_user_id, v_role_record.name;
END $$;

Query by Email Version

-- Change role by user email
DO $$
DECLARE
v_user_email TEXT := 'user@example.com';
v_new_role_code TEXT := 'coordinator'; -- Use role code instead of ID
v_agreement_id UUID;
v_user_id UUID;
v_new_role_id UUID;
v_role_record RECORD;
BEGIN
-- Get user ID from email
SELECT id INTO v_user_id
FROM auth.users
WHERE email = v_user_email;

      IF NOT FOUND THEN
          RAISE EXCEPTION 'User not found with email: %', v_user_email;
      END IF;

      -- Get active agreement for user
      SELECT id INTO v_agreement_id
      FROM agreements
      WHERE user_id = v_user_id
      AND status = 'active'
      ORDER BY created_at DESC
      LIMIT 1;

      IF NOT FOUND THEN
          RAISE EXCEPTION 'No active agreement found for user';
      END IF;

      -- Get role details by code
      SELECT * INTO v_role_record
      FROM roles
      WHERE code = v_new_role_code AND status = 'active';

      IF NOT FOUND THEN
          RAISE EXCEPTION 'Role not found or inactive: %', v_new_role_code;
      END IF;

      -- Update agreement
      UPDATE agreements
      SET role_id = v_role_record.id,
          updated_at = NOW()
      WHERE id = v_agreement_id;

      -- Update user metadata with all role fields
      UPDATE auth.users
      SET raw_user_meta_data = raw_user_meta_data ||
          jsonb_build_object(
              'role', v_role_record.code,
              'role_level', v_role_record.level,
              'role_id', v_role_record.id::text
          )
      WHERE id = v_user_id;

      RAISE NOTICE 'Successfully changed role for % to %', v_user_email, v_role_record.name;
END $$;

Reusable Function Version

-- Create a reusable function for role changes
CREATE OR REPLACE FUNCTION change_user_role(
p_agreement_id UUID,
p_new_role_id UUID
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
v_user_id UUID;
v_old_role_id UUID;
v_new_role RECORD;
v_old_role RECORD;
v_agreement RECORD;
BEGIN
-- Get agreement details
SELECT * INTO v_agreement
FROM agreements
WHERE id = p_agreement_id;

      IF NOT FOUND THEN
          RETURN jsonb_build_object('success', false, 'error', 'Agreement not found');
      END IF;

      v_user_id := v_agreement.user_id;
      v_old_role_id := v_agreement.role_id;

      IF v_user_id IS NULL THEN
          RETURN jsonb_build_object('success', false, 'error', 'No user associated with agreement');
      END IF;

      IF v_old_role_id = p_new_role_id THEN
          RETURN jsonb_build_object('success', false, 'error', 'New role is same as current role');
      END IF;

      -- Get old and new role details
      SELECT * INTO v_old_role FROM roles WHERE id = v_old_role_id;
      SELECT * INTO v_new_role FROM roles WHERE id = p_new_role_id AND status = 'active';

      IF v_new_role.id IS NULL THEN
          RETURN jsonb_build_object('success', false, 'error', 'New role not found or inactive');
      END IF;

      -- Update agreement
      UPDATE agreements
      SET role_id = p_new_role_id,
          updated_at = NOW()
      WHERE id = p_agreement_id;

      -- Update user metadata
      UPDATE auth.users
      SET raw_user_meta_data = raw_user_meta_data ||
          jsonb_build_object(
              'role', v_new_role.code,
              'role_level', v_new_role.level,
              'role_id', v_new_role.id::text
          ),
          updated_at = NOW()
      WHERE id = v_user_id;

      RETURN jsonb_build_object(
          'success', true,
          'user_id', v_user_id,
          'agreement_id', p_agreement_id,
          'old_role', jsonb_build_object(
              'id', v_old_role.id,
              'code', v_old_role.code,
              'name', v_old_role.name,
              'level', v_old_role.level
          ),
          'new_role', jsonb_build_object(
              'id', v_new_role.id,
              'code', v_new_role.code,
              'name', v_new_role.name,
              'level', v_new_role.level
          )
      );
END $$;

-- Usage example:
SELECT change_user_role(
'agreement-id-here'::uuid,
'new-role-id-here'::uuid
);

Quick Reference Queries

List all roles with their IDs:

SELECT id, code, name, level
FROM roles
WHERE status = 'active'
ORDER BY level DESC;

Find agreement and user by email:

SELECT
a.id as agreement_id,
a.user_id,
u.email,
r.code as current_role,
r.level as current_level
FROM agreements a
JOIN auth.users u ON u.id = a.user_id
JOIN roles r ON r.id = a.role_id
WHERE u.email = 'user@example.com'
AND a.status = 'active';

Verify role change was successful:

SELECT
u.email,
u.raw_user_meta_data->>'role' as metadata_role,
u.raw_user_meta_data->>'role_level' as metadata_level,
r.code as agreement_role,
r.level as agreement_level
FROM auth.users u
JOIN agreements a ON a.user_id = u.id
JOIN roles r ON r.id = a.role_id
WHERE u.email = 'user@example.com';
