# Production Deployment Guide for Akademy Supabase

## Pre-Deployment Checklist

1. **Have these credentials ready:**
   - Supabase project reference ID (from your dashboard)
   - Database password (from your dashboard)
   - Strapi API URL and token (if using migration feature)
   - Personal access token for Supabase CLI (optional)

2. **Create your .env.production file:**
```bash
# Copy the example file
cp .env.production.example .env.production

# Edit with your Strapi credentials (only these are needed)
STRAPI_API_URL=https://your-strapi-instance.com
STRAPI_API_TOKEN=your_strapi_api_token_here
```

## Step 1: Link to Production Project

```bash
# Set your database password
export SUPABASE_DB_PASSWORD="your_database_password"

# Link to your production project
npx supabase link --project-ref your_project_ref

# Verify connection
npx supabase status
```

## Step 2: Reset Production Database (CAREFUL!)

⚠️ **WARNING: This will DELETE ALL DATA in production!**

```bash
# 1. ALWAYS create a backup first
npx supabase db dump -f backup-before-reset-$(date +%Y%m%d-%H%M%S).sql

# 2. Reset the database (includes migrations + seed data)
npx supabase db reset --linked

# You'll be prompted to confirm - type 'y' to proceed
```

## Step 3: Deploy Edge Functions

```bash
# 1. Set your production secrets (Strapi credentials)
npx supabase secrets set --env-file .env.production

# 2. Deploy all functions
npx supabase functions deploy --no-verify-jwt

# Or deploy specific function
npx supabase functions deploy akademy-app --no-verify-jwt
```

## Step 4: Create Superadmin User

### Option A: Using a Script (Recommended)

Create this script as `scripts/create-production-superadmin.ts`:

```typescript
#!/usr/bin/env -S deno run -A

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.0';

// Get these from your Supabase dashboard
const SUPABASE_URL = 'https://your-project.supabase.co';
const SUPABASE_SERVICE_ROLE_KEY = 'your-service-role-key'; // From dashboard settings

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: {
    autoRefreshToken: false,
    persistSession: false
  }
});

async function createSuperAdmin() {
  try {
    // 1. Get headquarter and season
    const { data: hq } = await supabase
      .from('headquarters')
      .select('id')
      .limit(1)
      .single();

    const { data: season } = await supabase
      .from('seasons')
      .select('id')
      .eq('headquarter_id', hq.id)
      .limit(1)
      .single();

    const { data: role } = await supabase
      .from('roles')
      .select('id, level')
      .eq('code', 'superadmin')
      .single();

    // 2. Create agreement
    const { data: agreement } = await supabase
      .from('agreements')
      .insert({
        headquarter_id: hq.id,
        season_id: season.id,
        role_id: role.id,
        status: 'prospect',
        email: 'admin@yourdomain.com', // CHANGE THIS
        name: 'Admin',
        last_name: 'User',
        address: 'HQ',
        volunteering_agreement: true,
        ethical_document_agreement: true,
        mailing_agreement: true,
        age_verification: true,
        signature_data: 'admin-signature',
        document_number: '00000000',
        phone: '+1234567890'
      })
      .select('id')
      .single();

    // 3. Create user
    const password = crypto.randomUUID(); // Generate secure password
    
    const { data: user, error } = await supabase.auth.admin.createUser({
      email: 'admin@yourdomain.com', // CHANGE THIS
      password: password,
      email_confirm: true,
      user_metadata: {
        role: 'superadmin',
        role_level: 100,
        role_id: role.id,
        agreement_id: agreement.id,
        first_name: 'Admin',
        last_name: 'User',
        document_number: '00000000',
        phone: '+1234567890'
      }
    });

    if (error) throw error;

    // 4. Update agreement
    await supabase
      .from('agreements')
      .update({ user_id: user.user.id, status: 'active' })
      .eq('id', agreement.id);

    console.log('✅ Superadmin created successfully!');
    console.log('📧 Email:', 'admin@yourdomain.com');
    console.log('🔑 Password:', password);
    console.log('⚠️  Save this password securely - it won\'t be shown again!');

  } catch (error) {
    console.error('❌ Error:', error.message);
  }
}

await createSuperAdmin();
```

Run it:
```bash
deno run -A scripts/create-production-superadmin.ts
```

