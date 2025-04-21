# Akademia Database Schema

This repository contains the database schema for the Akademia project, organized using Supabase's declarative schema approach.

## Schema Organization

The database schema is divided into multiple files in the `schemas/` directory:

1. `extensions.sql` - Database extensions
2. `countries.sql` - Countries table and related objects
3. `headquarters.sql` - Headquarters table and related objects
4. `seasons.sql` - Seasons table and related objects
5. `roles.sql` - Roles table and related objects
6. `agreements.sql` - Agreements table and related objects
7. `students.sql` - Students table and related objects
8. `collaborators.sql` - Collaborators table and related objects
9. `workshops.sql` - Workshops table and related objects
10. `events.sql` - Events table and related objects
11. `processes.sql` - Processes table and related objects

## Working with Schema Changes

When modifying the database schema, follow these steps:

1. **Stop the local database**:
   ```bash
   supabase stop
   ```

2. **Make changes to schema files**:
   Edit the appropriate file in the `schemas/` directory.

3. **Generate a new migration**:
   ```bash
   supabase db diff -f descriptive_name_for_change
   ```

4. **Review the generated migration**:
   Check the new file in `migrations/` to confirm it contains the expected changes.

5. **Apply the pending migration**:
   ```bash
   supabase start && supabase migration up
   ```
   
you can also use supabase db reset

## Deploying Schema Changes

To deploy schema changes to a remote Supabase project:

1. **Log in to Supabase CLI**:
   ```bash
   supabase login
   ```

2. **Link your remote project** (if not already linked):
   ```bash
   supabase link
   ```

3. **Deploy database changes**:
   ```bash
   supabase db push
   ```

## Dependencies Management

Schema files are loaded in the order specified in `config.toml`. This ensures that tables with foreign key dependencies are created in the correct order.

If you need to add new schema files, make sure to update the `schema_paths` list in `config.toml`.
