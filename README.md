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
  - [Strapi Migration Function](#strapi-migration-function)
  - [Akademy Admin Function](#akademy-admin-function)
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
   supabase functions serve --env-file ./functions/strapi-migration/.env
   supabase functions serve --env-file ./functions/akademy-app/.env
   ```
6. (Optional) Full dev environment reset & start:
   ```powershell
   .\scripts\regenerate-dev.ps1 -Verbose
   ```

## Project Structure

```
/ (root)
├─ config.toml           # Supabase CLI configuration
├─ schemas/              # Declarative SQL schema files
├─ migrations/           # Auto-generated migration files
├─ seed.sql              # Initial seed data
├─ functions/            # Supabase Edge Functions
│  ├─ strapi-migration/  # Migrate data from Strapi CMS
│  └─ akademy-app/       # Admin API for agreements, roles, etc.
├─ scripts/              # Developer helper scripts
│  └─ regenerate-dev.ps1  # Reset & start local environment
└─ README.md             # Project overview (this file)
```

## Configuration

- **config.toml**: Defines project ID, ports, enabled services, and schema/seed paths.
- **.env** files (in `functions/*` and `scripts/`): Store API URLs, tokens, and Supabase keys.

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

- **regenerate-dev.ps1**: Automates environment reset, local Supabase, functions, Node app, ngrok, and initial migration/seed.

## Development Workflow

1. Start Supabase and functions locally
2. Modify schemas or function code
3. Test endpoints (e.g., `http://localhost:54321/functions/v1/...`)
4. Commit changes and migrations

## Deployment

- Push database changes: `supabase db push`
- Deploy functions: `supabase functions deploy`
- Ensure production env vars are set securely

## Contributing

Contributions welcome! Please open an issue or PR with details of your changes.

## License

This project is licensed under the MIT License.
