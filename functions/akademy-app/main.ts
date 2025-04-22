import { serveDir } from "jsr:@std/http";
import { corsHeaders, handleCors } from "./middleware/cors.ts";
import { validateAdminAuth, validateSuperAdminJWT } from "./middleware/auth.ts";
import { handleError } from "./utils/error.ts";
import { staticPathPattern, adminPathPattern, userCreationPattern, superAdminCreationPattern } from "./config/routes.ts";
import { handleAdminRoute } from "./routes/admin/index.ts";
import { createUser } from "./routes/users.ts";
import { createSuperAdmin } from "./routes/super-admin.ts";
import { handleRootRoute } from "./routes/index.ts";

// Main handler function
export default {
  async fetch(req: Request) {
    try {
      const url = new URL(req.url);

      // Handle CORS preflight requests
      const corsResponse = handleCors(req);
      if (corsResponse) return corsResponse;

      // Serve static files
      if (staticPathPattern.test(url)) {
        return serveDir(req);
      }

      // Handle admin routes
      const adminMatch = adminPathPattern.exec(url);
      if (adminMatch) {
        // Validate admin authentication
        if (!validateAdminAuth(req)) {
          return new Response(JSON.stringify({ error: "Unauthorized" }), {
            status: 401,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          });
        }

        const resource = adminMatch.pathname.groups.resource;
        return handleAdminRoute(req, resource);
      }

      // Handle user creation
      if (userCreationPattern.test(url) && req.method === "POST") {
        // Validate admin authentication
        if (!validateAdminAuth(req)) {
          return new Response(JSON.stringify({ error: "Unauthorized" }), {
            status: 401,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          });
        }

        return createUser(req);
      }

      // Handle super admin creation
      if (superAdminCreationPattern.test(url) && req.method === "POST") {
        // Validate super admin JWT
        const isValidJWT = await validateSuperAdminJWT(req);
        if (!isValidJWT) {
          return new Response(JSON.stringify({ error: "Unauthorized" }), {
            status: 401,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          });
        }

        return createSuperAdmin(req);
      }

      // Handle root endpoint
      if (url.pathname === "/akademy-app") {
        return handleRootRoute();
      }

      // Handle 404 for unknown routes
      return new Response(JSON.stringify({ error: "Not found" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    } catch (error) {
      return handleError(error);
    }
  },
} satisfies Deno.ServeDefaultExport;
