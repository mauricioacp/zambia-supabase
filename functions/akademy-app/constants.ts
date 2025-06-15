/**
 * Application constants
 */
export const CONSTANTS = {
  // User management
  BAN_DURATION_YEARS: 100,
  PASSWORD_MIN_LENGTH: 8,
  PASSWORD_MAX_LENGTH: 128,

  // Migration
  BATCH_SIZE: 50,
  MAX_RETRY_ATTEMPTS: 3,
  RETRY_DELAY_MS: 1000,

  // Security
  MAX_REQUEST_SIZE_MB: 1,
  RATE_LIMIT_REQUESTS_PER_MINUTE: 100,

  // Error messages
  ERROR_MESSAGES: {
    UNAUTHORIZED: "Unauthorized access",
    INVALID_DATA: "Invalid request data",
    USER_NOT_FOUND: "User not found",
    AGREEMENT_NOT_FOUND: "Agreement not found or already activated",
    INSUFFICIENT_PERMISSIONS: "Insufficient permissions",
    MIGRATION_FAILED: "Migration process failed",
    INTERNAL_ERROR: "Internal server error",
  } as const,
} as const;
