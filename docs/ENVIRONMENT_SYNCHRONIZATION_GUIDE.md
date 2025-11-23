# Environment Synchronization Guide

Complete guide for synchronizing database migrations and schemas between production and local environments in the Akademia Supabase project.

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Production to Local: Replicating Production Locally](#production-to-local-replicating-production-locally)
4. [Local to Production: Deploying Changes](#local-to-production-deploying-changes)
5. [Common Workflows](#common-workflows)
6. [Testing Strategy](#testing-strategy)
7. [Troubleshooting](#troubleshooting)
8. [Best Practices](#best-practices)

---

## Overview

This guide covers two critical workflows:

- **Production → Local**: Pull production schema/data to replicate the production environment locally for testing
- **Local → Production**: Deploy tested changes from local development to production

### When to Use Each Workflow

**Pull from Production (Production → Local)** when:
- Setting up a new development environment
- Production has manual changes made through the Dashboard
- Need to test against production data/schema
- Debugging production-specific issues
- Other developers deployed changes you don't have locally

**Push to Production (Local → Production)** when:
- Deploying new features or schema changes
- Applying tested migrations
- Updating Edge Functions
- Rolling out configuration changes

---

## Prerequisites

### Required Information

1. **Supabase Project Reference ID**
   - Find in: Supabase Dashboard → Project Settings → General
   - Format: `abcdefghijklmnop` (16 characters)

2. **Database Password**
   - Find in: Supabase Dashboard → Project Settings → Database
   - Set as environment variable for convenience

3. **Project Linked Status**
   - Run `supabase status` to verify
   - If not linked, follow linking steps below

### Initial Setup

```bash
# Set your database password (add to ~/.bashrc or ~/.zshrc for persistence)
export SUPABASE_DB_PASSWORD="your_database_password"

# Optional: Set project ID
export SUPABASE_PROJECT_ID="your_project_ref"

# Verify Supabase CLI is installed
npx supabase --version
# or
supabase --version
```

### Link Your Local Project to Production

```bash
# Navigate to project root
cd /path/to/zambia-supabase

# Link to production project
npx supabase link --project-ref your_project_ref
# You'll be prompted for the database password if not set in env

# Verify the link
npx supabase status

# Expected output includes:
# - Project ref: your_project_ref
# - API URL: https://your_project_ref.supabase.co
# - DB URL: postgresql://postgres:[PASSWORD]@...
```

---

## Production to Local: Replicating Production Locally

### Scenario 1: Fresh Development Setup

Starting from scratch and need to replicate production locally.

```bash
# 1. Link to production (if not already done)
npx supabase link --project-ref your_project_ref

# 2. Pull the production schema as a migration
npx supabase db pull

# This creates: migrations/<timestamp>_remote_schema.sql
# Contains the complete production schema

# 3. Start local Supabase
supabase start

# 4. Apply the pulled migration to local database
npx supabase db reset

# 5. Verify migration was applied
npx supabase migration list
# Shows all migrations including the pulled one
```

**What `db pull` does:**
- Connects to production database
- Runs `pg_dump` to extract schema
- Excludes Supabase-managed schemas (auth, storage, extensions)
- Creates a new migration file with timestamp
- Does NOT include data (schema only)

### Scenario 2: Production Has Manual Changes

Someone made changes through the Dashboard that aren't in version control.

```bash
# 1. Pull changes from production
npx supabase db pull

# This creates a new migration with production changes

# 2. Review the generated migration
cat migrations/<timestamp>_remote_schema.sql

# 3. If changes look good, apply to local database
npx supabase db reset

# 4. Commit the migration to version control
git add migrations/<timestamp>_remote_schema.sql
git commit -m "Pull production schema changes"
git push
```

### Scenario 3: Compare Local vs Production Schemas

Check what differences exist before pulling.

```bash
# Compare schemas without pulling
npx supabase db diff --linked --use-migra

# This shows SQL differences between local and remote
# Useful for:
# - Understanding what changed in production
# - Verifying your local changes before pushing
# - Identifying schema drift

# Save comparison as a migration (optional)
npx supabase db diff -f schema_sync_check --linked --use-migra

# Review the generated file
cat migrations/<timestamp>_schema_sync_check.sql
```

### Scenario 4: Pull Production Data (Full Backup)

Replicate production data locally for testing with real data.

```bash
# 1. Dump production database (schema + data)
npx supabase db dump -f production-backup-$(date +%Y%m%d-%H%M%S).sql

# 2. Stop local Supabase
supabase stop

# 3. Start fresh local instance
supabase start

# 4. Restore production data to local
# IMPORTANT: This uses psql to restore to local database
psql -h localhost -p 54322 -U postgres -d postgres -f production-backup-YYYYMMDD-HHMMSS.sql

# Password for local postgres is: postgres

# 5. Verify data was restored
npx supabase db reset  # Apply any pending migrations
```

**Data dump options:**

```bash
# Full backup (schema + data)
npx supabase db dump -f backup-full.sql

# Data only (no schema)
npx supabase db dump -f backup-data.sql --data-only

# Schema only (no data)
npx supabase db dump -f backup-schema.sql --schema-only

# Specific tables
npx supabase db dump -f backup-agreements.sql --table agreements --table users

# Exclude specific schemas
npx supabase db dump -f backup-custom.sql --exclude-schema auth --exclude-schema storage
```

### Scenario 5: Replicate Production for Testing

Create a local test environment identical to production.

```bash
# Complete workflow for production replication:

# Step 1: Pull latest schema
npx supabase db pull

# Step 2: Create production data backup
npx supabase db dump -f prod-data-$(date +%Y%m%d).sql

# Step 3: Reset local environment
supabase db reset

# Step 4: Restore production data
psql -h localhost -p 54322 -U postgres -d postgres -f prod-data-YYYYMMDD.sql

# Step 5: Verify local matches production
npx supabase migration list --remote
npx supabase migration list

# Both should show same migrations

# Step 6: Run tests against production-like data
deno task test
```

---

## Local to Production: Deploying Changes

### Scenario 1: Deploy Schema Changes

You've created new migrations locally and want to deploy to production.

```bash
# Pre-deployment checklist:

# 1. Verify all migrations work locally
npx supabase db reset
deno task test

# 2. Check migration status
npx supabase migration list          # Local migrations
npx supabase migration list --remote # Production migrations

# 3. See what will be deployed
npx supabase db diff --linked --use-migra

# 4. Create backup of production (CRITICAL!)
npx supabase db dump -f pre-deploy-backup-$(date +%Y%m%d-%H%M%S).sql

# 5. Deploy migrations to production
npx supabase db push

# Or include seed data (use cautiously in production!)
npx supabase db push --include-seed

# 6. Verify deployment
npx supabase migration list --remote

# 7. Test production endpoints
curl https://your-project.supabase.co/functions/v1/akademy/health
```

**Dry run option** (see what would be deployed without applying):

```bash
npx supabase db push --dry-run
```

### Scenario 2: Deploy Edge Functions

Deploy function changes without touching the database.

```bash
# 1. Test functions locally first
npx supabase functions serve --env-file ./functions/.env
# Test endpoints at http://localhost:54321/functions/v1/...

# 2. Deploy all functions
npx supabase functions deploy --no-verify-jwt

# 3. Deploy specific function
npx supabase functions deploy akademy --no-verify-jwt

# 4. Set production secrets (if changed)
npx supabase secrets set --env-file .env.production

# Or set individual secrets
npx supabase secrets set STRAPI_API_URL="https://api.example.com"
npx supabase secrets set STRAPI_API_TOKEN="your_token"

# 5. Verify secrets are set
npx supabase secrets list

# 6. View function logs
npx supabase functions logs akademy --tail
```

### Scenario 3: Complete Deployment (Database + Functions)

Full deployment workflow for a new feature.

```bash
# Complete deployment script:

echo "🚀 Starting deployment to production..."

# 1. Pre-deployment checks
echo "✅ Running pre-deployment checks..."
git status  # Ensure clean working directory
npx supabase status  # Verify linked

# 2. Test everything locally
echo "🧪 Running local tests..."
npx supabase db reset
deno task test
deno task test:akademy

# 3. Backup production
echo "💾 Creating production backup..."
npx supabase db dump -f backup-$(date +%Y%m%d-%H%M%S).sql

# 4. Deploy database changes
echo "📊 Deploying database migrations..."
npx supabase db push

# 5. Deploy Edge Functions
echo "⚡ Deploying Edge Functions..."
npx supabase secrets set --env-file .env.production
npx supabase functions deploy --no-verify-jwt

# 6. Verify deployment
echo "🔍 Verifying deployment..."
npx supabase migration list --remote
curl https://your-project.supabase.co/functions/v1/akademy/health

# 7. Monitor logs
echo "📋 Monitoring function logs..."
npx supabase functions logs akademy --tail

echo "✅ Deployment complete!"
```

### Scenario 4: Hotfix Deployment

Emergency fix that needs to go to production quickly.

```bash
# Hotfix workflow:

# 1. Create hotfix branch
deno task branch:hotfix "critical-auth-bug"

# 2. Make the fix and test
# ... edit code ...
npx supabase db reset
deno task test

# 3. Create migration if needed
npx supabase db diff -f hotfix_auth_bug

# 4. Backup production
npx supabase db dump -f pre-hotfix-backup-$(date +%Y%m%d-%H%M%S).sql

# 5. Deploy immediately
npx supabase db push
npx supabase functions deploy --no-verify-jwt

# 6. Verify fix
curl https://your-project.supabase.co/functions/v1/akademy/health

# 7. Merge to main
git checkout main
git merge hotfix/critical-auth-bug
git push origin main
```

---

## Common Workflows

### Workflow 1: Daily Development Sync

Keep local environment synchronized with production changes from other developers.

```bash
# Morning sync routine:

# 1. Pull latest code
git pull origin main

# 2. Check for production schema changes
npx supabase db diff --linked --use-migra

# 3. If differences exist, pull them
npx supabase db pull

# 4. Reset local database with new migrations
npx supabase db reset

# 5. Generate fresh TypeScript types
deno task generate:supabase:types

# 6. Run tests to ensure everything works
deno task test
```

### Workflow 2: Feature Development

Develop a new feature with database changes.

```bash
# 1. Create feature branch
deno task branch:feature "user-notifications"

# 2. Edit schema files
vim schemas/notifications.sql

# 3. Generate migration
npx supabase db diff -f add_notifications_system

# 4. Add to config.toml schema_paths
vim config.toml
# Add: "./schemas/notifications.sql"

# 5. Test locally
npx supabase db reset
deno task test

# 6. Commit changes
git add migrations/ schemas/ config.toml
git commit -m "feat: add notifications system"
git push origin feat/user-notifications

# 7. After review, deploy to production
git checkout main
git merge feat/user-notifications
npx supabase db push
npx supabase functions deploy --no-verify-jwt
```

### Workflow 3: Production Issue Investigation

Reproduce a production issue locally.

```bash
# Investigation workflow:

# 1. Pull production schema
npx supabase db pull

# 2. Dump production data
npx supabase db dump -f prod-issue-data-$(date +%Y%m%d).sql

# 3. Reset local to match production
supabase db reset
psql -h localhost -p 54322 -U postgres -d postgres -f prod-issue-data-*.sql

# 4. Check migration status matches
npx supabase migration list --remote
npx supabase migration list
# Should be identical

# 5. Reproduce issue locally
# ... test the problematic scenario ...

# 6. Create fix and test
# ... edit code ...
deno task test

# 7. Deploy fix
npx supabase db push
npx supabase functions deploy --no-verify-jwt
```

### Workflow 4: Rollback After Failed Deployment

Rollback production to previous state if deployment causes issues.

```bash
# Rollback workflow:

# 1. Identify the problematic migration
npx supabase migration list --remote

# 2. Restore from pre-deployment backup
# IMPORTANT: This requires direct database access
# Contact Supabase support or use database restore tools

# Alternative: Deploy a reverse migration
# 3. Create reverse migration
npx supabase db diff -f rollback_feature_x --linked

# 4. Review and edit the reverse migration
vim migrations/<timestamp>_rollback_feature_x.sql
# Manually write SQL to undo changes

# 5. Apply rollback
npx supabase db push

# 6. Verify rollback
npx supabase migration list --remote
curl https://your-project.supabase.co/functions/v1/akademy/health
```

**Prevention: Better than rollback**

```bash
# Always test before production deployment:

# 1. Use dry-run
npx supabase db push --dry-run

# 2. Compare schemas first
npx supabase db diff --linked --use-migra

# 3. Maintain backups
npx supabase db dump -f backup-$(date +%Y%m%d-%H%M%S).sql

# 4. Use staging environment (if available)
# Deploy to staging first, test, then deploy to production
```

---

## Testing Strategy

### Testing Local Changes Before Production

```bash
# Complete test workflow:

# 1. Reset local database
npx supabase db reset

# 2. Run all tests
deno task test

# 3. Run function-specific tests
deno task test:akademy
deno task test:user-management

# 4. Test Edge Functions locally
npx supabase functions serve --env-file ./functions/.env

# In another terminal:
# Test health endpoint
curl http://localhost:54321/functions/v1/akademy/health

# Test with authentication
curl -X POST http://localhost:54321/functions/v1/akademy/create-user \
  -H "Authorization: Bearer your_test_jwt" \
  -H "Content-Type: application/json" \
  -d '{"agreement_id": "test-uuid"}'

# 5. Generate test users
deno task generate:test:users

# 6. Test with different roles
# Use generated credentials.json to test role-based access

# 7. Check for schema issues
npx supabase db diff --linked --use-migra
```

### Testing Production After Deployment

```bash
# Post-deployment validation:

# 1. Verify migrations applied
npx supabase migration list --remote

# 2. Test function health
curl https://your-project.supabase.co/functions/v1/akademy/health

# 3. Monitor function logs
npx supabase functions logs akademy --tail

# 4. Test critical endpoints
# Use production credentials (carefully!)
curl -X POST https://your-project.supabase.co/functions/v1/akademy/create-user \
  -H "Authorization: Bearer production_jwt" \
  -H "Content-Type: application/json" \
  -d '{"agreement_id": "real-uuid"}'

# 5. Check database connectivity
psql "postgresql://postgres.[project-ref]:[password]@[host]/postgres" -c "\dt"

# 6. Verify RLS policies working
# Test with different user roles to ensure security
```

---

## Troubleshooting

### Issue: "Project not linked"

```bash
# Error: Project ref is not specified
# Solution:
npx supabase link --project-ref your_project_ref

# Verify link
npx supabase status
```

### Issue: "Permission denied" during db pull

```bash
# Error: permission denied for schema graphql
# Solution: Grant permissions (run in Supabase SQL Editor)
GRANT ALL ON SCHEMA graphql TO postgres;

# Then retry
npx supabase db pull
```

### Issue: "Migration already exists"

```bash
# Error: migration <timestamp> already exists
# Cause: Pulled migration has same timestamp as local

# Solution 1: Delete duplicate local migration
rm migrations/<timestamp>_remote_schema.sql

# Solution 2: Rename the pulled migration
mv migrations/<old_timestamp>_remote_schema.sql \
   migrations/<new_timestamp>_remote_schema.sql

# Update migration history if needed
npx supabase migration list
```

### Issue: "Schema differs after db reset"

```bash
# Error: Local schema doesn't match expected state

# Solution 1: Clean slate
supabase stop
rm -rf supabase/.branches
supabase start
npx supabase db reset

# Solution 2: Pull fresh from production
npx supabase db pull
npx supabase db reset
```

### Issue: "Function deployment fails"

```bash
# Error: Failed to deploy function

# Solution 1: Check function configuration
cat config.toml
# Verify entrypoint and import_map

# Solution 2: Test locally first
npx supabase functions serve --debug

# Solution 3: Check for lockfile issues
rm functions/*/deno.lock
npx supabase functions deploy --no-verify-jwt

# Solution 4: Verify secrets are set
npx supabase secrets list
```

### Issue: "Database connection timeout"

```bash
# Error: Connection timeout

# Solution 1: Check database password
export SUPABASE_DB_PASSWORD="correct_password"

# Solution 2: Verify project is online
# Check Supabase Dashboard → Project Settings

# Solution 3: Check network connectivity
ping your-project.supabase.co

# Solution 4: Re-link project
npx supabase unlink
npx supabase link --project-ref your_project_ref
```

### Issue: "Migration conflicts"

```bash
# Error: Migration order conflicts

# Solution: Use db diff to identify differences
npx supabase db diff --linked --use-migra > conflicts.sql

# Review conflicts
cat conflicts.sql

# Fix manually:
# 1. Edit migration files to resolve conflicts
# 2. Test locally
npx supabase db reset

# 3. If successful, deploy
npx supabase db push
```

---

## Best Practices

### 1. Always Backup Before Changes

```bash
# Before ANY production operation:
npx supabase db dump -f backup-$(date +%Y%m%d-%H%M%S).sql

# Store backups safely
mkdir -p backups
mv backup-*.sql backups/

# Keep backups for 30+ days
```

### 2. Use Dry Runs

```bash
# Preview changes before applying
npx supabase db push --dry-run

# Compare schemas
npx supabase db diff --linked --use-migra
```

### 3. Version Control Everything

```bash
# Commit migrations
git add migrations/
git commit -m "Add migration for feature X"

# Commit schema files
git add schemas/
git add config.toml
git commit -m "Update schema for feature X"

# Never commit secrets
echo ".env*" >> .gitignore
echo "credentials.json" >> .gitignore
```

### 4. Test Locally First

```bash
# Standard test workflow before production:
npx supabase db reset
deno task test
npx supabase functions serve --env-file ./functions/.env
# Manual testing...
```

### 5. Monitor After Deployment

```bash
# Watch logs for 10 minutes after deployment
npx supabase functions logs akademy --tail

# Check error rates in Supabase Dashboard
# Monitor → Logs & Functions
```

### 6. Document Schema Changes

```bash
# Add comments to migrations
-- Migration: Add notifications system
-- Author: Your Name
-- Date: 2025-01-18
-- Ticket: PROJ-123

CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  -- ... rest of schema
);
```

### 7. Use Migration Naming Conventions

```bash
# Good migration names:
npx supabase db diff -f add_notifications_table
npx supabase db diff -f fix_agreements_foreign_key
npx supabase db diff -f update_rbac_policies

# Bad migration names:
npx supabase db diff -f update  # Too vague
npx supabase db diff -f new     # Not descriptive
```

### 8. Maintain Schema Order in config.toml

```toml
# Always maintain proper order:
schema_paths = [
  "./schemas/extensions.sql",      # 1. Extensions first
  "./schemas/rbac_helpers.sql",    # 2. Helpers
  "./schemas/tables.sql",          # 3. Tables
  "./schemas/functions.sql",       # 4. Functions
  "./schemas/policies.sql",        # 5. Policies last
]
```

### 9. Regular Synchronization

```bash
# Weekly sync (minimum):
npx supabase db pull
npx supabase db reset
deno task generate:supabase:types
git add types/ migrations/
git commit -m "Sync with production schema"
```

### 10. Security Checklist

```bash
# Before deploying:
# ✅ No hardcoded secrets in code
grep -r "password" functions/
grep -r "api.key" functions/

# ✅ Secrets in environment variables
npx supabase secrets list

# ✅ RLS policies enabled
# Check in migrations/*.sql

# ✅ Test with different user roles
deno task generate:test:users
# Test with credentials.json

# ✅ Backup exists
ls -lh backups/backup-$(date +%Y%m%d)*.sql
```

---

## Quick Reference

### Production → Local Commands

| Task | Command |
|------|---------|
| Link project | `npx supabase link --project-ref <ref>` |
| Pull schema | `npx supabase db pull` |
| Compare schemas | `npx supabase db diff --linked --use-migra` |
| Full backup | `npx supabase db dump -f backup.sql` |
| Data only | `npx supabase db dump -f backup.sql --data-only` |
| Apply locally | `npx supabase db reset` |
| Check migrations | `npx supabase migration list --remote` |

### Local → Production Commands

| Task | Command |
|------|---------|
| Deploy migrations | `npx supabase db push` |
| Dry run | `npx supabase db push --dry-run` |
| Deploy functions | `npx supabase functions deploy --no-verify-jwt` |
| Set secrets | `npx supabase secrets set --env-file .env` |
| View logs | `npx supabase functions logs <name> --tail` |
| List secrets | `npx supabase secrets list` |

### Common Tasks

| Task | Command |
|------|---------|
| Check status | `npx supabase status` |
| Local migrations | `npx supabase migration list` |
| Remote migrations | `npx supabase migration list --remote` |
| Create migration | `npx supabase db diff -f <name>` |
| Reset local DB | `npx supabase db reset` |
| Start local | `supabase start` |
| Stop local | `supabase stop` |

---

## Additional Resources

- [Supabase CLI Documentation](https://supabase.com/docs/reference/cli/introduction)
- [Database Migrations Guide](https://supabase.com/docs/guides/deployment/database-migrations)
- [Managing Environments](https://supabase.com/docs/guides/deployment/managing-environments)
- [Production Deployment Guide](./PRODUCTION_DEPLOYMENT_GUIDE.md)
- [Production CLI Commands](./production-cli-commands.md)
- [Project README](../README.md)
- [CLAUDE.md](../CLAUDE.md)

---

**Last Updated:** November 18, 2025
**Project:** Akademia Supabase
**Maintainer:** Development Team
