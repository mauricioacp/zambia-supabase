import { createClient } from '@supabase/supabase-js';

export async function getUserRoleLevel(token: string): Promise<number | null> {
  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY');
    
    if (!supabaseUrl || !supabaseAnonKey) {
      console.error('Missing Supabase environment variables');
      return null;
    }

    // Create a client with the user's token
    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      global: {
        headers: {
          Authorization: `Bearer ${token}`
        }
      }
    });

    const {
      data: { user },
      error
    } = await supabase.auth.getUser(token);
    
    if (error || !user) {
      console.error("Error getting user:", error);
      return null;
    }

    console.log("User ID:", user.id);
    console.log("User metadata:", user.user_metadata);

    const metadata = user.user_metadata;

    if (!metadata || typeof metadata.role_level !== 'number') {
      console.error("No role_level in user metadata:", metadata);
      return null;
    }

    console.log("User role level:", metadata.role_level);
    return metadata.role_level as number;

  } catch (error) {
    console.error("Error extracting role level from token:", error);
    return null;
  }
}

/**
 * Generates a cryptographically secure random password
 */
export function generatePassword(): string {
  const length = 12;
  const charset =
    "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*";
  const array = new Uint8Array(length);
  crypto.getRandomValues(array);

  return Array.from(array, (byte) => charset[byte % charset.length]).join("");
}
