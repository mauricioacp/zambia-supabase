# Strapi Migration Function

## Overview
The Strapi Migration Function is a Supabase Edge Function that migrates agreement data from a Strapi CMS to a Supabase database. 
It handles the transformation of data structures, mapping of related entities (roles and headquarters), and ensures data integrity by avoiding duplicates.

## Features
- Incremental migration (only fetches new or updated records since last successful migration)
- Data transformation from Strapi to Supabase schema
- Mapping of roles and headquarters between systems
- Duplicate detection and prevention
- Migration history tracking
- Detailed statistics about the migration process

## Prerequisites
- [Supabase CLI](https://supabase.com/docs/guides/cli) installed
- A running Supabase instance
- A Strapi CMS instance with agreement data
- Node.js and npm/Deno installed

## Setup

### Environment Variables
Create a `.env` file in the `functions` directory with the following variables:

```
STRAPI_API_URL=<your-strapi-api-url>
STRAPI_API_TOKEN=<your-strapi-api-token>
SUPABASE_URL=<your-supabase-url>
SUPABASE_SERVICE_ROLE_KEY=<your-supabase-service-role-key>
SUPABASE_ANON_KEY=<your-supabase-anon-key>
```

### Database Setup
Ensure your Supabase database has the following tables:
- `agreements` - Stores agreement data
- `agreement_roles` - Junction table for agreement-role relationships
- `roles` - Stores role definitions
- `headquarters` - Stores headquarters definitions
- `strapi_migrations` - Tracks migration history

## Usage

### Starting the Local Development Environment
1. Start your Supabase instance:
   ```
   supabase start
   ```

2. Apply database migrations and seed data:
   ```
   supabase db reset
   ```

3. Serve the function locally:
   ```
   supabase functions serve --env-file .\functions\.env
   ```

### Triggering the Migration
Send a POST request to the function endpoint with an Authorization header:

```
POST http://localhost:54321/functions/v1/strapi-migration
Authorization: Bearer <your-jwt-token>
```

## How It Works
1. The function connects to both Strapi and Supabase using the provided credentials
2. It checks the last successful migration timestamp from the `strapi_migrations` table
3. It fetches agreements from Strapi that were created or updated since the last migration
4. It transforms the Strapi data to match the Supabase schema
5. It checks for existing agreements in Supabase to avoid duplicates
6. It inserts new agreements and their role associations into Supabase
7. It records the migration in the `strapi_migrations` table

## Troubleshooting
- **Authentication Errors**: Ensure your API tokens and keys are correct in the `.env` file
- **Connection Issues**: Check that both Strapi and Supabase instances are running and accessible
- **Mapping Errors**: Verify that roles and headquarters in Strapi have corresponding entries in Supabase

## Contributing
Contributions are welcome! Please feel free to submit a Pull Request.