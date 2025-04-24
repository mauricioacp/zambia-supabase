import { corsHeaders } from "../middleware/cors.ts";

// Handle root endpoint
export function handleRootRoute() {
  return new Response(JSON.stringify({ message: "Akademy App API" }), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}