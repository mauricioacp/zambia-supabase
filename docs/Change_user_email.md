```sql
sql
-- Change User Email (using only emails)
DO $$
DECLARE
v_old_email TEXT := 'old-email@example.com';  -- Replace with current email
v_new_email TEXT := 'new-email@example.com';  -- Replace with new email
v_user_id UUID;
BEGIN
-- Find user_id from auth.users
SELECT id INTO v_user_id FROM auth.users WHERE email = v_old_email;

         IF v_user_id IS NULL THEN
             RAISE EXCEPTION 'User not found with email: %', v_old_email;
         END IF;

         -- 1. Update auth.users
         UPDATE auth.users SET email = v_new_email WHERE email = v_old_email;
         RAISE NOTICE 'Updated auth.users';

         -- 2. Update agreements
         UPDATE public.agreements SET email = v_new_email WHERE user_id = v_user_id;
         RAISE NOTICE 'Updated agreements: % rows', ROW_COUNT;

         -- 3. Update user_search_index
         UPDATE public.user_search_index SET email = v_new_email WHERE user_id = v_user_id;
         RAISE NOTICE 'Updated user_search_index: % rows', ROW_COUNT;

         RAISE NOTICE 'Done! Email changed from % to %', v_old_email, v_new_email;
     END $$;

Verify first:

sql
-- Check what will be updated
SELECT 'auth.users' as source, id, email FROM auth.users WHERE email = 'old-email@example.com'
UNION ALL
SELECT 'agreements', user_id, email FROM public.agreements
WHERE user_id = (SELECT id FROM auth.users WHERE email = 'old-email@example.com')
UNION ALL
SELECT 'user_search_index', user_id, email FROM public.user_search_index
WHERE user_id = (SELECT id FROM auth.users WHERE email = 'old-email@example.com');
```
