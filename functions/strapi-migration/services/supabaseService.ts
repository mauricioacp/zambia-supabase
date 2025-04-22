import { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2.39.8';
import { SupabaseLookupItem } from '../interfaces.ts';

/**
 * @param supabaseClient
 * @param tableName
 * @param nameColumn
 * @returns Promise<Map<string, string>>
 */
export async function preloadLookupTable(
    supabaseClient: SupabaseClient,
    tableName: string,
    nameColumn: string = 'name'
): Promise<Map<string, string>> {
    const { data, error } = await supabaseClient
        .from(tableName)
        .select(`id, ${nameColumn}`)
        .order(`${nameColumn}`)

    if (error) {
        console.error(`Error pre-loading ${tableName}:`, error);
        throw error;
    }

    const map = new Map<string, string>();
    (data as unknown as SupabaseLookupItem[] | null)?.forEach(item => {
        if (item.name) {
            map.set(item.name.trim().toLowerCase(), item.id);
        } else {
             console.warn(`Item in ${tableName} table with ID ${item.id} has a null or missing '${nameColumn}'. Skipping.`);
        }
    });
    return map;
}


export async function getSeasonIdByHeadQuarterId(headquarterId: string, supabaseClient: SupabaseClient) {

    const {data, error} = await supabaseClient
        .from('seasons')
        .select('id')
        .eq('headquarter_id', headquarterId)
        .single();

    if (error) {
        console.error(`Error getting season id by headquarter id:`, error);
        throw error;
    }

    return data?.id;
}