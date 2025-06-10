import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { HTTPException } from 'hono/http-exception';
import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { strapiMigrationRoute } from "./routes/migration.ts";
import { createUserFromAgreement } from "./routes/create-user.ts";
import { resetUserPassword } from "./routes/reset-password.ts";
import { deactivateUser } from "./routes/deactivate-user.ts";
import { 
	searchUsers, 
	sendNotification, 
	sendRoleNotification, 
	getNotifications, 
	getUnreadCount, 
	markNotificationsRead, 
	archiveNotification,
	getNotificationPreferences,
	updateNotificationPreferences 
} from "./routes/notifications.ts";
import { requireMinRoleLevel } from "./middleware/auth.ts";

export const app = new Hono();

// Enable CORS with specific origins for production
app.use('*', cors({
    origin: (origin) => {
        // Allow specific production domains and localhost for development
        const allowedOrigins = [
            'https://app.laakademia.digital',
            'https://laakademia.digital',
            'http://localhost:4200',
            'http://localhost:3000',
            'http://127.0.0.1:4200',
            'http://127.0.0.1:3000'
        ];
        
        if (!origin || allowedOrigins.includes(origin)) {
            return origin || '*';
        }
        
        // Allow any origin in development
        if (Deno.env.get('ENVIRONMENT') === 'development') {
            return '*';
        }
        
        return null;
    },
    allowHeaders: ['Content-Type', 'Authorization', 'x-client-info', 'apikey', 'X-Requested-With'],
    allowMethods: ['GET', 'POST', 'OPTIONS', 'PUT', 'DELETE'],
    credentials: true,
    exposeHeaders: ['Content-Length', 'X-JSON'],
    maxAge: 86400,
}));

// Handle OPTIONS requests explicitly for all routes
app.options('*', (c) => {
    return c.text('', 204);
});

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


app.get('/akademy-app/users/search', requireMinRoleLevel(1), searchUsers);
app.post('/akademy-app/notifications/send', requireMinRoleLevel(1), sendNotification);
app.post('/akademy-app/notifications/send-role', requireMinRoleLevel(50), sendRoleNotification);
app.get('/akademy-app/notifications', requireMinRoleLevel(1), getNotifications);
app.get('/akademy-app/notifications/unread-count', requireMinRoleLevel(1), getUnreadCount);
app.post('/akademy-app/notifications/mark-read', requireMinRoleLevel(1), markNotificationsRead);
app.post('/akademy-app/notifications/:id/archive', requireMinRoleLevel(1), archiveNotification);
app.get('/akademy-app/notifications/preferences', requireMinRoleLevel(1), getNotificationPreferences);
app.put('/akademy-app/notifications/preferences', requireMinRoleLevel(1), updateNotificationPreferences);

Deno.serve(app.fetch);
