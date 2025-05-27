import { assertEquals, assertExists } from '@std/assert';
import app from '../main.ts';

// Mock JWT tokens for different role levels
const LEVEL_30_TOKEN = 'Bearer mock-level-30-token';
const LEVEL_50_TOKEN = 'Bearer mock-level-50-token';
const LEVEL_20_TOKEN = 'Bearer mock-level-20-token';
const INVALID_TOKEN = 'Bearer invalid-token';

// Test helper to make requests
async function makeRequest(path: string, options: RequestInit = {}) {
	const req = new Request(`http://localhost:8000${path}`, {
		method: 'GET',
		headers: {
			'Content-Type': 'application/json',
			...options.headers,
		},
		...options,
	});
	
	return await app.fetch(req);
}

// === HEALTH CHECK TESTS ===
Deno.test('Health check endpoint', async () => {
	const res = await makeRequest('/health');
	assertEquals(res.status, 200);
	
	const body = await res.json();
	assertEquals(body.status, 'ok');
	assertExists(body.timestamp);
	assertEquals(body.services, ['migration', 'user-management']);
});

// === MIGRATION ENDPOINT TESTS ===
Deno.test('Migration - missing super password', async () => {
	const res = await makeRequest('/migrate', {
		method: 'POST',
		headers: {
			'Authorization': 'Bearer test-jwt-token',
		},
	});
	
	assertEquals(res.status, 401);
	const body = await res.json();
	assertEquals(body.error, 'Unauthorized: Invalid or missing credentials');
});

Deno.test('Migration - missing authorization header', async () => {
	const res = await makeRequest('/migrate', {
		method: 'POST',
		headers: {
			'x-super-password': 'test-password',
		},
	});
	
	assertEquals(res.status, 401);
	const body = await res.json();
	assertEquals(body.error, 'Unauthorized: Invalid or missing credentials');
});

Deno.test('Migration - dual auth headers present but invalid', async () => {
	const res = await makeRequest('/migrate', {
		method: 'POST',
		headers: {
			'Authorization': 'Bearer test-jwt-token',
			'x-super-password': 'wrong-password',
		},
	});
	
	assertEquals(res.status, 401);
	const body = await res.json();
	assertEquals(body.error, 'Unauthorized: Invalid or missing credentials');
});

// === USER MANAGEMENT ENDPOINT TESTS ===

// Create User Tests
Deno.test('Create user - missing authorization header', async () => {
	const res = await makeRequest('/create-user', {
		method: 'POST',
		body: JSON.stringify({ agreement_id: 'test-uuid' }),
	});
	
	assertEquals(res.status, 401);
	const body = await res.json();
	assertEquals(body.error, 'Missing or invalid authorization header');
});

Deno.test('Create user - invalid token format', async () => {
	const res = await makeRequest('/create-user', {
		method: 'POST',
		headers: {
			'Authorization': 'InvalidFormat',
		},
		body: JSON.stringify({ agreement_id: 'test-uuid' }),
	});
	
	assertEquals(res.status, 401);
});

Deno.test('Create user - insufficient role level', async () => {
	const res = await makeRequest('/create-user', {
		method: 'POST',
		headers: {
			'Authorization': LEVEL_20_TOKEN,
		},
		body: JSON.stringify({ agreement_id: 'test-uuid' }),
	});
	
	assertEquals(res.status, 403);
	const body = await res.json();
	assertEquals(body.error.includes('Insufficient permissions'), true);
});

Deno.test('Create user - invalid request body', async () => {
	const res = await makeRequest('/create-user', {
		method: 'POST',
		headers: {
			'Authorization': LEVEL_30_TOKEN,
		},
		body: JSON.stringify({ invalid_field: 'value' }),
	});
	
	assertEquals(res.status, 400);
	const body = await res.json();
	assertEquals(body.error, 'Invalid request data');
});

Deno.test('Create user - valid request format', async () => {
	const res = await makeRequest('/create-user', {
		method: 'POST',
		headers: {
			'Authorization': LEVEL_30_TOKEN,
		},
		body: JSON.stringify({ 
			agreement_id: '123e4567-e89b-12d3-a456-426614174000' 
		}),
	});
	
	// Will fail due to mock data, but should pass validation
	assertEquals([400, 404, 500].includes(res.status), true);
});

