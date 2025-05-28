# 🚀 Deployment Quick Reference

## Prerequisites Setup (One-time)

```bash
# 1. Install tools
npm install -g supabase
# Ensure Docker Desktop is installed and running

# 2. Set environment variables
export SUPABASE_ACCESS_TOKEN="sbp_your_access_token"
export SUPABASE_DB_PASSWORD="your_db_password"
export SUPABASE_PROJECT_ID="your_project_ref"

# 3. Login and link project
supabase login
supabase link --project-ref $SUPABASE_PROJECT_ID
```

## Deployment Commands

```bash
# 🎯 Full Production Deployment
deno task deploy:production --project-ref $SUPABASE_PROJECT_ID

# 👀 Preview (Dry Run)
deno task deploy:dry-run --project-ref $SUPABASE_PROJECT_ID

# ⚡ Functions Only
deno task deploy:functions --project-ref $SUPABASE_PROJECT_ID

# 💾 Database Only  
deno task deploy:database --project-ref $SUPABASE_PROJECT_ID

# 🤖 CI/CD (No prompts)
deno task deploy:production --force --project-ref $SUPABASE_PROJECT_ID
```

## Manual Commands

```bash
# Database
supabase db push --include-seed
supabase migration list --remote

# Functions
supabase functions deploy --no-verify-jwt
supabase functions logs akademy

# Secrets
supabase secrets set --env-file .env
supabase secrets list
```

## Emergency Procedures

```bash
# 🔄 Rollback Functions
git checkout previous_commit
supabase functions deploy akademy
git checkout main

# 🔄 Rollback Database
supabase migration new rollback_changes
# Edit migration file to reverse changes
supabase db push
```

## Validation

```bash
# ✅ Health Check
curl https://your-project.supabase.co/functions/v1/akademy/health

# ✅ Status Check
supabase status
supabase migration list --remote
```

## Environment Variables Locations

- **Access Token**: Supabase Dashboard → Account Settings → Access Tokens
- **DB Password**: Dashboard → Project Settings → Database → Connection string  
- **Project ID**: Dashboard → Project Settings → General → Reference ID