/**
 * Utility functions for mapping string values to their corresponding Supabase IDs
 */

/**
 * Maps a role name to its corresponding ID in Supabase
 * @param roleName The name of the role to map
 * @param rolesMap Map of role names to IDs
 * @param unmappedRoles Set to collect unmapped roles
 * @returns The UUID of the mapped role or null if not found
 */
export function mapRoleToId(
  roleName: string | null | undefined,
  rolesMap: Map<string, string>,
  unmappedRoles: Set<string>
): string | null {
  if (!roleName) return null;
  
  const normalizedRole = roleName.trim().toLowerCase();
  
  // Known mappings for roles
  const roleAliases = new Map<string, string>([
    ["equipo de comunicación", "comunicacion"],
    ["miembro del konsejo de dirección", "konsejo_direccion"],
    ["director/a local", "director_local"],
    ["facilitador", "facilitador"],
    ["alumno", "alumno"],
    ["acompañante", "acompañante"],
    ["otro", "otro"]
  ]);
  
  // Check if we have a defined alias
  const mappedAlias = roleAliases.get(normalizedRole);
  if (mappedAlias && rolesMap.has(mappedAlias)) {
    return rolesMap.get(mappedAlias) || null;
  }
  
  // Direct lookup
  const roleId = rolesMap.get(normalizedRole);
  if (roleId) {
    return roleId;
  }
  
  // If we couldn't map it, add to unmapped set
  unmappedRoles.add(normalizedRole);
  return null;
}

/**
 * Maps a headquarters name to its corresponding ID in Supabase
 * @param hqName The name of the headquarters to map
 * @param headquartersMap Map of headquarters names to IDs
 * @param unmappedHeadquarters Set to collect unmapped headquarters
 * @returns The UUID of the mapped headquarters or null if not found
 */
export function mapHeadquarterToId(
  hqName: string | null | undefined,
  headquartersMap: Map<string, string>,
  unmappedHeadquarters: Set<string>
): string | null {
  if (!hqName) return null;
  
  const normalizedHq = hqName.trim().toLowerCase();
  
  // Known mappings/normalizations for headquarters names
  const hqAliases = new Map<string, string>([
    ["ciudad de méxico", "cdmx"],
    ["donostia/san sebastián", "donostia"],
    ["valencia ruzafa/ribera alta", "valencia"],
    ["valencia catarroja", "valencia"],
    ["valencia nómada upv", "valencia"],
    ["general pico, la pampa", "la_pampa"],
    ["mar de plata", "mar_del_plata"]
  ]);
  
  // Check if we have a defined alias
  const mappedAlias = hqAliases.get(normalizedHq);
  if (mappedAlias && headquartersMap.has(mappedAlias)) {
    return headquartersMap.get(mappedAlias) || null;
  }
  
  // Direct lookup
  const hqId = headquartersMap.get(normalizedHq);
  if (hqId) {
    return hqId;
  }
  
  // If we couldn't map it, add to unmapped set
  unmappedHeadquarters.add(normalizedHq);
  return null;
}
