# User Management Function

A Supabase Edge Function built with Deno 2 and Hono for managing user operations with role-based access control.

## Features

### 1. Create User from Agreement
- **Endpoint**: `POST /create-user`
- **Required Role Level**: 30+
- **Description**: Creates a user from an existing prospect agreement and activates it
- **Restrictions**: Users can only create users with their own role level or lower

### 2. Reset User Password
- **Endpoint**: `POST /reset-password`
- **Required Role Level**: 30+
- **Description**: Resets a user's password with identity verification
- **Validation**: Requires matching email, document_number, phone, first_name, and last_name

### 3. Deactivate User
- **Endpoint**: `POST /deactivate-user`
- **Required Role Level**: 50+
- **Description**: Deactivates a user account and associated agreements

## Authentication

All endpoints require a valid JWT token in the Authorization header:
```
Authorization: Bearer <jwt-token>
```

The JWT token must contain user metadata with `role_level` property for authorization.

## API Endpoints

### Create User from Agreement
```http
POST /create-user
Content-Type: application/json
Authorization: Bearer <jwt-token>

{
  "agreement_id": "uuid-of-prospect-agreement"
}
```

**Response:**
```json
{
  "data": {
    "user_id": "uuid",
    "email": "user@example.com",
    "password": "generated-password",
    "headquarter_name": "HQ Name",
    "country_name": "Country",
    "season_name": "Season Name",
    "role_name": "Role Name",
    "phone": "123456789"
  }
}
```

### Reset Password
```http
POST /reset-password
Content-Type: application/json
Authorization: Bearer <jwt-token>

{
  "email": "user@example.com",
  "document_number": "12345678",
  "new_password": "newPassword123",
  "phone": "123456789",
  "first_name": "John",
  "last_name": "Doe"
}
```

**Response:**
```json
{
  "data": {
    "message": "Password successfully updated for user user@example.com",
    "new_password": "newPassword123",
    "user_email": "user@example.com"
  }
}
```

### Deactivate User
```http
POST /deactivate-user
Content-Type: application/json
Authorization: Bearer <jwt-token>

{
  "user_id": "uuid-of-user"
}
```

**Response:**
```json
{
  "data": {
    "message": "User user@example.com has been deactivated",
    "user_id": "uuid-of-user"
  }
}
```

## Development

### Local Development
```bash
cd functions/user-management
deno task dev
```

### Testing
```bash
deno task test
```

### Environment Variables
- `SUPABASE_URL`: Supabase project URL
- `SUPABASE_SERVICE_ROLE_KEY`: Service role key for admin operations

## Error Handling

All endpoints return structured error responses:
```json
{
  "error": "Error message",
  "status": 400
}
```

Common HTTP status codes:
- `400`: Bad Request (validation errors)
- `401`: Unauthorized (missing/invalid token)
- `403`: Forbidden (insufficient role level)
- `404`: Not Found (resource not found)
- `500`: Internal Server Error