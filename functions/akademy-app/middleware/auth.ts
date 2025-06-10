import { Context, Next } from "hono";
import { HTTPException } from "hono/http-exception";
import { getUserRoleLevel } from "../utils/auth.ts";

export function requireMinRoleLevel(minLevel: number) {
  return async (c: Context, next: Next) => {
    // Skip authentication for OPTIONS requests (CORS preflight)
    if (c.req.method === 'OPTIONS') {
      await next();
      return;
    }

    // Get the Authorization header
    const authHeader = c.req.header('Authorization');
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      throw new HTTPException(401, {
        message: "Missing or invalid Authorization header",
      });
    }

    const token = authHeader.substring(7); // Remove 'Bearer ' prefix
    const userLevel = await getUserRoleLevel(token);

    if (userLevel === null) {
      throw new HTTPException(401, {
        message: "Invalid token or user not found",
      });
    }

    if (userLevel < minLevel) {
      throw new HTTPException(403, {
        message:
          `Insufficient permissions. Required level: ${minLevel}, your level: ${userLevel}`,
      });
    }

    c.set("userLevel", userLevel);
    c.set("userToken", token); // Store token for later use
    await next();
  };
}
