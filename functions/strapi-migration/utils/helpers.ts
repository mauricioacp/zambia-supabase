/**
 * @param value
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
 * @param dateStr
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