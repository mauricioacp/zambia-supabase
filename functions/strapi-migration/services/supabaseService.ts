import { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2.39.8';
import { SupabaseAgreement, SupabaseLookupItem } from '../interfaces.ts';

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

    console.log(`Finished pre-loading ${tableName}. ${map.size} items mapped.`);
    return map;
}


/**
 * @param supabaseClient
 * @param agreements
 * @returns Promise<{ count: number | null; error: Error | null }>
 */
export async function insertAgreementsBatch(
    supabaseClient: SupabaseClient,
    agreements: SupabaseAgreement[]
): Promise<{ count: number | null; error: unknown | null }> {

    if (!agreements || agreements.length === 0) {
        console.log("No records to insert into Supabase.");
        return { count: 0, error: null };
    }

    console.log(`Inserting ${agreements.length} records into Supabase table 'agreements'...`);

    const { error, count } = await supabaseClient
        .from('agreements')
        .insert(agreements)

    if (error) {
        console.error('Supabase insert error:', error);
        return { count: null, error };
    }

    console.log(`Supabase insert successful. Response count: ${count ?? 'unknown'}.`);
    return { count, error: null };
}