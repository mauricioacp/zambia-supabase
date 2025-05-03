import { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2.39.8';

export interface MigrationRecord {
	id?: number;
	migration_timestamp?: string;
	last_migrated_at: string;
	status: 'success' | 'failed';
	records_processed: number;
	error_message?: string;
	created_at?: string;
}

/**
 * @param supabaseClient
 * @returns
 */
export async function getLastSuccessfulMigrationTimestamp(
	supabaseClient: SupabaseClient,
): Promise<string | null> {
	try {
		const { data, error } = await supabaseClient
			.from('strapi_migrations')
			.select('last_migrated_at')
			.eq('status', 'success')
			.order('migration_timestamp', { ascending: false })
			.limit(1);

		if (error) {
			console.error('Error fetching last migration timestamp:', error);
			return null;
		}

		return data && data.length > 0 ? data[0].last_migrated_at : null;
	} catch (error) {
		console.error('Exception fetching last migration timestamp:', error);
		return null;
	}
}

/**
 * @param supabaseClient
 * @param migrationRecord
 * @returns
 */
export async function recordMigration(
	supabaseClient: SupabaseClient,
	migrationRecord: MigrationRecord,
): Promise<MigrationRecord | null> {
	try {
		const { data, error } = await supabaseClient
			.from('strapi_migrations')
			.insert(migrationRecord)
			.select()
			.single();

		if (error) {
			console.error('Error recording migration:', error);
			return null;
		}

		return data;
	} catch (error) {
		console.error('Exception recording migration:', error);
		return null;
	}
}
