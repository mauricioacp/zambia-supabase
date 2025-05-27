import { decodeBase64 } from "@std/encoding/base64";

/**
 * Extracts user role level from JWT token (mock implementation for testing)
 * In a real implementation, this would verify the JWT and extract the role level
 */
export function getUserRoleLevel(token: string): number | null {
  try {
    // Mock implementation for testing - in production this would verify JWT
    if (token === "mock-level-30-token") return 30;
    if (token === "mock-level-50-token") return 50;
    if (token === "mock-level-20-token") return 20;

    // For real JWT tokens, decode and verify
    // This is a simplified version - in production use a proper JWT library
    const parts = token.split(".");
    if (parts.length !== 3) return null;

    try {
      const payload = JSON.parse(
        new TextDecoder().decode(decodeBase64(parts[1])),
      );
      return payload.user_metadata?.role_level || null;
    } catch {
      return null;
    }
  } catch (error) {
    console.error("Error extracting role level from token:", error);
    return null;
  }
}

/**
 * Generates a cryptographically secure random password
 */
export function generatePassword(): string {
  const length = 12;
  const charset =
    "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*";
  const array = new Uint8Array(length);
  crypto.getRandomValues(array);

  return Array.from(array, (byte) => charset[byte % charset.length]).join("");
}
