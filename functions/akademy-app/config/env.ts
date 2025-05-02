export const SUPABASE_URL = Deno.env.get('SUPABASE_URL') || '';
export const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY') || '';
export const SUPABASE_SERVICE_ROLE_KEY =
	Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || '';
export const ADMIN_SECRET = Deno.env.get('ADMIN_SECRET') || '';
export const SUPER_ADMIN_JWT_SECRET = Deno.env.get('SUPER_ADMIN_JWT_SECRET') ||
	'';
