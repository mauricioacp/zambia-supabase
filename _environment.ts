import { createClient } from 'supabase';
import { loadSync } from '@std/dotenv';
import * as path from '@std/path';
import {Database} from "./types/supabase.type.ts";

const currentDir = path.dirname(path.fromFileUrl(import.meta.url));
const envFilePath = path.resolve(currentDir, '.env');
console.log(`Attempting to load .env file from: ${envFilePath}`);
loadSync({
	envPath: envFilePath,
	export: true,
});

export const SUPABASE_PROJECT_ID = Deno.env.get('SUPABASE_PROJECT_ID');
export const SUPABASE_DB_PASSWORD = Deno.env.get('SUPABASE_DB_PASSWORD');


export const SUPABASE_URL = Deno.env.get('SUPABASE_URL');
export const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get(
	'SUPABASE_SERVICE_ROLE_KEY',
);

export const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY');

export const TEST_USER_PASSWORD = Deno.env.get('TEST_USER_PASSWORD') ||
	'Test123!';
export const TEST_USER_EMAIL_PREFIX = Deno.env.get('TEST_USER_EMAIL_PREFIX') ||
	'test-user-';

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY || !SUPABASE_ANON_KEY) {
	console.error(
		'Error: SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY environment variables are required',
	);
	Deno.exit(1);
}

export const SUPA_CLIENT = createClient(
	SUPABASE_URL,
	SUPABASE_SERVICE_ROLE_KEY,
);

export const supabaseClient= createClient<Database>(
    SUPABASE_URL,
    SUPABASE_ANON_KEY,
);

export const EXTERNAL_KEY = Deno.env.get('EXTERNAL_KEY');
export const level95Token = Deno.env.get("level95");