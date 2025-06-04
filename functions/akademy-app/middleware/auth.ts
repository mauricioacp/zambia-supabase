import { Context, Next } from "hono";
import { HTTPException } from "hono/http-exception";
import { getUserRoleLevel } from "../utils/auth.ts";

/**
 * Middleware to verify JWT token and minimum role level
 */
export function requireMinRoleLevel(minLevel: number) {
  return async (c: Context, next: Next) => {

    const userLevel = getUserRoleLevel(token);

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

    // Store user level in context for later use
    c.set("userLevel", userLevel);
    await next();
  };
}
