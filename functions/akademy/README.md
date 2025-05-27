# Akademy Function

A unified Supabase Edge Function built with Deno 2 and Hono that combines data migration and user management capabilities for the Akademia platform.

## Overview

The Akademy function serves as the central API for the Akademia platform, providing two main services:

1. **Data Migration**: Migrates data from Strapi CMS to Supabase with incremental updates and comprehensive validation
2. **User Management**: Role-based user operations including creation, password reset, and deactivation

## Architecture

This function uses the Hono web framework for modern routing and middleware handling, with separate authentication mechanisms for different service endpoints:

- **Migration endpoints**: Dual authentication (JWT + super password)
- **User management endpoints**: JWT-based role-level authentication

## API Endpoints

### Health Check
```http
GET /health
```
Returns the function status and available services.

**Response:**
```json
{
  "status": "ok",
  "timestamp": "2024-01-01T00:00:00.000Z",
  "services": ["migration", "user-management"]
}
```

### Data Migration

#### Migrate from Strapi
```http
POST /migrate
Authorization: Bearer <jwt-token>
x-super-password: <super-password>
```

Performs incremental data migration from Strapi CMS to Supabase.

**Authentication:**
- Requires both JWT token in Authorization header
- Requires super password in x-super-password header

**Features:**
- Incremental migration based on timestamps
- Duplicate detection and prevention
- Data normalization and mapping
- Comprehensive error handling and logging
- Migration history tracking

**Response:**
```json
{
  "success": true,
  "message": "Datos insertados correctamente",
  "statistics": {
    "strapiCount": 150,
    "supabaseInserted": 120,
    "transformedCount": 150,
    "excludedCount": 30,
    "excludedReason": "Agreements with the same email or document number already exist",
    "difference": 30
  },
  "data": [...]
}
```

### User Management

#### Create User from Agreement
```http
POST /create-user
Authorization: Bearer <jwt-token>
Content-Type: application/json

{
  "agreement_id": "uuid-of-prospect-agreement"
}
```

**Required Role Level**: 30+
**Features:**
- Creates users from prospect agreements
- Auto-generates secure passwords
- Role hierarchy enforcement (cannot create higher-level roles)
- Returns comprehensive user data including generated password

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

#### Reset User Password
```http
POST /reset-password
Authorization: Bearer <jwt-token>
Content-Type: application/json

{
  "email": "user@example.com",
  "document_number": "12345678",
  "new_password": "newPassword123",
  "phone": "123456789",
  "first_name": "John",
  "last_name": "Doe"
}
```

**Required Role Level**: 30+
**Features:**
- Identity verification using multiple data points
- Service role password update
- Comprehensive validation

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

#### Deactivate User
```http
POST /deactivate-user
Authorization: Bearer <jwt-token>
Content-Type: application/json

{
  "user_id": "uuid-of-user"
}
```

**Required Role Level**: 50+
**Features:**
- Bans user account (100 years)
- Updates associated agreement status
- High-level permission requirement

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
cd functions/akademy
deno task dev
```

### Testing
```bash
deno task test
```

### Environment Variables
```bash
# Supabase Configuration
SUPABASE_URL=http://localhost:54321
SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key

# Migration Configuration
STRAPI_API_URL=http://localhost:1337
STRAPI_API_TOKEN=your-strapi-token
SUPER_PASSWORD=your-super-password
```

## Building on the Function

### Adding New Migration Endpoints

1. **Create a new route file** in `routes/` directory:
```typescript
// routes/new-migration.ts
import { Context } from 'hono';
import { HTTPException } from 'hono/http-exception';

export async function newMigrationRoute(c: Context): Promise<Response> {
  // Implement your migration logic
  return c.json({ success: true });
}
```

2. **Add authentication if needed** using existing middleware:
```typescript
// In main.ts
import { newMigrationRoute } from './routes/new-migration.ts';

// For migration with dual auth (super password + JWT)
app.post('/new-migrate', async (c, next) => {
  // Add dual auth check here
  await next();
}, newMigrationRoute);
```

3. **Update tests** in `tests/akademy.test.ts`:
```typescript
Deno.test('New migration endpoint', async () => {
  const res = await makeRequest('/new-migrate', {
    method: 'POST',
    headers: {
      'Authorization': 'Bearer jwt-token',
      'x-super-password': 'password',
    },
  });
  
  assertEquals(res.status, 200);
});
```

### Adding New User Management Endpoints

1. **Create Zod schema** in `schemas/user.ts`:
```typescript
export const NewActionSchema = z.object({
  field: z.string().min(1, 'Field is required'),
});
```

2. **Create route handler** in `routes/`:
```typescript
// routes/new-action.ts
import { requireMinRoleLevel } from '../middleware/auth.ts';

export async function newAction(c: Context): Promise<Response> {
  const validatedData = NewActionSchema.parse(await c.req.json());
  // Implement logic
  return c.json({ data: result });
}
```

3. **Add to main.ts** with appropriate role level:
```typescript
// Requires role level 40+
app.post('/new-action', requireMinRoleLevel(40), newAction);
```

### Data Transformation and Validation

For migration endpoints, follow the existing pattern:

1. **Create service** in `services/` for external API integration
2. **Add mapping logic** in `services/mappingService.ts`
3. **Update interfaces** in `interfaces.ts` for new data types
4. **Add validation** in `utils/` if needed

### Error Handling

The function uses centralized error handling:

```typescript
// Validation errors automatically return 400
if (error instanceof ZodError) {
  throw new HTTPException(400, { message: 'Invalid request data' });
}

// Custom business logic errors
throw new HTTPException(404, { message: 'Resource not found' });
```

### Testing Strategy

1. **Unit tests** for individual functions in `utils/` and `services/`
2. **Integration tests** for complete endpoint workflows
3. **Authentication tests** for all permission levels
4. **Validation tests** for all Zod schemas

### Security Considerations

1. **Migration endpoints** require dual authentication for maximum security
2. **User management** enforces role hierarchy (cannot elevate privileges)
3. **Service role operations** are isolated and logged
4. **Input validation** is comprehensive using Zod schemas
5. **CORS** is configured for allowed origins only

## Monitoring and Debugging

### Logging
All operations include comprehensive logging:
- Migration statistics and progress
- Authentication attempts
- Validation failures
- Database operations

### Error Tracking
Errors are categorized by type:
- Authentication errors (401/403)
- Validation errors (400)
- Business logic errors (404/409)
- System errors (500)

### Performance
- Batch processing for large migrations
- Connection pooling for database operations
- Efficient duplicate detection algorithms

## Migration History

The function tracks all migration attempts in the `strapi_migrations` table:
- Timestamps of last successful migration
- Records processed counts
- Error messages for failed attempts
- Migration status tracking

This enables safe incremental migrations and rollback capabilities.