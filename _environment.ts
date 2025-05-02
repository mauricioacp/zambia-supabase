import { createClient } from 'supabase';
import { loadSync } from '@std/dotenv';
import * as path from '@std/path';

const currentDir = path.dirname(path.fromFileUrl(import.meta.url));
const envFilePath = path.resolve(currentDir, '.env');
console.log(`Attempting to load .env file from: ${envFilePath}`);
loadSync({
	envPath: envFilePath,
	export: true,
});

export const SUPABASE_URL = Deno.env.get('SUPABASE_URL');
export const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get(
	'SUPABASE_SERVICE_ROLE_KEY',
);
export const TEST_USER_PASSWORD = Deno.env.get('TEST_USER_PASSWORD') ||
	'Test123!';
export const TEST_USER_EMAIL_PREFIX = Deno.env.get('TEST_USER_EMAIL_PREFIX') ||
	'test-user-';

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
	console.error(
		'Error: SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY environment variables are required',
	);
	Deno.exit(1);
}

export const SUPA_CLIENT = createClient(
	SUPABASE_URL,
	SUPABASE_SERVICE_ROLE_KEY,
);
