import { corsHeaders } from "../middleware/cors.ts";

export function handleRootRoute() {
  return new Response(JSON.stringify({ message: "Akademy App API" }), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}