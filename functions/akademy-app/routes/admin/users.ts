import { corsHeaders } from "../../middleware/cors.ts";
import { supabaseAdmin } from "../../services/supabase.ts";

export async function getUsers() {
  const { data: { users }, error: usersError } = await supabaseAdmin.auth.admin.listUsers();

  if (usersError) throw usersError;

  return new Response(JSON.stringify({ data: users }), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}