import { Context, Next } from "hono";
import { HTTPException } from "hono/http-exception";
import { CONSTANTS } from "../utils/constants.ts";

/**
 * Middleware to validate request size and basic security checks
 */
export function requestValidationMiddleware() {
  return async (c: Context, next: Next) => {
    // Check request size
    const contentLength = c.req.header("content-length");
    if (
      contentLength &&
      parseInt(contentLength) > CONSTANTS.MAX_REQUEST_SIZE_MB * 1024 * 1024
    ) {
      throw new HTTPException(413, {
        message: "Request too large",
      });
    }

    // Add correlation ID for request tracking
    const correlationId = crypto.randomUUID();
    c.set("correlationId", correlationId);
    c.res.headers.set("x-correlation-id", correlationId);

    await next();
  };
}

/**
 * Middleware to add security headers
 */
export function securityHeadersMiddleware() {
  return async (c: Context, next: Next) => {
    await next();

    // Add security headers
    c.res.headers.set("x-content-type-options", "nosniff");
    c.res.headers.set("x-frame-options", "DENY");
    c.res.headers.set("x-xss-protection", "1; mode=block");
    c.res.headers.set("referrer-policy", "strict-origin-when-cross-origin");
  };
}
