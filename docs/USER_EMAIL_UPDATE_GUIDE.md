# User Email Update Function Guide

## Overview

The `fn_update_user_email()` function provides a safe and controlled way to update user emails in the Akademia Supabase system. It synchronizes email changes across both the authentication system (`auth.users`) and the application data (`agreements` table).

## Why This Function Exists

The `agreements` table has Row Level Security (RLS) policies that prevent direct email updates:

```sql
-- From agreements RLS policy:
email = email AND  -- Email cannot be changed via table update
```

This function bypasses RLS using `SECURITY DEFINER` while maintaining proper authorization checks.

## Function Signature

```sql
public.fn_update_user_email(
    p_user_id uuid,      -- The user ID whose email to update
    p_new_email text     -- The new email address
) RETURNS jsonb
```

## Authorization Rules

The function enforces strict authorization:

1. **General Directors** (level 95+) can update ANY user's email
2. **Regular users** can ONLY update their OWN email
3. **Unauthenticated requests** are rejected

## Features

### ✅ Atomic Updates
- Updates both `auth.users` and `agreements` tables in a single transaction
- If either update fails, the entire operation rolls back

### ✅ Email Validation
- Validates email format using regex
- Checks for duplicate emails across all users
- Prevents empty or malformed emails

### ✅ Security
- Uses `SECURITY DEFINER` with `search_path = ''` (Supabase best practice)
- Fully qualified table names to prevent SQL injection
- RBAC enforcement using existing `fn_get_current_role_level()` helper

### ✅ Email Re-confirmation
- Sets `email_confirmed_at = NULL` in `auth.users`
- Forces user to re-verify their new email address
- Follows Supabase security best practices

### ✅ Comprehensive Response
- Returns JSON with operation details
- Includes old and new email for audit trails
- Reports number of updated agreement records

## Usage Examples

### Example 1: User Updating Their Own Email

```sql
-- As an authenticated user, update your own email
SELECT public.fn_update_user_email(
    auth.uid(),                    -- Your own user ID
    'newemail@example.com'         -- Your new email
);
```

**Response:**
```json
{
  "success": true,
  "user_id": "550e8400-e29b-41d4-a716-446655440000",
  "old_email": "oldemail@example.com",
  "new_email": "newemail@example.com",
  "updated_agreements": 2,
  "email_confirmation_required": true,
  "updated_at": "2025-11-18T23:15:30.123456+00:00"
}
```

### Example 2: Admin Updating Another User's Email

```sql
-- As a General Director (level 95+), update someone else's email
SELECT public.fn_update_user_email(
    '123e4567-e89b-12d3-a456-426614174000',  -- Target user ID
    'newuseremail@example.com'               -- New email for that user
);
```

**Response:**
```json
{
  "success": true,
  "user_id": "123e4567-e89b-12d3-a456-426614174000",
  "old_email": "olduser@example.com",
  "new_email": "newuseremail@example.com",
  "updated_agreements": 1,
  "email_confirmation_required": true,
  "updated_at": "2025-11-18T23:16:45.789012+00:00"
}
```

### Example 3: Using from Supabase Client (TypeScript)

```typescript
import { createClient } from '@supabase/supabase-js';

const supabase = createClient(url, anonKey);

// User must be authenticated
const { data: session } = await supabase.auth.getSession();

if (session) {
  // Call the function via RPC
  const { data, error } = await supabase.rpc('fn_update_user_email', {
    p_user_id: session.user.id,
    p_new_email: 'newemail@example.com'
  });

  if (error) {
    console.error('Failed to update email:', error);
  } else {
    console.log('Email updated successfully:', data);

    if (data.success) {
      // Notify user to check their email for confirmation
      alert('Please check your new email to confirm the change');
    }
  }
}
```

### Example 4: Using from Edge Function

