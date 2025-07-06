# Akademy Supabase Backend

A comprehensive educational platform backend built with Supabase, PostgreSQL, and Deno Edge Functions. This backend supports Akademy's multi-country educational organization management system with robust authentication, role-based access control, and automated data migration capabilities.

## 🏗️ Architecture Overview

### Technology Stack
- **Database**: PostgreSQL 15 with Row Level Security (RLS)
- **Backend**: Supabase with Deno Edge Functions
- **Runtime**: Deno 2.0 with TypeScript
- **Framework**: Hono.js for API routing
- **Authentication**: JWT with role-based permissions
- **Validation**: Zod schemas for type-safe data validation
- **Migration**: Automated Strapi CMS data migration

### Key Features
- 🔐 **Advanced RBAC**: 7-level role hierarchy with granular permissions
- 📊 **Data Migration**: Automated import from external Strapi CMS
- 👥 **User Management**: Complete lifecycle management with role enforcement
- 🔔 **Notification System**: Real-time notifications with template system
- 🛡️ **Security**: Comprehensive RLS policies and audit logging
- 🏢 **Multi-tenant**: Support for multiple headquarters and countries
- 📈 **Analytics**: Dashboard functions and reporting capabilities

## 📁 Project Structure

```
supabase/
├── config.toml                    # Supabase configuration
├── deno.json                      # Deno tasks and dependencies
├── credentials.json               # Generated test user credentials
├── schemas/                       # Database schema files (ordered)
│   ├── extensions.sql             # PostgreSQL extensions
│   ├── rbac_helpers.sql           # Role-based access helpers
│   ├── roles.sql                  # User roles and permissions
│   ├── countries.sql              # Country master data
│   ├── headquarters.sql           # Organization headquarters
│   ├── collaborators.sql          # Staff and facilitators
│   ├── agreements.sql             # Student agreements/contracts
│   ├── students.sql               # Student management
│   ├── workflows.sql              # Business process workflows
│   ├── notifications.sql          # Notification system
│   └── [30+ more schema files]    # Additional entities and functions
├── functions/
│   └── akademy-app/               # Main Edge Function
│       ├── index.ts               # Hono app entry point
│       ├── migration.ts           # Strapi data migration
│       ├── create-user.ts         # User creation from agreements
│       ├── reset-password.ts      # Password reset functionality
│       ├── deactivate-user.ts     # User deactivation
│       ├── notifications.ts       # Notification management
│       └── [additional modules]   # Authentication, validation, etc.
├── scripts/                       # Development and deployment scripts
├── docs/                          # Comprehensive documentation
├── migrations/                    # Generated migration files
└── types/                         # TypeScript type definitions
```

## 🚀 Quick Start

### Prerequisites
- **Node.js** 18+ and npm
- **Deno** 2.0+
- **Supabase CLI** 2.24.3+
- **Git** for version control

### Local Development Setup

1. **Clone and Install**
```bash
git clone <repository-url>
cd supabase
npm install
```

2. **Start Supabase Stack**
```bash
# Start all Supabase services
supabase start

# Reset database with migrations and seed data
supabase db reset
```

3. **Generate Development Environment**
```bash
# Automated setup: reset DB + create test users + generate types
deno task generate:dev:environment
```

4. **Serve Edge Functions**
```bash
# Start function server with local environment
deno task serve:local

# Or manually with specific env file
supabase functions serve --env-file .env.local
```

5. **Verify Setup**
```bash
# Test health endpoint
curl http://localhost:54321/functions/v1/akademy-app/health

# View Supabase Studio
open http://localhost:54323
```

## 📋 Development Commands

### Core Development Workflow
```bash
# Database Management
supabase db reset                   # Reset with migrations + seed
deno task generate:supabase:types   # Generate TypeScript types
supabase db diff -f migration_name  # Create new migration

# Testing
deno task test                      # Run all tests
deno task test:akademy             # Test main function
deno task generate:test:users      # Create test user credentials

# Development
deno task serve:local              # Serve functions locally
deno fmt                           # Format code
deno lint                          # Lint TypeScript

# Production Operations
deno task deploy:db:seed           # Deploy database + seed
deno task deploy:functions         # Deploy Edge Functions
deno task backup:db                # Create database backup
```

### Branch Management
```bash
# Feature development
deno task branch:feature           # Interactive feature branch
deno task branch:feature "user dashboard"  # Named feature branch

# Hotfix branches
deno task branch:hotfix "auth bug fix"
```

