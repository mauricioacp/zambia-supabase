# 🚀 Production Deployment Guide for Akademia Supabase

This guide covers the complete deployment process for the Akademia Supabase project, including database migrations and Edge Functions.

## 📋 Prerequisites

### Required Software
- **Supabase CLI**: Latest version
- **Docker Desktop**: Required for Edge Functions deployment
- **Git**: For version control verification
- **Deno**: For running deployment scripts

### Installation Commands
```bash
# Install Supabase CLI
npm install -g supabase

# Verify installations
supabase --version
docker --version
deno --version
```

### Required Environment Variables

Set these environment variables for production deployment:

```bash
# Your personal access token from Supabase Dashboard
export SUPABASE_ACCESS_TOKEN="your_access_token_here"

# Your project-specific database password
export SUPABASE_DB_PASSWORD="your_db_password_here"

# Optional: Your project reference ID
export SUPABASE_PROJECT_ID="your_project_ref_here"
```

**How to get these values:**
1. **Access Token**: Supabase Dashboard → Account Settings → Access Tokens
2. **Database Password**: Supabase Dashboard → Project Settings → Database → Connection string
3. **Project ID**: Supabase Dashboard → Project Settings → General → Reference ID

## 🎯 Deployment Options

### 1. Full Deployment (Recommended)
```bash
# Deploy everything with confirmation
deno run --allow-all scripts/deploy-production.ts --project-ref your_project_id

# Force deployment without prompts (CI/CD)
deno run --allow-all scripts/deploy-production.ts --force --project-ref your_project_id
```

### 2. Database Only
```bash
# Deploy only database migrations
deno run --allow-all scripts/deploy-production.ts --db-only --project-ref your_project_id
```

### 3. Functions Only
```bash
# Deploy only Edge Functions
deno run --allow-all scripts/deploy-production.ts --functions-only --project-ref your_project_id
```

### 4. Dry Run (Preview)
```bash
# See what would be deployed without executing
deno run --allow-all scripts/deploy-production.ts --dry-run --project-ref your_project_id
```

## 🔍 Pre-Deployment Checklist

The deployment script automatically checks:

- ✅ **Supabase CLI** installed and accessible
- ✅ **Docker Desktop** running (for Edge Functions)
- ✅ **Project linked** to Supabase
- ✅ **Environment variables** configured
- ✅ **Git status** clean (warns about uncommitted changes)
- ✅ **Configuration files** valid
- ✅ **Pre-deployment tests** pass

### Manual Pre-Deployment Steps

1. **Commit all changes**:
   ```bash
   git add .
   git commit -m "feat: ready for production deployment"
   git push
   ```

2. **Link your project** (first time only):
   ```bash
   supabase login
   supabase projects list
   supabase link --project-ref your_project_id
   ```

3. **Test locally**:
   ```bash
   supabase start
   supabase functions serve
   
   # Run tests
   cd functions/akademy
   deno task test:all
   ```

## 📊 Deployment Process Flow

### Phase 1: Preflight Checks
1. Verify CLI tools and Docker
2. Check project linking
3. Validate environment variables
4. Inspect git status
5. Validate configuration files

### Phase 2: Pre-Deployment Testing
1. Run unit tests
2. Validate function syntax
3. Check migration files

### Phase 3: Database Deployment
1. Display current migration status
2. Deploy pending migrations
3. Apply seed data (if specified)
4. Verify migration completion

### Phase 4: Functions Deployment  
1. Deploy secrets/environment variables
2. Deploy Edge Functions
3. Configure function settings
4. Verify function deployment

### Phase 5: Post-Deployment Validation
1. Test function health endpoints
2. Verify database migration status
3. Run smoke tests
4. Generate deployment report

## 🛡️ Security Considerations

### Environment Variables and Secrets

**In your local `.env` file** (never commit this):
```bash
# External API keys
STRAPI_API_URL=https://your-strapi-instance.com
STRAPI_TOKEN=your_strapi_token

# Super password for migration endpoint
SUPER_PASSWORD=your_super_secure_password

# Other secrets as needed
OPENAI_API_KEY=your_openai_key
```

**Deploy secrets to Supabase**:
```bash
# Manual deployment
supabase secrets set --env-file .env

# Automatic (handled by deployment script)
deno run --allow-all scripts/deploy-production.ts
```

### Function Security Settings

The akademy function is configured with:
- `verify_jwt = false` (handles its own authentication)
- Custom CORS configuration
- Role-based access control
- Dual authentication for migration endpoints

## 🏗️ Manual Deployment Commands

If you prefer manual deployment or need to troubleshoot:

### Database Migrations
```bash
# Check current status
supabase migration list

# Deploy migrations
supabase db push

# Include seed data
supabase db push --include-seed

# Check deployment status
supabase migration list --remote
```