```typescript
import { createClient } from 'jsr:@supabase/supabase-js@2';

export default async function handler(req: Request) {
  const supabaseAdmin = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, // Admin access
  );

  const { user_id, new_email } = await req.json();

  const { data, error } = await supabaseAdmin.rpc('fn_update_user_email', {
    p_user_id: user_id,
    p_new_email: new_email
  });

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' }
    });
  }

  return new Response(JSON.stringify(data), {
    status: 200,
    headers: { 'Content-Type': 'application/json' }
  });
}
```

## Error Handling

The function returns error information in the response JSON:

### Error: Not Authenticated
```json
{
  "success": false,
  "error": "Not authenticated",
  "error_detail": "P0001"
}
```

### Error: Invalid Email Format
```json
{
  "success": false,
  "error": "Invalid email format",
  "error_detail": "P0001"
}
```

### Error: User Not Found
```json
{
  "success": false,
  "error": "User not found",
  "error_detail": "P0001"
}
```

### Error: Insufficient Permissions
```json
{
  "success": false,
  "error": "Insufficient permissions to update email",
  "error_detail": "P0001"
}
```

### Error: Email Already in Use
```json
{
  "success": false,
  "error": "Email already in use by another user",
  "error_detail": "P0001"
}
```

## Complete TypeScript Example with Error Handling

```typescript
import { createClient } from '@supabase/supabase-js';

interface EmailUpdateResponse {
  success: boolean;
  user_id?: string;
  old_email?: string;
  new_email?: string;
  updated_agreements?: number;
  email_confirmation_required?: boolean;
  updated_at?: string;
  error?: string;
  error_detail?: string;
}

async function updateUserEmail(
  userId: string,
  newEmail: string
): Promise<EmailUpdateResponse> {
  const supabase = createClient(
    process.env.SUPABASE_URL!,
    process.env.SUPABASE_ANON_KEY!
  );

  const { data, error } = await supabase.rpc('fn_update_user_email', {
    p_user_id: userId,
    p_new_email: newEmail
  });

  if (error) {
    throw new Error(`RPC Error: ${error.message}`);
  }

  return data as EmailUpdateResponse;
}

// Usage
try {
  const result = await updateUserEmail(
    '550e8400-e29b-41d4-a716-446655440000',
    'newemail@example.com'
  );

  if (result.success) {
    console.log('✅ Email updated successfully!');
    console.log(`   Old: ${result.old_email}`);
    console.log(`   New: ${result.new_email}`);
    console.log(`   Updated ${result.updated_agreements} agreement(s)`);
    console.log('⚠️  User must confirm new email address');
  } else {
    console.error('❌ Failed to update email:', result.error);
  }
} catch (error) {
  console.error('❌ Unexpected error:', error);
}
```

## What Gets Updated

When you call this function, the following changes occur:

### In `auth.users` table:
```sql
UPDATE auth.users SET
  email = 'newemail@example.com',
  email_confirmed_at = NULL,  -- Forces re-confirmation
  updated_at = NOW()
WHERE id = 'user-uuid';
```

### In `agreements` table:
```sql
UPDATE agreements SET
  email = 'newemail@example.com',
  updated_at = NOW()
WHERE user_id = 'user-uuid';
```

**Note:** If a user has multiple agreements (e.g., across different seasons), ALL are updated.

## Security Considerations

### ✅ Safe Patterns
```typescript
// ✅ User updating their own email
const { data: session } = await supabase.auth.getSession();
await supabase.rpc('fn_update_user_email', {
  p_user_id: session.user.id,  // Own ID
  p_new_email: 'newemail@example.com'
});

// ✅ Admin updating user email (with level 95+ role)
await supabaseAdmin.rpc('fn_update_user_email', {
  p_user_id: targetUserId,
  p_new_email: 'newemail@example.com'
});
```

### ❌ Unsafe Patterns
```typescript
// ❌ Trying to update someone else's email without proper permissions
// Will fail with "Insufficient permissions" error
await supabase.rpc('fn_update_user_email', {
  p_user_id: 'someone-elses-uuid',  // Not your ID, not admin
  p_new_email: 'hacked@example.com'
});

// ❌ Using raw SQL to bypass function
// Will fail due to RLS policies on agreements table
await supabase.from('agreements')
  .update({ email: 'newemail@example.com' })
  .eq('user_id', userId);
```