## 🗄️ Database Schema

### Core Entities
- **Users & Authentication**: Supabase Auth integration with custom profiles
- **Organizations**: Countries, headquarters, collaborators
- **Educational**: Students, agreements, workshops, attendance
- **Workflows**: Business process management with audit trails
- **Notifications**: Template-based notification system

### Role Hierarchy (1-99 scale)
```
1-9:   Public/Guest access
10-19: Students
20-29: Student companions/parents
30-39: Facilitators
40-49: Coordinators
50-59: Administrators
60-69: Regional managers
70-79: Country directors
80-89: Executive team
90-99: Super administrators
```

### Schema Loading Order
Critical: Schemas load in the exact order defined in `config.toml`:
1. **Extensions** → PostgreSQL extensions
2. **RBAC Helpers** → Role-based access functions
3. **Core Entities** → Tables and basic structures
4. **Relationships** → Foreign keys and mappings
5. **Triggers** → Automated actions
6. **Functions** → Business logic and API helpers

## 🔌 API Endpoints

### Base URL
- **Local**: `http://localhost:54321/functions/v1/akademy-app`
- **Production**: `https://your-project.supabase.co/functions/v1/akademy-app`

### Health Check
```bash
GET /health
# Returns: { status: 'ok', timestamp: '...', version: '1.0.0' }
```

### Data Migration (Dual Authentication Required)
```bash
POST /migrate
Headers:
  Authorization: Bearer <jwt_token>
  Content-Type: application/json
Body: {
  "super_password": "your_super_password",
  "endpoints": ["agreements", "students", "collaborators"],
  "batch_size": 100
}
```

### User Management (Role-Based Access)

**Create User** (Level 30+ required)
```bash
POST /create-user
Headers:
  Authorization: Bearer <jwt_token>
Body: {
  "agreement_id": "uuid",
  "role_level": 10,
  "send_credentials": true
}
```

**Reset Password** (Level 30+ required)
```bash
POST /reset-password
Headers:
  Authorization: Bearer <jwt_token>
Body: {
  "identifier": "email@example.com or document_number",
  "identifier_type": "email"
}
```

**Deactivate User** (Level 50+ required)
```bash
POST /deactivate-user
Headers:
  Authorization: Bearer <jwt_token>
Body: {
  "user_id": "uuid",
  "reason": "violation_terms"
}
```

### Notification System
```bash
# Send notification
POST /notifications/send
# Search users
GET /notifications/search-users?q=search_term
# Get user notifications
GET /notifications?user_id=uuid
# Mark as read
PUT /notifications/read
```

## 🧪 Testing

### Test Framework
- **Deno Test** for unit and integration tests
- **Role-based test helpers** for authentication scenarios
- **Generated test users** with all role levels
- **Cleanup utilities** for test data management

### Running Tests
```bash
# All tests
deno task test

# Specific function tests
deno task test:akademy
deno task test:user-management

# Test route access with different roles
deno task test:route:access
```

### Test User Credentials
After running `deno task generate:test:users`, check `credentials.json`:
```json
{
  "admin": {
    "email": "admin@test.com",
    "password": "generated_password",
    "role_level": 50
  }
}
```

## 🔒 Security & Authentication

### Authentication Methods
- **JWT Tokens**: Standard Supabase auth for most endpoints
- **Dual Authentication**: JWT + super password for migration endpoints
- **Role Enforcement**: Hierarchical permission system
- **Service Role**: Admin operations bypass RLS when needed

### Row Level Security (RLS)
- **Policy Separation**: Distinct policies for SELECT, INSERT, UPDATE, DELETE
- **Role-based Filtering**: Data access based on user role level
- **Audit Trails**: Comprehensive logging of all data changes
- **Field-level Protection**: Sensitive data restricted by role

### Environment Variables
```bash
# Required for functions
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_anon_key
SUPABASE_SERVICE_ROLE_KEY=your_service_key

# Migration credentials (optional)
STRAPI_API_URL=https://your-strapi.com
STRAPI_API_TOKEN=your_api_token
SUPER_PASSWORD=your_super_password
```

## 🚀 Production Deployment

### Prerequisites
1. **Supabase Project**: Create and configure your production project
2. **Environment Setup**: Prepare production environment variables
3. **CLI Access**: Install and authenticate Supabase CLI

### Deployment Steps

1. **Link Project**
```bash
export SUPABASE_DB_PASSWORD="your_db_password"
npx supabase link --project-ref your_project_ref
```

