// Purpose: General utility functions
/**
 * Helper utility functions for the migration process
 */

/**
 * Safely parses a boolean value, handling various formats
 * @param value The value to convert to boolean
 * @returns The parsed boolean value or null
 */
export function parseBoolean(value: any): boolean | null {
  if (value === undefined || value === null) return null;
  
  if (typeof value === 'boolean') return value;
  
  if (typeof value === 'string') {
    const normalized = value.trim().toLowerCase();
    if (normalized === 'true' || normalized === 'yes' || normalized === '1') return true;
    if (normalized === 'false' || normalized === 'no' || normalized === '0') return false;
  }
  
  if (typeof value === 'number') {
    return value !== 0;
  }
  
  return null;
}

/**
 * Formats a date string to ISO format for Supabase timestamp columns
 * @param dateStr The date string to format
 * @returns ISO formatted date string or null
 */
export function formatIsoDate(dateStr: string | undefined | null): string | null {
  if (!dateStr) return null;
  
  try {
    const date = new Date(dateStr);
    if (isNaN(date.getTime())) return null;
    return date.toISOString();
  } catch (error) {
    console.warn(`Failed to parse date: ${dateStr}`, error);
    return null;
  }
}

/**
 * Creates a map for quick lookup, with normalized keys (lowercase, trimmed)
 * @param sourceMap Original map to normalize
 * @returns New map with normalized keys
 */
export function createNormalizedMap<T>(sourceMap: Map<string, T>): Map<string, T> {
  const normalizedMap = new Map<string, T>();
  for (const [key, value] of sourceMap.entries()) {
    if (key) {
      normalizedMap.set(key.trim().toLowerCase(), value);
    }
  }
  return normalizedMap;
}
/**
 * Parses a value (boolean, string, null) into a boolean or null.
 * Treats 'true' (case-insensitive) as true.
 * @param value The value to parse.
 * @returns boolean | null
 */
export function parseBoolean(value: boolean | string | null | undefined): boolean | null {
    if (typeof value === 'boolean') return value;
    if (typeof value === 'string') return value.trim().toLowerCase() === 'true';
    // Decide default: null is safer if unsure, false might be required by schema
    return null;
}

/**
 * Safely formats a date string into ISO 8601 format or returns null.
 * @param dateString The date string to format.
 * @returns string | null
 */
export function formatIsoDate(dateString: string | null | undefined): string | null {
    if (!dateString) return null;
    try {
        return new Date(dateString).toISOString();
    } catch (e) {
        console.warn(`Invalid date format encountered: ${dateString}`);
        return null; // Or handle error differently
    }
}