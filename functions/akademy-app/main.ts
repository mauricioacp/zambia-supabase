import { serveDir } from "jsr:@std/http";
import { corsHeaders, handleCors } from "./middleware/cors.ts";
import { validateAdminAuth, validateSuperAdminJWT } from "./middleware/auth.ts";
import { handleError } from "./utils/error.ts";
import { staticPathPattern, adminPathPattern, userCreationPattern, superAdminCreationPattern } from "./config/routes.ts";
import { handleAdminRoute } from "./routes/admin/index.ts";
import { createUser } from "./routes/users.ts";
import { createSuperAdmin } from "./routes/super-admin.ts";
import { handleRootRoute } from "./routes/index.ts";

export default {
  async fetch(req: Request) {
    try {
      const url = new URL(req.url);
      const corsResponse = handleCors(req);
      if (corsResponse) return corsResponse;

      if (staticPathPattern.test(url)) {
        return serveDir(req);
      }

      const adminMatch = adminPathPattern.exec(url);
      if (adminMatch) {
        if (!validateAdminAuth(req)) {
          return new Response(JSON.stringify({ error: "Unauthorized" }), {
            status: 401,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          });
        }

        const resource = adminMatch.pathname.groups.resource;
        return handleAdminRoute(req, String(resource));
      }
      if (userCreationPattern.test(url) && req.method === "POST") {
        if (!validateAdminAuth(req)) {
          return new Response(JSON.stringify({ error: "Unauthorized" }), {
            status: 401,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          });
        }

        return createUser(req);
      }

      if (superAdminCreationPattern.test(url) && req.method === "POST") {
        const isValidJWT = await validateSuperAdminJWT(req);
        if (!isValidJWT) {
          return new Response(JSON.stringify({ error: "Unauthorized" }), {
            status: 401,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          });
        }

        return createSuperAdmin(req);
      }

      if (url.pathname === "/akademy-app") {
        return handleRootRoute();
      }

      return new Response(JSON.stringify({ error: "Not found" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    } catch (error) {
      return handleError(error);
    }
  },
} satisfies Deno.ServeDefaultExport;
