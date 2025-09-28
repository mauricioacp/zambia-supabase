import { Context, Next } from "jsr:@hono/hono@4";
import { HTTPException } from "jsr:@hono/hono@4/http-exception";
import {getUserMiddleware} from "./auth.ts";

export function requireMinRoleLevel(minLevel: number) {
  return async (c: Context, next: Next) => {
    if (c.req.method === "OPTIONS") {
      await next();
      return;
    }

    const authHeader = c.req.header("Authorization");

    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      throw new HTTPException(401, {
        message: "Missing or invalid Authorization header",
      });
    }

    const token = authHeader.substring(7);
    const {user} = await getUserMiddleware(token);

    if (!user?.user_metadata?.role_level) {
      throw new HTTPException(401, {
        message: "Invalid token or user not found",
      });
    }

    if (user.user_metadata.role_level < minLevel) {
      throw new HTTPException(403, {
        message:
          `Insufficient permissions`,
      });
    }

    c.set("userLevel", user.user_metadata.role_level);
    c.set("user", user);
    c.set("userMetadata", user.user_metadata);
    c.set("userToken", token);
    await next();
  };
}