2. **Deploy Database**
```bash
# Deploy all schemas and seed data
npx supabase db push --include-seed
```

3. **Deploy Functions**
```bash
# Set secrets first
npx supabase secrets set --env-file .env.production

# Deploy all functions
npx supabase functions deploy --no-verify-jwt
```

4. **Verify Deployment**
```bash
# Check migration status
npx supabase migration list --remote

# Test health endpoint
curl https://your-project.supabase.co/functions/v1/akademy-app/health
```

### Production Monitoring
```bash
# Function logs
npx supabase functions logs akademy-app

# Database status
npx supabase status --linked

# Create backups
deno task backup:db
```

## 📚 Documentation

### Comprehensive Guides
- **[Production Deployment](docs/PRODUCTION_DEPLOYMENT_GUIDE.md)**: Complete deployment workflow
- **[Notification System](docs/NOTIFICATION_SYSTEM_GUIDE.md)**: Real-time notifications setup
- **[CLI Commands](docs/production-cli-commands.md)**: Full command reference
- **[CLAUDE.md](CLAUDE.md)**: AI assistant development guide

### Key Concepts
- **Schema Dependencies**: Understanding load order and relationships
- **RBAC Implementation**: Role hierarchy and permission management
- **Migration Strategy**: Incremental data import from external sources
- **Edge Function Patterns**: Hono framework usage and middleware

## 🛠️ Development Guidelines

### Code Style (deno.json)
- **Indentation**: Tabs (width: 4)
- **Quotes**: Single quotes
- **Semicolons**: Required
- **Line width**: 80 characters
- **TypeScript**: Strict mode enabled

### Database Function Patterns
```sql
-- Template for secure database functions
create or replace function public.function_name(param1 type)
returns return_type
language plpgsql
security invoker  -- Use user permissions
set search_path = ''  -- Always explicit schema
as $$
begin
  -- Use fully qualified names: public.table_name
  return result;
end;
$$;
```

### Edge Function Requirements
- **JSR Imports**: Use full JSR paths in TypeScript files
- **Function-specific deno.json**: Each function has its own configuration
- **Hono Framework**: Modern routing with middleware patterns
- **Path Handling**: Include function name in all routes

## 🤝 Contributing

### Development Workflow
1. **Feature Branch**: `deno task branch:feature "feature-name"`
2. **Development**: Make changes with tests
3. **Testing**: `deno task test` and verify locally
4. **Schema Changes**: Add to `config.toml` in correct order
5. **Migration**: `supabase db diff -f descriptive_name`
6. **Documentation**: Update relevant docs
7. **Pull Request**: Submit for review

### Schema Change Process
1. Edit SQL files in `schemas/` directory
2. Add new files to `config.toml` schema_paths in dependency order
3. Generate migration: `supabase db diff -f descriptive_name`
4. Test locally: `supabase db reset`
5. Generate types: `deno task generate:supabase:types`

## 📊 Monitoring & Analytics

### Health Monitoring
- **Function Health**: `/health` endpoint for status checks
- **Database Metrics**: Built-in Supabase analytics
- **Error Tracking**: Comprehensive logging and audit trails
- **Performance**: Dashboard functions for insights

### Audit System
- **User Actions**: All CRUD operations logged
- **Role Changes**: Permission modifications tracked
- **Data Migration**: Import history and statistics
- **Security Events**: Authentication and authorization logs

## 🆘 Troubleshooting

### Common Issues

**Function Boot Errors**
- Delete `deno.lock` if version conflicts occur
- Verify JSR imports use full paths
- Check function configuration in `config.toml`

**Schema Loading Failures**
- Verify dependency order in `config.toml`
- Check for missing schema files
- Ensure RBAC helpers load before dependent policies

**Authentication Issues**
- Verify JWT token validity and permissions
- Check role level requirements for endpoints
- Ensure RLS policies allow user access

**Migration Problems**
- Verify dual authentication (JWT + super password)
- Check external API connectivity
- Review migration history in `strapi_migrations` table

### Getting Help
- **Documentation**: Check `/docs` directory for guides
- **Logs**: Use `npx supabase functions logs` for debugging
- **Community**: Supabase Discord and GitHub discussions
- **Support**: Create issues in project repository

---

## 📝 License

This project is part of the Akademy educational platform. All rights reserved.

## 📞 Contact

For questions about this backend system, please contact the development team or create an issue in the project repository.

---

**Built with ❤️ for educational excellence**