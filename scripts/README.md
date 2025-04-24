# Test User Management Script

This script creates test users in Supabase for each active role in your database. It's designed to help with local development and testing of role-based access control.

## Features

- Automatically creates one test user for each active role in your database
- Deletes existing test users before creating new ones
- Generates and displays JWT tokens for immediate use
- Outputs credentials for all created users
- Creates users without associating them to roles (role association will be handled separately)

## Prerequisites

- [Deno](https://deno.land/) installed on your system
- A running Supabase instance (local or remote)
- Service Role Key for your Supabase project

## Setup

1. Copy the `.env.example` file to a new file named `.env`:

```bash
cp .env.example .env
```

2. Edit the `.env` file and add your Supabase URL and Service Role Key:

```
SUPABASE_URL=http://127.0.0.1:54321
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key-here
```

For local development, the URL is typically `http://127.0.0.1:54321`. You can find your Service Role Key in the Supabase dashboard under Project Settings > API.

3. (Optional) Customize test user settings:

```
TEST_USER_PASSWORD=YourCustomPassword123!
TEST_USER_EMAIL_PREFIX=custom-prefix-
```

## Usage

Run the script with Deno:

```bash
deno run --allow-net --allow-env --allow-read create-test-users.ts
```

The script will:

1. Fetch all active roles from your database
2. For each role:
   - Check if a test user already exists
   - Delete the existing user if found
   - Create a new test user (without role association)
   - Generate a JWT token
   - Display the credentials

## Example Output

```
Fetching active roles...
Found 3 active roles

Processing role: Admin (admin)
Deleting existing test user for role Admin...
Creating new test user for role Admin...

=== TEST USER CREDENTIALS ===
Role: Admin
Email: test-user-admin@example.com
Password: Test123!
JWT: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
============================

Processing role: Editor (editor)
Creating new test user for role Editor...

=== TEST USER CREDENTIALS ===
Role: Editor
Email: test-user-editor@example.com
Password: Test123!
JWT: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
============================

Processing role: Viewer (viewer)
Creating new test user for role Viewer...

=== TEST USER CREDENTIALS ===
Role: Viewer
Email: test-user-viewer@example.com
Password: Test123!
JWT: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
============================

Test user management completed successfully!
```

## Notes

- The script creates users without associating them with roles. Role association will be handled separately.
- All test users are created with email confirmation already completed.
- The script uses the Supabase Admin API, which requires the Service Role Key.
