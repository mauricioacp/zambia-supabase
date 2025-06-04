import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { HTTPException } from 'hono/http-exception';
import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { strapiMigrationRoute } from "./routes/migration.ts";
import { createUserFromAgreement } from "./routes/create-user.ts";
import { resetUserPassword } from "./routes/reset-password.ts";
import { deactivateUser } from "./routes/deactivate-user.ts";
import { requireMinRoleLevel } from "./middleware/auth.ts";

export const app = new Hono();

// Enable CORS for all origins in development
app.use('*', cors({
    origin: '*',
    allowHeaders: ['Content-Type', 'Authorization', 'x-client-info', 'apikey', 'X-Requested-With'],
    allowMethods: ['GET', 'POST', 'OPTIONS', 'PUT', 'DELETE'],
    credentials: true,
    exposeHeaders: ['Content-Length', 'X-JSON'],
    maxAge: 86400,
}));

app.get('/akademy-app/health', (c) => {
    return c.json({
        status: 'ok',
        timestamp: new Date().toISOString(),
        services: ['migration', 'user-management']
    });
});

app.onError((err, c) => {
    if (err instanceof HTTPException) {
        return c.json({
            error: err.message,
            status: err.status
        }, err.status);
    }

    console.error('Unhandled error:', err);
    return c.json({
        error: 'Internal server error',
        status: 500
    }, 500);
});

app.notFound((c) => {
    return c.json({
        error: 'Not found',
        status: 404
    }, 404);
});


app.post('/akademy-app/migrate', requireMinRoleLevel(95), strapiMigrationRoute);
app.post('/akademy-app/create-user', requireMinRoleLevel(30), createUserFromAgreement);
app.post('/akademy-app/reset-password', requireMinRoleLevel(1), resetUserPassword);
app.post('/akademy-app/deactivate-user', requireMinRoleLevel(50), deactivateUser);

Deno.serve(app.fetch);
