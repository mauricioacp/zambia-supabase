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

    // Consider chunking inserts if agreements.length is very large (e.g., > 1000)
    // const chunkSize = 500;
    // let totalInserted = 0;
    // for (let i = 0; i < agreements.length; i += chunkSize) {
    //    const chunk = agreements.slice(i, i + chunkSize);
    //    const { error, count } = await supabaseClient...insert(chunk)...
    //    // handle error, aggregate count
    // }

    const { error, count } = await supabaseClient
        .from('agreements')
        .insert(agreements)
        // .upsert(agreements, { onConflict: 'email, season_id' }) // Example: Use upsert if you need to update existing records
        .select({ count: 'exact' }); // Request the count of affected rows

    if (error) {
        console.error('Supabase insert error:', error);
        // Detailed logging of the first few failing records might be helpful
        // console.error('First few records in failed batch:', JSON.stringify(agreements.slice(0, 5), null, 2));
        return { count: null, error }; // Return the error object
    }

    console.log(`Supabase insert successful. Response count: ${count ?? 'unknown'}.`);
    // Note: 'count' might be null even on success in some scenarios,
    // or reflect the total rows matched in an upsert, not just inserted.
    // The actual number inserted might differ if using upsert or if RLS prevents some inserts.
    return { count, error: null };
}