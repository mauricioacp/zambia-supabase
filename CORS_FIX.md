# CORS Fix for Akademy-App Edge Function

## The Issue
Your frontend at `http://localhost:4200` is being blocked by CORS when trying to call the edge function at `http://127.0.0.1:54321/functions/v1/akademy-app/create-user`.

## The Fix Applied
I've added CORS middleware to the `akademy-app` function:

```typescript
import { cors } from 'hono/cors';

// Enable CORS for all origins in development
app.use('*', cors({
    origin: '*',
    allowHeaders: ['Content-Type', 'Authorization'],
    allowMethods: ['GET', 'POST', 'OPTIONS'],
    credentials: true,
}));
```

## Steps to Resolve

1. **Make sure Supabase is running:**
   ```bash
   npx supabase start
   ```

2. **Serve the edge function with the correct environment file:**
   ```bash
   npx supabase functions serve akademy-app --env-file .env.local
   ```

3. **Verify the function is running:**
   ```bash
   # Test the health endpoint
   curl http://127.0.0.1:54321/functions/v1/akademy-app/health
   ```

4. **If you're still getting CORS errors, try these alternatives:**

   ### Option A: Use --no-verify-jwt flag
   ```bash
   npx supabase functions serve akademy-app --env-file .env.local --no-verify-jwt
   ```

   ### Option B: Restart everything
   ```bash
   npx supabase stop
   npx supabase start
   npx supabase functions serve akademy-app --env-file .env.local
   ```

   ### Option C: Check if another process is using the port
   ```bash
   lsof -i :54321
   ```

## Frontend Code Example
Make sure your frontend is calling the function correctly:

```typescript
const response = await fetch('http://127.0.0.1:54321/functions/v1/akademy-app/create-user', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${session.access_token}`,
  },
  body: JSON.stringify({
    agreement_id: 'your-agreement-uuid'
  })
});
```

## Production CORS Configuration
For production, you might want to be more restrictive:

```typescript
app.use('*', cors({
    origin: ['https://yourdomain.com', 'https://app.yourdomain.com'],
    allowHeaders: ['Content-Type', 'Authorization'],
    allowMethods: ['GET', 'POST', 'OPTIONS'],
    credentials: true,
}));
```

## Common Issues

1. **Function not running**: Make sure you see "Function 'akademy-app' is ready to serve" in the terminal
2. **Wrong URL**: Ensure you're using `http://127.0.0.1:54321` not `http://localhost:54321`
3. **Missing environment variables**: The function needs the .env.local file to run properly