import { ADMIN_SECRET, SUPER_ADMIN_JWT_SECRET } from "../config/env.ts";

// Helper function to validate admin authentication
export function validateAdminAuth(req: Request): boolean {
  const adminHeader = req.headers.get("admin");
  return adminHeader === ADMIN_SECRET;
}

// Helper function to validate super admin JWT
export async function validateSuperAdminJWT(req: Request): Promise<boolean> {
  const authHeader = req.headers.get("authorization");
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return false;
  }

  const token = authHeader.split(" ")[1];
  return token === SUPER_ADMIN_JWT_SECRET;
}