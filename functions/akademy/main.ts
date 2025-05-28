import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { HTTPException } from 'hono/http-exception';
import 'jsr:@supabase/functions-js/edge-runtime.d.ts';

import { strapiMigrationRoute } from './routes/migration.ts';

import { requireMinRoleLevel } from './middleware/auth.ts';
import { createUserFromAgreement } from './routes/create-user.ts';
import { resetUserPassword } from './routes/reset-password.ts';
import { deactivateUser } from './routes/deactivate-user.ts';

const app = new Hono();

app.use('*', cors({
	origin: ['http://localhost:3000', 'https://*.supabase.co'],
	allowMethods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
	allowHeaders: ['Content-Type', 'Authorization', 'x-super-password'],
	credentials: true,
}));

app.get('/akademy/health', (c) => {
	return c.json({ 
		status: 'ok', 
		timestamp: new Date().toISOString(),
		services: ['migration', 'user-management']
	});
});

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

app.options('*', (_c) => {
	return new Response('', { status: 204 });
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

app.post('/akademy/migrate', strapiMigrationRoute);
app.post('/akademy/create-user', requireMinRoleLevel(30), createUserFromAgreement);
app.post('/akademy/reset-password', requireMinRoleLevel(30), resetUserPassword);
app.post('/akademy/deactivate-user', requireMinRoleLevel(50), deactivateUser);

app.notFound((c) => {
	return c.json({ 
		error: 'Not found',
		status: 404 
	}, 404);
});

Deno.serve(app.fetch);
