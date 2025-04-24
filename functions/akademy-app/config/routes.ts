// URL patterns for routing
export const staticPathPattern = new URLPattern({ pathname: "/static/*" });
export const adminPathPattern = new URLPattern({ pathname: "/akademy-app/admin/:resource" });
export const userCreationPattern = new URLPattern({ pathname: "/akademy-app/users" });
export const superAdminCreationPattern = new URLPattern({ pathname: "/akademy-app/super-admin" });