import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { HTTPException } from 'hono/http-exception';
import 'jsr:@supabase/functions-js/edge-runtime.d.ts';

// Migration routes
import { strapiMigrationRoute } from './routes/migration.ts';

// User management routes  
import { requireMinRoleLevel } from './middleware/auth.ts';
import { createUserFromAgreement } from './routes/create-user.ts';
import { resetUserPassword } from './routes/reset-password.ts';
import { deactivateUser } from './routes/deactivate-user.ts';

const app = new Hono();

// CORS middleware
app.use('*', cors({
	origin: ['http://localhost:3000', 'https://*.supabase.co'],
	allowMethods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
	allowHeaders: ['Content-Type', 'Authorization', 'x-super-password'],
	credentials: true,
}));

// Health check endpoint
app.get('/akademy/health', (c) => {
	return c.json({ 
		status: 'ok', 
		timestamp: new Date().toISOString(),
		services: ['migration', 'user-management']
	});
});

// Root endpoint for testing
app.get('/akademy/', (c) => {
	return c.json({ 
		status: 'ok', 
		message: 'Akademy API is running',
		timestamp: new Date().toISOString(),
		endpoints: ['/health', '/migrate', '/create-user', '/reset-password', '/deactivate-user']
	});
});

app.get('/akademy', (c) => {
	return c.json({ 
		status: 'ok', 
		message: 'Akademy API is running',
		timestamp: new Date().toISOString(),
		endpoints: ['/health', '/migrate', '/create-user', '/reset-password', '/deactivate-user']
	});
});

// OPTIONS handler for preflight requests
app.options('*', (c) => {
	return new Response('', { status: 204 });
});

// === ROUTES ===
// Routes temporarily disabled to test basic functionality
// TODO: Re-enable after fixing import issues

// Error handler
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

// === MIGRATION ROUTES ===
// Main migration endpoint - preserves original strapi-migration functionality
app.post('/akademy/migrate', strapiMigrationRoute);

// === USER MANAGEMENT ROUTES ===
// Create user from agreement endpoint (requires role level 30+)
app.post('/akademy/create-user', requireMinRoleLevel(30), createUserFromAgreement);

// Reset password endpoint (requires role level 30+)
app.post('/akademy/reset-password', requireMinRoleLevel(30), resetUserPassword);

// Deactivate user endpoint (requires role level 50+)
app.post('/akademy/deactivate-user', requireMinRoleLevel(50), deactivateUser);

// 404 handler
app.notFound((c) => {
	return c.json({ 
		error: 'Not found',
		status: 404 
	}, 404);
});

// Serve the app
Deno.serve(app.fetch);