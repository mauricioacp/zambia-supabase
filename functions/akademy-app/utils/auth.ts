import {client} from "../_environment.ts";

export function getUserRoleLevel(): number | null {
  try {

      const {
          data: { user },
      } = await client.auth.getUser()
      let metadata = user.user_metadata

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
