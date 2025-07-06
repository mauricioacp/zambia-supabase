import { Hono } from 'jsr:@hono/hono@4';
import { cors } from 'jsr:@hono/hono@4/cors';
import { HTTPException } from 'jsr:@hono/hono@4/http-exception';
import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { strapiMigrationRoute } from "./migration.ts";
import { createUserFromAgreement } from "./create-user.ts";
import { resetUserPassword } from "./reset-password.ts";
import { deactivateUser } from "./deactivate-user.ts";
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
} from "./notifications.ts";
import { requireMinRoleLevel } from "./middlewareAuth.ts";

export const app = new Hono();

const allowedOrigins = '*';

app.use('*', cors({
    origin: allowedOrigins,
    allowHeaders: ['Content-Type', 'Authorization', 'x-client-info', 'apikey', 'X-Requested-With'],
    allowMethods: ['GET', 'POST', 'OPTIONS', 'PUT', 'DELETE'],
    credentials: true,
    exposeHeaders: ['Content-Length', 'X-JSON'],
    maxAge: 86400,
}));

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
