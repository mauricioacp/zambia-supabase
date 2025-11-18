-- Migration: Add function to update user email in both auth.users and agreements
-- Created: 2025-11-18
-- Description: Implements fn_update_user_email() to allow General Directors (95+)
--              and users to update their own email with proper synchronization

-- Drop function if exists to allow clean updates
DROP FUNCTION IF EXISTS public.fn_update_user_email(uuid, text);

-- Main function to update user email
CREATE OR REPLACE FUNCTION public.fn_update_user_email(
    p_user_id uuid,
    p_new_email text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_current_user_id uuid;
    v_current_role_level integer;
    v_target_user_email text;
    v_updated_agreements integer := 0;
    v_result jsonb;
BEGIN
    -- Get current user ID
    v_current_user_id := auth.uid();

    -- Ensure user is authenticated
    IF v_current_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- Get current user's role level
    v_current_role_level := public.fn_get_current_role_level();

    -- Validate email format (basic validation)
    IF p_new_email IS NULL OR p_new_email !~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' THEN
        RAISE EXCEPTION 'Invalid email format';
    END IF;

    -- Check if target user exists
    SELECT email INTO v_target_user_email
    FROM auth.users
    WHERE id = p_user_id;

    IF v_target_user_email IS NULL THEN
        RAISE EXCEPTION 'User not found';
    END IF;

    -- Authorization check:
    -- 1. General Director+ (level 95+) can update any user's email
    -- 2. Users can update their own email
    IF NOT (v_current_role_level >= 95 OR v_current_user_id = p_user_id) THEN
        RAISE EXCEPTION 'Insufficient permissions to update email';
    END IF;

    -- Check if new email is already in use by another user
    IF EXISTS (
        SELECT 1 FROM auth.users
        WHERE email = p_new_email
        AND id != p_user_id
    ) THEN
        RAISE EXCEPTION 'Email already in use by another user';
    END IF;

    -- Update email in auth.users table
    UPDATE auth.users
    SET
        email = p_new_email,
        email_confirmed_at = NULL, -- Require re-confirmation
        updated_at = NOW()
    WHERE id = p_user_id;

    -- Check if update was successful
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Failed to update email in auth.users';
    END IF;

    -- Update email in all agreements for this user
    UPDATE public.agreements
    SET
        email = p_new_email,
        updated_at = NOW()
    WHERE user_id = p_user_id;

    -- Get number of updated agreements
    GET DIAGNOSTICS v_updated_agreements = ROW_COUNT;

    -- Build result JSON
    v_result := jsonb_build_object(
        'success', true,
        'user_id', p_user_id,
        'old_email', v_target_user_email,
        'new_email', p_new_email,
        'updated_agreements', v_updated_agreements,
        'email_confirmation_required', true,
        'updated_at', NOW()
    );

    RETURN v_result;

EXCEPTION
    WHEN OTHERS THEN
        -- Return error details
        RETURN jsonb_build_object(
            'success', false,
            'error', SQLERRM,
            'error_detail', SQLSTATE
        );
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.fn_update_user_email(uuid, text) TO authenticated;

-- Add function comment
COMMENT ON FUNCTION public.fn_update_user_email(uuid, text) IS
'Updates user email in both auth.users and agreements tables.
Authorization: General Directors (level 95+) can update any user, users can update their own email.
The function atomically updates both tables and requires email re-confirmation.
Returns JSON with success status and update details.

Example usage:
SELECT public.fn_update_user_email(
    ''user-uuid-here'',
    ''newemail@example.com''
);

Returns:
{
  "success": true,
  "user_id": "uuid",
  "old_email": "old@example.com",
  "new_email": "new@example.com",
  "updated_agreements": 2,
  "email_confirmation_required": true,
  "updated_at": "2025-11-18T..."
}';
