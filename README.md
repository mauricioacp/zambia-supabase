# Akademia Supabase Project

This repository contains the backend for the Akademia project, powered by Supabase. It includes:

- PostgreSQL schema and migrations
- Seed data and TypeScript seeding scripts
- Supabase Edge Functions (Deno/TypeScript)
- Developer scripts for local environment management

## Table of Contents

- [Prerequisites](#prerequisites)
- [Quickstart](#quickstart)
- [Project Structure](#project-structure)
- [Configuration](#configuration)
- [Database Schema & Migrations](#database-schema--migrations)
- [Seed Data](#seed-data)
- [Edge Functions](#edge-functions)
  - [Akademy Function](#akademy-function)
- [Developer Scripts](#developer-scripts)
- [Development Workflow](#development-workflow)
- [Deployment](#deployment)
- [Contributing](#contributing)
- [License](#license)

## Prerequisites

- Supabase CLI (>=1.x)
- Docker & Docker Compose
- Deno (>=1.x)
- Node.js & npm
- PowerShell (Windows)

## Quickstart

1. Clone this repo:
   ```bash
   git clone <repo-url>
   cd supabase
   ```
2. (Optional) Link a remote project:
   ```bash
   supabase link
   ```
3. Start local services:
   ```bash
   supabase start
   ```
4. Apply migrations and seed data:
   ```bash
   supabase db reset
   ```
5. Serve Edge Functions:
   ```bash
   supabase functions serve --env-file ./functions/.env
   ```
6. (Optional) Full dev environment reset & start:
   ```bash
   deno task generate:dev:environment
   ```

## Project Structure

```
/ (root)
├─ config.toml           # Supabase CLI configuration
├─ schemas/              # Declarative SQL schema files
├─ migrations/           # Auto-generated migration files
├─ seed.sql              # Initial seed data
├─ functions/            # Supabase Edge Functions
│  ├─ akademy/           # Unified API: migration + user management
│  ├─ user-management/   # Legacy user management (compatibility)
│  └─ .env               # Centralized environment configuration
├─ scripts/              # Developer helper scripts
│  └─ regenerate-dev.ts  # Reset & start local environment
└─ README.md             # Project overview (this file)
```

## Configuration

- **config.toml**: Defines project ID, ports, enabled services, and schema/seed paths.
- **functions/.env**: Centralized environment configuration for all functions.

## Edge Functions

### Akademy Function

The primary function combining data migration and user management capabilities:

- **Migration**: `POST /migrate` - Migrates data from Strapi CMS with dual authentication
- **User Management**: Create, reset password, and deactivate users with role-based access
- **Health Check**: `GET /health` - Function status and service listing

Access at: `http://localhost:54321/functions/v1/akademy`

To get local schema types:

```bash
supabase gen types typescript --local > scripts/supabase.type.ts
```

## Database Schema & Migrations

Schemas live in `schemas/` and load in order via `config.toml`:

```toml
schema_paths = [
  "./schemas/extensions.sql",
  ...
]
```

To update the schema:
1. Stop services: `supabase stop`
2. Edit SQL in `schemas/`
3. Generate migration: `supabase db diff -f descriptive_name`
4. Include in config.toml
5. Apply migrations: `supabase db reset`

## Seed Data

- **seed.sql**: Core seed statements.
- **scripts/create-test-users.ts**: Deno script to generate test users.

## Developer Scripts

- **regenerate-dev.ts**: Automates complete environment reset including:
  - Cleanup of old migrations
  - Supabase stack restart with fresh database  
  - Edge function serving
  - Strapi data migration via `/akademy/migrate` endpoint
  - Generation of new migration file with migrated data
  - Test user creation and type generation

## Development Workflow

1. Start Supabase and functions locally: `deno task generate:dev:environment`
2. Modify schemas or function code
3. Test endpoints:
   - Akademy function: `http://localhost:54321/functions/v1/akademy`
   - User management: `http://localhost:54321/functions/v1/user-management`
4. Run tests: `deno task test:akademy` or `deno task test:user-management`
5. Commit changes and migrations

## Deployment

- Push database changes: `supabase db push`
- Deploy functions: `supabase functions deploy`
- Ensure production env vars are set securely

## Contributing

Contributions welcome! Please open an issue or PR with details of your changes.

## License

This project is licensed under the MIT License.
