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

# Full environment reset (automated)
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
# Akademy App function (admin API)
cd functions/akademy-app
deno task dev          # Watch mode development

# User Management function (Hono-based user operations)
cd functions/user-management
deno task dev          # Watch mode development
deno task test         # Run function tests

# Test endpoints at:
# http://localhost:54321/functions/v1/akademy-app
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
- **akademy-app**: Admin CRUD API with role-based endpoints (`/admin/*`, `/super-admin`)
- **strapi-migration**: Data migration function with dual authentication (JWT + super password)
- **user-management**: Hono-based user operations API with JWT authentication and role-based access control

All functions use middleware pattern with authentication layers and shared CORS utilities. The user-management function specifically uses Hono framework for modern routing and middleware handling.

### Authentication Patterns
- **Admin routes**: Secret header validation (`x-admin-secret`)
- **Super admin**: JWT token validation  
- **Migration function**: Dual auth (JWT + super password with timing-safe comparison)
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
- Strapi migration uses incremental timestamp-based tracking
- Dual authentication required (JWT + super password)
- Migration history tracked in `strapi_migrations` table
- Maps external Strapi data to internal schema

### Type Safety
- Generated types: `types/supabase.type.ts`
- Zod schemas for validation in `functions/*/schemas/`
- Strict TypeScript enabled across project

### User Management Function (Hono-based)
The user-management function provides role-based user operations with automatic password generation and role-level restrictions.

#### Endpoints and Access Levels:
- **Create User** (`POST /create-user`): Level 30+ required
  - Creates users from prospect agreements
  - Auto-generates passwords
  - Users can only create equal or lower role levels
  - Returns comprehensive user data including generated password
  
- **Reset Password** (`POST /reset-password`): Level 30+ required
  - Validates identity using email, document_number, phone, first_name, last_name
  - Updates password using service role key
  
- **Deactivate User** (`POST /deactivate-user`): Level 50+ required
  - Bans user account (100 years)
  - Updates associated agreement status to inactive

#### Key Features:
- Built with Hono framework for modern routing and middleware
- JWT-based authentication with role level validation
- Comprehensive Zod schema validation
- Automatic password generation for user creation
- Role hierarchy enforcement (users cannot create higher-level roles)
- Full test coverage with mock authentication for testing

#### Development:
```bash
cd functions/user-management
deno task dev    # Start development server
deno task test   # Run comprehensive tests
```

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
