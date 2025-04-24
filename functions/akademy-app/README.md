# Akademy App Edge Function

This Edge Function serves as the foundation for the Akademy application, providing secure endpoints for various functionalities.

## Project Structure

The project follows a modular architecture for better maintainability and scalability:

```
akademy-app/
├── config/             # Configuration files
│   ├── env.ts          # Environment variables
│   └── routes.ts       # URL patterns for routing
├── middleware/         # Middleware functions
│   ├── auth.ts         # Authentication middleware
│   └── cors.ts         # CORS handling middleware
├── routes/             # Route handlers
│   ├── admin/          # Admin route handlers
│   │   ├── agreements.ts  # Agreements CRUD operations
│   │   ├── index.ts    # Admin route dispatcher
│   │   └── users.ts    # Users operations
│   ├── index.ts        # Root route handler
│   ├── super-admin.ts  # Super admin creation
│   └── users.ts        # User creation
├── schemas/            # Zod validation schemas
│   ├── agreement.ts    # Agreement schema
│   └── user.ts         # User schemas
├── services/           # Service layer
│   └── supabase.ts     # Supabase client
├── utils/              # Utility functions
│   └── error.ts        # Error handling
├── main.ts             # Main entry point
├── main_test.ts        # Tests
└── README.md           # Documentation
```

## Authentication

The function implements two authentication mechanisms:

1. **Admin Authentication**: All routes under `/akademy-app/admin/*` require an `admin` header containing a secret password, which is compared against the `ADMIN_SECRET` environment variable.

2. **Super Admin Authentication**: The super admin creation route requires a JWT token in the `Authorization` header, which is compared against the `SUPER_ADMIN_JWT_SECRET` environment variable.

## Environment Variables

The function requires the following environment variables:

- `SUPABASE_URL`: The URL of your Supabase project
- `SUPABASE_SERVICE_ROLE_KEY`: The service role key for your Supabase project
- `ADMIN_SECRET`: The secret password for admin authentication
- `SUPER_ADMIN_JWT_SECRET`: The JWT token for super admin authentication

## Endpoints

### Root Endpoint

- `GET /akademy-app`: Returns a welcome message

### Admin Endpoints

All admin endpoints require the `admin` header with the correct secret.

#### Agreements

- `GET /akademy-app/admin/agreements`: Get all agreements
- `POST /akademy-app/admin/agreements`: Create a new agreement
- `PUT /akademy-app/admin/agreements`: Update an existing agreement
- `DELETE /akademy-app/admin/agreements`: Delete an agreement

#### Users

- `GET /akademy-app/admin/users`: Get all users

### User Creation

- `POST /akademy-app/users`: Create a new user and associate it with an agreement

  This endpoint requires the `admin` header with the correct secret.

  Request body:
  ```json
  {
    "email": "user@example.com",
    "password": "secure-password",
    "agreement_id": "uuid",
    "role_id": "uuid",
    "headquarter_id": "uuid"
  }
  ```

  The user will be created with metadata containing the agreement_id, role_id, and headquarter_id, which can be retrieved in the frontend during login.

### Super Admin Creation

- `POST /akademy-app/super-admin`: Create a super admin user

  This endpoint requires a JWT token in the `Authorization` header with the format `Bearer <token>`.

  Request body:
  ```json
  {
    "email": "admin@example.com",
    "password": "secure-password",
    "agreement_id": "uuid",
    "role_id": "uuid",
    "headquarter_id": "uuid"
  }
  ```

  The super admin user will be created with metadata containing the agreement_id, role_id, headquarter_id, and is_super_admin flag.

## Error Handling

The function includes proper error handling for all endpoints, returning appropriate status codes and error messages.

## CORS

The function includes CORS headers to allow cross-origin requests, with support for the following:

- Headers: authorization, x-client-info, apikey, content-type, admin
- Methods: POST, GET, PUT, DELETE, OPTIONS

## Development

To run the function locally:

```bash
cd functions/akademy-app
deno task dev
```

To run the tests:

```bash
cd functions/akademy-app
deno test
```

## Frontend Usage Example

Here's an example of how to use the user creation metadata in the frontend:

```typescript
const { data, error } = await supabase.auth.signUp({
  email: 'user@example.com',
  password: 'secure-password',
  options: {
    data: {
      agreement_id: '123',
      role_id: '456',
      headquarter_id: '789'
    }
  }
})
```

This metadata can be retrieved during login using:

```typescript
const { data, error } = await supabase.auth.getUser()
console.log(data.user.user_metadata)
// Output: { agreement_id: '123', role_id: '456', headquarter_id: '789' }
```
