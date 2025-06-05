# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Akademia Supabase backend - Educational platform with PostgreSQL database, Deno Edge Functions, and automated data migration from Strapi CMS. Uses declarative schema management with ordered SQL files and comprehensive role-based access control.

## Common Development Commands

### Core Development Workflow
```bash
# Start local Supabase stack
supabase start

# Reset database with migrations and seed data
supabase db reset

# Serve Edge Functions (choose appropriate env file)
supabase functions serve --env-file ./functions/.env

# Full environment reset (automated) - includes Strapi migration
deno task generate:dev:environment
```

### Database Schema Management
```bash
# After editing files in schemas/ directory:
supabase db diff -f descriptive_name    # Generate migration
# Add new migration to config.toml schema_paths
supabase db reset                        # Apply changes

# Generate TypeScript types from database
deno task generate:supabase:types
```

### Testing and Development
```bash
# Run all tests
deno task test

# Run akademy function tests specifically
deno task test:akademy

# Run user-management function tests specifically
deno task test:user-management

# Create test users for all roles (generates credentials.json)
deno task generate:test:users

# Format and lint code
deno fmt
deno lint
```

### Branch Management
```bash
# Create feature branch (interactive or with name)
deno task branch:feature
deno task branch:feature "user dashboard"

# Create hotfix branch
deno task branch:hotfix "auth bug fix"

# Branch naming convention:
# - Features: feat/feature-name-here  
# - Hotfixes: hotfix/issue-description
```

### Function Development
```bash
# Akademy function (unified migration and user management API)
cd functions/akademy
deno task dev          # Watch mode development
deno task test         # Run function tests

# User Management function (Hono-based user operations) 
cd functions/user-management
deno task dev          # Watch mode development
deno task test         # Run function tests

# Test endpoints at:
# http://localhost:54321/functions/v1/akademy
# http://localhost:54321/functions/v1/user-management
```

## Architecture Patterns

### Database Schema Loading Order
Schemas load in sequence defined in config.toml:
1. Extensions → 2. RBAC helpers → 3. Core entities → 4. Triggers → 5. Functions

**Critical**: Always add new schema files to config.toml `schema_paths` array in correct order.

### Schema File Execution Rules
- **Order matters**: Files execute in the exact order listed in `config.toml` `schema_paths` array
- **Missing files fail**: If a file is not in `schema_paths`, it won't be included in migrations
- **Dependencies first**: Functions, policies, and triggers must be defined AFTER the entities they reference
- **Example dependency issue**: If `workflow_policies.sql` runs before `workflow_rbac.sql`, policies referencing RBAC helper functions will fail

**Correct workflow order example:**
```toml
schema_paths = [
  "./schemas/workflows.sql",        # 1. Tables first
  "./schemas/workflow_rbac.sql",    # 2. RBAC helpers next
  "./schemas/workflow_audit.sql",   # 3. Audit triggers
  "./schemas/workflow_policies.sql", # 4. Policies (uses RBAC functions)
  "./schemas/workflow_functions.sql" # 5. Helper functions last
]
```

### Edge Functions Structure
- **akademy**: Unified function combining data migration and user management with Hono framework
  - Migration endpoint: `/migrate` (dual authentication: JWT + super password)
  - User management endpoints: `/create-user`, `/reset-password`, `/deactivate-user` (JWT + role-based)
- **user-management**: Legacy Hono-based user operations API (maintained for compatibility)

The akademy function serves as the primary API using Hono framework for modern routing, middleware patterns, and centralized authentication layers with shared CORS utilities.

### Authentication Patterns
- **Migration endpoints**: Dual auth (JWT + super password with timing-safe comparison)
- **User management endpoints**: JWT token validation with role-level enforcement
- **Role hierarchy**: Users can only create/modify equal or lower role levels
- **Database**: Row-level security (RLS) policies throughout

### Testing Strategy
- Role-based test helpers in `tests/_testHelpers.ts`
- Auto-generated test users with `credentials.json`
- Pattern: `getClientForRole('admin')` → test operations → cleanup test data
- Tests both allowed and denied operations for RLS validation

## Key Development Notes

### Schema Changes
1. Edit SQL files in `schemas/` directory
2. Run `supabase db diff -f name` to generate migration  
3. Add migration path to `config.toml` schema_paths
4. Apply with `supabase db reset`

### Edge Function Testing
Local endpoints: `http://localhost:54321/functions/v1/{function-name}`
Functions require appropriate environment files for authentication.

### Migration Development
- Akademy function `/migrate` endpoint uses incremental timestamp-based tracking
- Dual authentication required (JWT + super password)
- Migration history tracked in `strapi_migrations` table
- Maps external Strapi data to internal schema with data normalization
- Batch processing and duplicate detection for large datasets

