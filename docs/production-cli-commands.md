# Supabase CLI Commands for Production

This guide provides the essential Supabase CLI commands for production operations. Use these commands directly instead of complex wrapper scripts.

## Prerequisites

### Required Environment Variables
```bash
export SUPABASE_DB_PASSWORD="your_database_password"
export SUPABASE_PROJECT_ID="your_project_ref"  # Optional, can use --project-ref flag
```

### Project Setup
```bash
# Link your local project to production
npx supabase link --project-ref your_project_id

# Verify connection
npx supabase status
```

## Core Production Operations

### 1. Deploy Database Migrations
Deploy your local migrations to production:

```bash
# Deploy migrations with seed data
npx supabase db push --include-seed

# Deploy migrations only (no seed)
npx supabase db push

# Dry run - see what would be deployed
npx supabase db push --dry-run
```

### 2. Deploy Edge Functions
Deploy your Edge Functions to production:

```bash
# Deploy all functions
npx supabase functions deploy --no-verify-jwt

# Deploy specific function
npx supabase functions deploy akademy --no-verify-jwt

# Deploy with secrets from .env file
npx supabase secrets set --env-file .env
npx supabase functions deploy --no-verify-jwt
```

### 3. Database Backup
Create backups of your production database:

```bash
# Create full backup (schema + data)
npx supabase db dump -f backup-$(date +%Y%m%d-%H%M%S).sql

# Create data-only backup
npx supabase db dump -f backup-data-$(date +%Y%m%d-%H%M%S).sql --data-only

# Create schema-only backup
npx supabase db dump -f backup-schema-$(date +%Y%m%d-%H%M%S).sql --schema-only
```

### 4. Production Database Reset
⚠️ **DANGER**: This will DELETE ALL DATA in production!

```bash
# Reset production database (includes backup creation and seed application)
npx supabase db reset --linked

# Reset with confirmation prompt
npx supabase db reset --linked
# When prompted, type 'y' to confirm
```

**Safety procedure:**
1. Always create a backup first: `npx supabase db dump -f pre-reset-backup.sql`
2. Run the reset: `npx supabase db reset --linked`
3. Verify the reset worked: `npx supabase migration list`

### 5. Schema Comparison
Compare your local schema with production:

```bash
# Show differences between local and remote
npx supabase db diff --linked --use-migra

# Save differences as a new migration
npx supabase db diff -f fix_schema_differences --linked --use-migra

# Check migration status
npx supabase migration list
npx supabase migration list --remote
```

## Useful Monitoring Commands

### Check Project Status
```bash
# View project information and endpoints
npx supabase status

# Check if project is properly linked
npx supabase projects list
```

### Migration Management
```bash
# List local migrations
npx supabase migration list

# List remote (production) migrations
npx supabase migration list --remote

# Create new migration from schema changes
npx supabase db diff -f descriptive_migration_name
```

## Common Workflows

### Complete Production Deployment
```bash
# 1. Verify everything is ready
npx supabase status
git status  # Ensure changes are committed

# 2. Deploy database changes
npx supabase db push --include-seed

# 3. Deploy function changes
npx supabase secrets set --env-file .env  # If you have secrets
npx supabase functions deploy --no-verify-jwt

# 4. Verify deployment
npx supabase migration list --remote
curl https://your-project.supabase.co/functions/v1/akademy/health
```

### Safe Production Reset (for testing)
```bash
# 1. Create backup first
npx supabase db dump -f backup-$(date +%Y%m%d-%H%M%S).sql

# 2. Reset database
npx supabase db reset --linked

# 3. Verify reset
npx supabase migration list --remote
```

### Schema Development Workflow
```bash
# 1. Make changes to schemas/ files
# 2. Generate migration
npx supabase db diff -f add_new_feature

# 3. Test locally
npx supabase db reset

# 4. Deploy to production
npx supabase db push
```

## Troubleshooting

### Project Not Linked
```bash
npx supabase link --project-ref your_project_id
# Enter your database password when prompted
```

### Permission Errors
Ensure you have the correct database password:
```bash
export SUPABASE_DB_PASSWORD="your_correct_password"
```

### Function Deployment Issues
```bash
# Check if functions are properly configured
npx supabase functions serve --debug

# Verify function exists
ls -la functions/
```

### Migration Issues
```bash
# Check for conflicts
npx supabase db diff --linked

# Reset local database if needed
npx supabase db reset
```

## Security Best Practices

1. **Never commit passwords or secrets**
2. **Always backup before destructive operations**
3. **Use environment variables for sensitive data**
4. **Test deployments in staging first**
5. **Monitor function logs after deployment**

## Quick Reference

| Operation | Command |
|-----------|---------|
| Deploy DB | `npx supabase db push --include-seed` |
| Deploy Functions | `npx supabase functions deploy --no-verify-jwt` |
| Create Backup | `npx supabase db dump -f backup.sql` |
| Reset Production | `npx supabase db reset --linked` |
| Compare Schemas | `npx supabase db diff --linked --use-migra` |
| Check Status | `npx supabase status` |
| View Logs | `npx supabase functions logs function-name` |

This direct approach is simpler, more reliable, and eliminates the complexity of wrapper scripts.