### Option B: Using SQL (Alternative)

```sql
-- Run this in Supabase SQL editor after deployment

-- Get IDs
WITH ids AS (
  SELECT 
    (SELECT id FROM headquarters LIMIT 1) as hq_id,
    (SELECT id FROM seasons WHERE headquarter_id = (SELECT id FROM headquarters LIMIT 1) LIMIT 1) as season_id,
    (SELECT id FROM roles WHERE code = 'superadmin') as role_id
)
-- Create agreement
INSERT INTO agreements (
  headquarter_id, season_id, role_id, status,
  email, name, last_name, address,
  volunteering_agreement, ethical_document_agreement,
  mailing_agreement, age_verification, signature_data,
  document_number, phone
)
SELECT 
  hq_id, season_id, role_id, 'prospect',
  'admin@yourdomain.com', 'Admin', 'User', 'HQ',
  true, true, true, true, 'admin-signature',
  '00000000', '+1234567890'
FROM ids;

-- Then use Supabase dashboard to create auth user and link it
```

### Option C: Using the API After Deployment

Once your functions are deployed, create a temporary level 95+ user via SQL/dashboard, then use the API:

```bash
# Use the create-user endpoint with a level 95+ JWT
curl -X POST https://your-project.supabase.co/functions/v1/akademy-app/create-user \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"agreement_id": "agreement-uuid-from-database"}'
```

## Step 5: Verify Deployment

```bash
# 1. Check migration status
npx supabase migration list --remote

# 2. Test function health endpoint
curl https://your-project.supabase.co/functions/v1/akademy-app/health

# 3. Check function logs
npx supabase functions logs akademy-app

# 4. Verify secrets are set
npx supabase secrets list
```

## Complete Deployment Script

Save this as `deploy-to-production.sh`:

```bash
#!/bin/bash

echo "🚀 Starting production deployment..."

# Check if environment variables are set
if [ -z "$SUPABASE_DB_PASSWORD" ]; then
    echo "❌ Please set SUPABASE_DB_PASSWORD environment variable"
    exit 1
fi

# 1. Create backup
echo "📦 Creating backup..."
npx supabase db dump -f backup-$(date +%Y%m%d-%H%M%S).sql

# 2. Reset database (with confirmation)
echo "⚠️  About to reset production database. This will DELETE ALL DATA!"
read -p "Are you sure? (yes/no): " confirm
if [ "$confirm" = "yes" ]; then
    echo "🔄 Resetting database..."
    npx supabase db reset --linked
else
    echo "❌ Deployment cancelled"
    exit 1
fi

# 3. Deploy secrets
echo "🔐 Setting production secrets..."
npx supabase secrets set --env-file .env.production

# 4. Deploy functions
echo "⚡ Deploying edge functions..."
npx supabase functions deploy --no-verify-jwt

# 5. Verify deployment
echo "✅ Verifying deployment..."
npx supabase migration list --remote
curl https://your-project.supabase.co/functions/v1/akademy-app/health

echo "🎉 Deployment complete!"
echo "⚠️  Don't forget to create your superadmin user!"
```

Make it executable:
```bash
chmod +x deploy-to-production.sh
```

## Important Notes

1. **Database Reset**: The `npx supabase db reset --linked` command will:
   - Drop all existing tables and data
   - Run all migrations in order
   - Apply seed data (including test data)

2. **Environment Variables**: Supabase automatically provides:
   - SUPABASE_URL
   - SUPABASE_ANON_KEY
   - SUPABASE_SERVICE_ROLE_KEY
   
   You only need to set:
   - STRAPI_API_URL
   - STRAPI_API_TOKEN

3. **Superadmin Creation**: Choose the method that works best for you:
   - Script method is most automated
   - SQL method gives you more control
   - API method uses your existing functions

4. **Security**: After deployment:
   - Remove any test users from seed data
   - Change default passwords
   - Enable RLS policies
   - Review function permissions

## Troubleshooting

If deployment fails:
```bash
# Check logs
npx supabase functions logs akademy-app --tail

# Verify project connection
npx supabase status

# Check for migration conflicts
npx supabase db diff --linked

# Re-link if needed
npx supabase unlink
npx supabase link --project-ref your_project_ref
```