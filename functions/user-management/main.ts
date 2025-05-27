import { Hono } from 'hono';
import { cors } from 'hono/cors'
import { HTTPException } from 'hono/http-exception';
import { requireMinRoleLevel } from './middleware/auth.ts';
import { createUserFromAgreement } from './routes/create-user.ts';
import { resetUserPassword } from './routes/reset-password.ts';
import { deactivateUser } from './routes/deactivate-user.ts';

const app = new Hono();

// CORS middleware
app.use('*', cors({
	origin: ['http://localhost:3000', 'https://*.supabase.co'],
	allowMethods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
	allowHeaders: ['Content-Type', 'Authorization'],
	credentials: true,
}));

// Health check endpoint
app.get('/health', (c) => {
	return c.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// OPTIONS handler for preflight requests
app.options('*', (c) => {
	return new Response('', { status: 204 });
});

// Create user from agreement endpoint (requires role level 30+)
app.post('/create-user', requireMinRoleLevel(30), createUserFromAgreement);

// Reset password endpoint (requires role level 30+)
app.post('/reset-password', requireMinRoleLevel(30), resetUserPassword);

// Deactivate user endpoint (requires role level 50+)
app.post('/deactivate-user', requireMinRoleLevel(50), deactivateUser);

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

// 404 handler
app.notFound((c) => {
	return c.json({ 
		error: 'Not found',
		status: 404 
	}, 404);
});

export default app;