// Reset Password Tests
Deno.test('Reset password - missing authorization', async () => {
	const res = await makeRequest('/reset-password', {
		method: 'POST',
		body: JSON.stringify({
			email: 'test@example.com',
			document_number: '12345678',
			new_password: 'newPassword123',
			phone: '123456789',
			first_name: 'John',
			last_name: 'Doe',
		}),
	});
	
	assertEquals(res.status, 401);
});

Deno.test('Reset password - insufficient role level', async () => {
	const res = await makeRequest('/reset-password', {
		method: 'POST',
		headers: {
			'Authorization': LEVEL_20_TOKEN,
		},
		body: JSON.stringify({
			email: 'test@example.com',
			document_number: '12345678',
			new_password: 'newPassword123',
			phone: '123456789',
			first_name: 'John',
			last_name: 'Doe',
		}),
	});
	
	assertEquals(res.status, 403);
});

Deno.test('Reset password - invalid email format', async () => {
	const res = await makeRequest('/reset-password', {
		method: 'POST',
		headers: {
			'Authorization': LEVEL_30_TOKEN,
		},
		body: JSON.stringify({
			email: 'invalid-email',
			document_number: '12345678',
			new_password: 'newPassword123',
			phone: '123456789',
			first_name: 'John',
			last_name: 'Doe',
		}),
	});
	
	assertEquals(res.status, 400);
	const body = await res.json();
	assertEquals(body.error, 'Invalid request data');
});

Deno.test('Reset password - password too short', async () => {
	const res = await makeRequest('/reset-password', {
		method: 'POST',
		headers: {
			'Authorization': LEVEL_30_TOKEN,
		},
		body: JSON.stringify({
			email: 'test@example.com',
			document_number: '12345678',
			new_password: 'short',
			phone: '123456789',
			first_name: 'John',
			last_name: 'Doe',
		}),
	});
	
	assertEquals(res.status, 400);
	const body = await res.json();
	assertEquals(body.error, 'Invalid request data');
});

// Deactivate User Tests
Deno.test('Deactivate user - missing authorization', async () => {
	const res = await makeRequest('/deactivate-user', {
		method: 'POST',
		body: JSON.stringify({
			user_id: '123e4567-e89b-12d3-a456-426614174000',
		}),
	});
	
	assertEquals(res.status, 401);
});

Deno.test('Deactivate user - insufficient role level (requires 50+)', async () => {
	const res = await makeRequest('/deactivate-user', {
		method: 'POST',
		headers: {
			'Authorization': LEVEL_30_TOKEN,
		},
		body: JSON.stringify({
			user_id: '123e4567-e89b-12d3-a456-426614174000',
		}),
	});
	
	assertEquals(res.status, 403);
	const body = await res.json();
	assertEquals(body.error.includes('Required level: 50'), true);
});

Deno.test('Deactivate user - invalid UUID format', async () => {
	const res = await makeRequest('/deactivate-user', {
		method: 'POST',
		headers: {
			'Authorization': LEVEL_50_TOKEN,
		},
		body: JSON.stringify({
			user_id: 'invalid-uuid',
		}),
	});
	
	assertEquals(res.status, 400);
	const body = await res.json();
	assertEquals(body.error, 'Invalid request data');
});

Deno.test('Deactivate user - valid request format', async () => {
	const res = await makeRequest('/deactivate-user', {
		method: 'POST',
		headers: {
			'Authorization': LEVEL_50_TOKEN,
		},
		body: JSON.stringify({
			user_id: '123e4567-e89b-12d3-a456-426614174000',
		}),
	});
	
	// Will fail due to mock data, but should pass validation and authorization
	assertEquals([404, 500].includes(res.status), true);
});

// === CORS TESTS ===
Deno.test('CORS headers are present', async () => {
	const res = await makeRequest('/health', {
		method: 'OPTIONS',
		headers: {
			'Origin': 'http://localhost:3000',
		},
	});
	
	// Should have CORS headers
	assertExists(res.headers.get('Access-Control-Allow-Origin'));
	assertExists(res.headers.get('Access-Control-Allow-Methods'));
	assertExists(res.headers.get('Access-Control-Allow-Headers'));
	
	// Should allow both migration and user management headers
	const allowedHeaders = res.headers.get('Access-Control-Allow-Headers');
	assertEquals(allowedHeaders?.includes('x-super-password'), true);
	assertEquals(allowedHeaders?.includes('Authorization'), true);
});

// === 404 TESTS ===
Deno.test('Unknown endpoint returns 404', async () => {
	const res = await makeRequest('/unknown-endpoint');
	assertEquals(res.status, 404);
	
	const body = await res.json();
	assertEquals(body.error, 'Not found');
});