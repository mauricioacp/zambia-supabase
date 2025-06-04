import { createClient } from 'supabase';


export const ANON_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
export const URL = Deno.env.get('SUPABASE_URL');

export const client = createClient(
    URL,
    ANON_KEY,
);