## Testing

### Manual Testing in Supabase SQL Editor

1. **Create a test user** (if needed):
```sql
-- Use admin/service role
INSERT INTO auth.users (id, email)
VALUES (
  '123e4567-e89b-12d3-a456-426614174000',
  'test@example.com'
);
```

2. **Test the function**:
```sql
SELECT public.fn_update_user_email(
  '123e4567-e89b-12d3-a456-426614174000',
  'newemail@example.com'
);
```

3. **Verify the update**:
```sql
-- Check auth.users
SELECT email, email_confirmed_at
FROM auth.users
WHERE id = '123e4567-e89b-12d3-a456-426614174000';

-- Check agreements
SELECT email, updated_at
FROM agreements
WHERE user_id = '123e4567-e89b-12d3-a456-426614174000';
```

### Automated Test (Deno)

```typescript
import { assertEquals } from 'https://deno.land/std/testing/asserts.ts';
import { createClient } from 'jsr:@supabase/supabase-js@2';

Deno.test('fn_update_user_email - user updates own email', async () => {
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!
  );

  // Sign in as test user
  const { data: session } = await supabase.auth.signInWithPassword({
    email: 'test@example.com',
    password: 'testpassword'
  });

  // Update email
  const { data } = await supabase.rpc('fn_update_user_email', {
    p_user_id: session.user.id,
    p_new_email: 'updated@example.com'
  });

  assertEquals(data.success, true);
  assertEquals(data.new_email, 'updated@example.com');
  assertEquals(data.email_confirmation_required, true);
});
```

## Migration Information

**File:** `migrations/20251118231030_add_user_email_update_function.sql`
**Schema:** `schemas/user_email_functions.sql`

To apply this migration:

```bash
# Local development
supabase db reset

# Production
npx supabase db push
```

## Related Documentation

- [Environment Synchronization Guide](./ENVIRONMENT_SYNCHRONIZATION_GUIDE.md)
- [Production Deployment Guide](./PRODUCTION_DEPLOYMENT_GUIDE.md)
- [RBAC Helpers](../schemas/rbac_helpers.sql)
- [Agreements Schema](../schemas/agreements.sql)
- [Supabase Auth Docs](https://supabase.com/docs/guides/auth)

## Troubleshooting

### Issue: "Not authenticated" error

**Cause:** User is not signed in
**Solution:**
```typescript
// Check authentication status
const { data: session } = await supabase.auth.getSession();
if (!session) {
  // Redirect to login
}
```

### Issue: "Insufficient permissions" error

**Cause:** User trying to update someone else's email without admin privileges
**Solution:**
- Users can only update their own email
- Only General Directors (level 95+) can update other users' emails

### Issue: "Email already in use" error

**Cause:** Another user already has this email
**Solution:**
- Choose a different email address
- Verify the email isn't already registered

### Issue: Function not found

**Cause:** Migration not applied
**Solution:**
```bash
# Check if migration is applied
supabase migration list

# Apply migration
supabase db reset  # Local
npx supabase db push  # Production
```

## Best Practices

1. **Always check the response**:
```typescript
if (!result.success) {
  // Handle error
  console.error(result.error);
  return;
}
```

2. **Notify users about email confirmation**:
```typescript
if (result.email_confirmation_required) {
  alert('Please check your new email to confirm the change');
}
```

3. **Log email changes for audit**:
```typescript
if (result.success) {
  console.log(`Email changed: ${result.old_email} → ${result.new_email}`);
}
```

4. **Handle errors gracefully**:
```typescript
try {
  const result = await updateUserEmail(userId, newEmail);
  if (!result.success) {
    showError(result.error);
  }
} catch (error) {
  showError('Unexpected error occurred');
}
```

---

**Last Updated:** November 18, 2025
**Maintainer:** Development Team
**Related Issues:** Email update functionality requirement