### Type Safety
- Generated types: `types/supabase.type.ts`
- Zod schemas for validation in `functions/*/schemas/`
- Strict TypeScript enabled across project

### Akademy Function (Unified API)
The primary function combining data migration and user management with role-based access control.

#### Migration Endpoints:
- **Migrate from Strapi** (`POST /migrate`): Dual auth required (JWT + super password)
  - Incremental data migration with timestamp tracking
  - Data normalization and duplicate detection
  - Comprehensive error handling and migration history
  - Returns detailed statistics and processed data

#### User Management Endpoints:
- **Create User** (`POST /create-user`): Level 30+ required
  - Creates users from prospect agreements
  - Auto-generates passwords
  - Role hierarchy enforcement (cannot create higher-level roles)
  - Returns comprehensive user data including generated password
  
- **Reset Password** (`POST /reset-password`): Level 30+ required
  - Identity verification using multiple data points
  - Service role password updates
  
- **Deactivate User** (`POST /deactivate-user`): Level 50+ required
  - Bans user account (100 years)
  - Updates associated agreement status to inactive

#### Key Features:
- Built with Hono framework for modern routing and middleware
- Dual authentication patterns for different endpoint types
- Comprehensive Zod schema validation throughout
- Automatic password generation and role hierarchy enforcement
- Full test coverage with authentication mocking
- Centralized error handling and CORS configuration

#### Development:
```bash
cd functions/akademy
deno task dev    # Start development server
deno task test   # Run comprehensive tests
```

### Legacy User Management Function (Compatibility)
Maintained for backward compatibility - use akademy function for new development.

## Project-Specific Conventions

### Code Style (deno.json)
- Tabs for indentation (width: 4)
- Single quotes for strings
- Semicolons required
- Line width: 80 characters

### Environment Management
- Multiple `.env` files per function
- Service role keys for admin operations
- Anon keys for client operations
- External API tokens for integrations

### Data Management
- Full-text search using tsvector for names
- Comprehensive audit logging
- Automated test user generation for each database role
- Seed data includes countries, headquarters, roles, and test data

## Supabase Function Guidelines

### Database Functions
- **Default to `SECURITY INVOKER`**: Functions run with user permissions for safer access control
- **Set `search_path = ''`**: Always set to empty string and use fully qualified names
- **Use explicit typing**: Clearly specify input/output types
- **Minimize side effects**: Prefer functions that return results over data modification
- **Default to IMMUTABLE/STABLE**: Use VOLATILE only for data modification or side effects

### Example Function Template
```sql
create or replace function public.function_name(param1 type)
returns return_type
language plpgsql
security invoker
set search_path = ''
as $$
begin
  -- function body with fully qualified names
  return result;
end;
$$;
```

**Common mistakes to avoid:**
- ❌ Don't duplicate `LANGUAGE` after `$$` - specify only in function signature
- ❌ Don't use `OLD`/`NEW` in RLS policies - only available in triggers  
- ❌ Don't use unqualified table names - always use `public.table_name`

### RLS Policies
- **Separate policies**: Use separate policies for SELECT, INSERT, UPDATE, DELETE (never use FOR ALL)
- **Use meaningful names**: Policy names should be descriptive and enclosed in double quotes
- **Specify roles**: Always use TO clause (authenticated/anon)
- **Performance**: Add indexes on policy columns, use SELECT wrapping for functions
- **No OLD/NEW references**: RLS policies cannot use OLD or NEW - these are only available in triggers
- **Clause rules**:
  - SELECT: USING only, no WITH CHECK
  - INSERT: WITH CHECK only, no USING  
  - UPDATE: Both USING and WITH CHECK
  - DELETE: USING only, no WITH CHECK
- **Field-level restrictions**: Cannot prevent specific field changes in RLS - handle in application logic

### Updated Timestamp Triggers
Use `moddatetime` procedure for automatic timestamp updates:
```sql
CREATE TRIGGER handle_updated_at_table_name
    BEFORE UPDATE ON table_name
    FOR EACH ROW EXECUTE PROCEDURE moddatetime(updated_at);
```

## Supabase Edge Functions Development

### Critical Function Configuration Rules

#### Lockfile Management
- **Remove incompatible lockfiles**: Edge Runtime may not support latest Deno lockfile versions
- **Safe approach**: Delete `deno.lock` files if getting "Unsupported lockfile version" errors
- **Auto-regeneration**: Supabase will regenerate compatible lockfiles during deployment

