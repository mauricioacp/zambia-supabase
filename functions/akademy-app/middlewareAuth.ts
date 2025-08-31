import { Context, Next } from 'jsr:@hono/hono@4';
import { HTTPException } from 'jsr:@hono/hono@4/http-exception';
import { getUserRoleLevel } from "./auth.ts";

export function requireMinRoleLevel(minLevel: number) {
  return async (c: Context, next: Next) => {
    if (c.req.method === 'OPTIONS') {
      await next();
      return;
    }

    const authHeader = c.req.header('Authorization');
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      throw new HTTPException(401, {
        message: "Missing or invalid Authorization header",
      });
    }

    const token = authHeader.substring(7); // Remove 'Bearer ' prefix
    const metadata = await getUserRoleLevel(token);

    if (metadata.role_level === null) {
      throw new HTTPException(401, {
        message: "Invalid token or user not found",
      });
    }

    if (metadata.role_level < minLevel) {
      throw new HTTPException(403, {
        message:
          `Insufficient permissions. Required level: ${minLevel}, your level: ${userLevel}`,
      });
    }

    c.set("userLevel", metadata.role_level);
    c.set("userMetadata", metadata);
    c.set("userToken", token);
    await next();
  };
}