### Edge Functions
```bash
# Deploy all functions
supabase functions deploy

# Deploy specific function
supabase functions deploy akademy

# Deploy without JWT verification
supabase functions deploy --no-verify-jwt

# Check function logs
supabase functions logs akademy
```

### Secrets Management
```bash
# Set individual secret
supabase secrets set API_KEY=your_value

# Set from .env file
supabase secrets set --env-file .env

# List current secrets
supabase secrets list

# Remove secret
supabase secrets unset API_KEY
```

## 🔧 CI/CD Integration

### GitHub Actions Example

Create `.github/workflows/deploy.yml`:

```yaml
name: Deploy to Production
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Deno
        uses: denoland/setup-deno@v1
        with:
          deno-version: v1.x
          
      - name: Setup Supabase CLI
        uses: supabase/setup-cli@v1
        with:
          version: latest
          
      - name: Deploy to Production
        env:
          SUPABASE_ACCESS_TOKEN: ${{ secrets.SUPABASE_ACCESS_TOKEN }}
          SUPABASE_DB_PASSWORD: ${{ secrets.SUPABASE_DB_PASSWORD }}
          SUPABASE_PROJECT_ID: ${{ secrets.SUPABASE_PROJECT_ID }}
        run: |
          deno run --allow-all scripts/deploy-production.ts \
            --force \
            --project-ref $SUPABASE_PROJECT_ID
```

### Required GitHub Secrets
- `SUPABASE_ACCESS_TOKEN`
- `SUPABASE_DB_PASSWORD`  
- `SUPABASE_PROJECT_ID`

## 🚨 Troubleshooting

### Common Issues

**"Docker not running"**:
```bash
# Start Docker Desktop
# On macOS: open Docker Desktop app
# On Linux: sudo systemctl start docker
```

**"Project not linked"**:
```bash
supabase login
supabase link --project-ref your_project_id
```

**"Migration failed"**:
```bash
# Check migration status
supabase migration list

# View detailed error
supabase db push --debug

# Reset if needed (DANGER: data loss)
supabase db reset --linked
```

**"Function deployment failed"**:
```bash
# Check function logs
supabase functions logs akademy

# Deploy with debug info
supabase functions deploy akademy --debug

# Verify Docker is running
docker ps
```

**"Secrets not found"**:
```bash
# Verify secrets are set
supabase secrets list

# Re-deploy secrets
supabase secrets set --env-file .env
```

### Rollback Procedures

**Database Rollback**:
```bash
# Create rollback migration
supabase migration new rollback_changes

# Edit migration file to reverse changes
# Then deploy
supabase db push
```

**Function Rollback**:
```bash
# Deploy previous version from git
git checkout previous_commit_hash
supabase functions deploy akademy
git checkout main
```

## 📊 Monitoring and Validation

### Post-Deployment Checks

1. **Function Health**:
   ```bash
   curl https://your-project.supabase.co/functions/v1/akademy/health
   ```

2. **Database Status**:
   ```bash
   supabase migration list --remote
   ```

3. **Function Logs**:
   ```bash
   supabase functions logs akademy
   ```

### Performance Monitoring

Monitor these metrics after deployment:
- Function response times
- Error rates  
- Database connection usage
- Memory consumption
- Request throughput

### Health Check Endpoints

The akademy function provides these endpoints for monitoring:
- `GET /akademy/health` - Basic health check
- `GET /akademy/` - API information and available endpoints

## 📚 Best Practices

### Development Workflow
1. **Feature Development**: Work in feature branches
2. **Local Testing**: Always test locally first  
3. **Staging Deployment**: Deploy to staging environment
4. **Production Deployment**: Use deployment script with proper validation
5. **Monitoring**: Watch logs and metrics after deployment

### Security Practices
1. **Never commit secrets** to version control
2. **Use environment variables** for all configuration
3. **Regular secret rotation** 
4. **Monitor access logs**
5. **Test authorization boundaries**

### Deployment Practices
1. **Always run dry-run first** on critical deployments
2. **Deploy during low-traffic periods**
3. **Have rollback plan ready**
4. **Monitor immediately after deployment**
5. **Document all changes**

## 🎯 Quick Reference

### Essential Commands
```bash
# Full deployment
deno run --allow-all scripts/deploy-production.ts --project-ref PROJECT_ID

# Dry run
deno run --allow-all scripts/deploy-production.ts --dry-run --project-ref PROJECT_ID

# Check status
supabase status
supabase migration list
supabase functions logs akademy

# Emergency rollback
git checkout previous_version
supabase functions deploy akademy
```

### Environment Setup
```bash
export SUPABASE_ACCESS_TOKEN="your_token"
export SUPABASE_DB_PASSWORD="your_password"  
export SUPABASE_PROJECT_ID="your_project_id"
```

This deployment guide ensures safe, reliable, and repeatable deployments to production! 🚀