#### Import Map Configuration
- **Function-specific imports**: Each function should have its own `deno.json` with `imports` section
- **Avoid shared import maps**: Don't use `importMap` pointing to shared files in production
- **Required dependencies**:
  ```json
  {
    "imports": {
      "@supabase/supabase-js": "jsr:@supabase/supabase-js@2",
      "@std/crypto": "jsr:@std/crypto@1.0.4",
      "@std/crypto/timing-safe-equal": "jsr:@std/crypto@1.0.4/timing-safe-equal",
      "@std/encoding/base64": "jsr:@std/encoding@1/base64",
      "hono": "jsr:@hono/hono@4",
      "hono/cors": "jsr:@hono/hono@4/cors",
      "hono/http-exception": "jsr:@hono/hono@4/http-exception",
      "zod": "https://deno.land/x/zod@v3.22.4/mod.ts"
    }
  }
  ```

#### Function Export Format
- **Use Deno.serve()**: Functions must use `Deno.serve(app.fetch)` format, not default exports
- **Entry point**: Use `main.ts` or `index.ts` as entry point (configure in `config.toml`)

#### Route Path Handling
- **Function name prefix**: Supabase passes requests with function name in path
- **Route definition**: Routes must include function name: `app.get('/akademy/health', ...)`
- **URL structure**: `http://localhost:54321/functions/v1/akademy/health` → path = `/akademy/health`

#### Configuration in config.toml
```toml
[functions.function-name]
enabled = true
verify_jwt = false  # Set based on your auth needs
entrypoint = "./functions/function-name/main.ts"
# Do NOT include import_map if using function-specific deno.json
```

### Function Development Workflow

#### Debugging Steps
1. **Start with minimal function**: Test basic functionality before adding complex imports
2. **Add imports incrementally**: Import modules one by one to identify problematic dependencies
3. **Test each change**: Verify function boots and responds after each modification
4. **Use debug routes**: Add catch-all routes to understand path structure during development

#### Testing Commands
```bash
# Serve functions locally
npx supabase functions serve --no-verify-jwt

# Test basic connectivity
curl http://127.0.0.1:54321/functions/v1/function-name/health

# Check function boot logs for errors
npx supabase functions serve --debug
```

#### Common Boot Errors and Solutions
- **"Unsupported lockfile version"**: Delete `deno.lock` file
- **"Worker failed to boot"**: Check import map configuration and entry point
- **"Module not found"**: Verify function-specific imports in `deno.json`
- **"Function not found"**: Check function is enabled in `config.toml`

### Hono Framework Integration
- **Route prefixes**: All routes must include function name prefix
- **CORS handling**: Configure CORS middleware for cross-origin requests
- **Authentication**: Implement middleware for JWT validation and role-based access
- **Error handling**: Use Hono's error handling and HTTPException for consistent responses

## Production Deployment

Use direct Supabase CLI commands for production operations. See `docs/production-cli-commands.md` for complete reference.

### Essential Commands
```bash
# Deploy database migrations
npx supabase db push --include-seed

# Deploy Edge Functions
npx supabase functions deploy --no-verify-jwt

# Create database backup
npx supabase db dump -f backup-$(date +%Y%m%d-%H%M%S).sql

# Reset production database (DANGEROUS!)
npx supabase db reset --linked

# Compare local vs remote schemas
npx supabase db diff --linked --use-migra
```

### Prerequisites
1. **Environment Variables Required**:
   ```bash
   export SUPABASE_DB_PASSWORD="your_db_password"
   export SUPABASE_PROJECT_ID="your_project_ref"  # Optional
   ```

2. **Project Setup**:
   ```bash
   npx supabase link --project-ref your_project_id
   npx supabase status  # Verify connection
   ```

### Complete Deployment Workflow
```bash
# 1. Deploy database changes
npx supabase db push --include-seed

# 2. Deploy secrets (if any)
npx supabase secrets set --env-file .env

# 3. Deploy functions
npx supabase functions deploy --no-verify-jwt

# 4. Verify deployment
npx supabase migration list --remote
curl https://your-project.supabase.co/functions/v1/akademy/health
```

### Monitoring and Validation
```bash
# Check function health
curl https://your-project.supabase.co/functions/v1/akademy/health

# View function logs
npx supabase functions logs akademy

# Check migration status
npx supabase migration list --remote
```

See `docs/production-cli-commands.md` for comprehensive CLI command reference.


- to serve supabase functions locally: npx supabase functions serve --env-file=<path-to-env-file>
- to push all secrets from .env file to our remote supabase project (npx):  supabase secrets set --env-file ./supabase/.env

# You can also set secrets individually using:
supabase secrets set MY_NAME=Chewbacca

- You don't need to re-deploy after setting your secrets.
- To see all the secrets which you have set remotely, use: supabase secrets list
