import { Context } from 'jsr:@hono/hono@4';
import { HTTPException } from 'jsr:@hono/hono@4/http-exception';
import { createClient, SupabaseClient } from 'jsr:@supabase/supabase-js@2';

import { fetchAllStrapiAgreements } from './strapiService.ts';
import { preloadLookupTable } from './supabaseService.ts';
import { StrapiAgreement } from './interfaces.ts';
import { matchData } from './mappingService.ts';
import {
	getLastSuccessfulMigrationTimestamp,
	recordMigration,
} from './migrationService.ts';

interface AppConfig {
	supabaseClient: SupabaseClient;
	strapiApiUrl: string;
	strapiToken: string;
}


const setupConfiguration = (authHeader: string): AppConfig => {
	const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
	const supabaseServiceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
	const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY')!;

	const strapiApiUrl = Deno.env.get('STRAPI_API_URL');
	const strapiToken = Deno.env.get('STRAPI_API_TOKEN');

	if (!strapiApiUrl || !strapiToken) {
		throw new Error(
			'Strapi API URL or Token environment variable is missing. These must be set via supabase secrets.',
		);
	}

	const supabaseKey = supabaseServiceRoleKey || supabaseAnonKey;
	const supabaseClient = createClient(supabaseUrl, supabaseKey, {
		global: {
			headers: { Authorization: `Bearer ${supabaseKey}` },
		},
		auth: {
			autoRefreshToken: false,
			persistSession: false,
		},
	});

	console.log('Environment variables loaded and Supabase client created.');
	console.log(`Using ${supabaseServiceRoleKey ? 'service role' : 'anon'} key for database operations.`);

	return {
		supabaseClient,
		strapiApiUrl,
		strapiToken,
	};
};

const connectToStrapi = async (
	strapiToken: string,
	strapiApiUrl: string,
	supabaseClient: SupabaseClient,
) => {
	const lastMigratedAt = await getLastSuccessfulMigrationTimestamp(
		supabaseClient,
	);
	console.log(
		`Last successful migration timestamp: ${
			lastMigratedAt || 'None (fetching all records)'
		}`,
	);

	const strapiAgreements: StrapiAgreement[] = await fetchAllStrapiAgreements(
		strapiApiUrl,
		strapiToken,
		'/api/acuerdo-akademias',
		lastMigratedAt,
	);

	const rolesSet = new Set<string>();
	const headquartersSet = new Set<string>();
	strapiAgreements.forEach((agreement) => {
		if (agreement.role) {
			rolesSet.add(agreement.role.trim().toLowerCase());
		}
		if (agreement.headQuarters) {
			headquartersSet.add(agreement.headQuarters.trim().toLowerCase());
		}
	});

	console.log(`Roles size in strapi: ${rolesSet.size}`);
	console.log(`Headquarters size in strapi: ${headquartersSet.size}`);
	return {
		rolesSet,
		headquartersSet,
		strapiAgreements,
	};
};

const preloadSupabaseTableRecords = async (supabaseClient: SupabaseClient) => {
	const [rolesMap, headquartersMap] = await Promise.all([
		preloadLookupTable(supabaseClient, 'roles', 'name'),
		preloadLookupTable(supabaseClient, 'headquarters', 'name'),
	]);
	return {
		rolesMap,
		headquartersMap,
	};
};

export async function strapiMigrationRoute(c: Context): Promise<Response> {
	try {

		const authHeader = c.req.header('Authorization');
		if (!authHeader) {
			throw new HTTPException(401, { 
				message: 'No autorizado'
			});
		}

		const { supabaseClient, strapiToken, strapiApiUrl } = setupConfiguration(authHeader);

		const { strapiAgreements, headquartersSet, rolesSet } = await connectToStrapi(
			strapiToken, 
			strapiApiUrl, 
			supabaseClient
		);

		const { rolesMap, headquartersMap } = await preloadSupabaseTableRecords(supabaseClient);

		const result = await matchData(
			strapiAgreements,
			headquartersSet,
			rolesSet,
			rolesMap,
			headquartersMap,
			supabaseClient,
		);

		console.log('Estadísticas de la migración:', result.statistics);

		if (result.success && strapiAgreements.length > 0) {
			const timestamps = strapiAgreements.map((a) =>
				new Date(a.updatedAt || a.createdAt).toISOString()
			);
			const mostRecentTimestamp = timestamps.sort().pop();

			if (mostRecentTimestamp) {
				const migrationRecord = {
					last_migrated_at: mostRecentTimestamp,
					status: 'success' as const,
					records_processed: result.statistics.supabaseInserted || 0,
				};

				const recordResult = await recordMigration(
					supabaseClient,
					migrationRecord,
				);
				console.log(
					'Migration record saved:',
					recordResult ? 'Success' : 'Failed',
				);
			}
		} else if (!result.success) {
			const migrationRecord = {
				last_migrated_at: new Date().toISOString(),
				status: 'failed' as const,
				records_processed: 0,
				error_message: result.error || 'Unknown error',
			};

			await recordMigration(supabaseClient, migrationRecord);
			console.log('Failed migration recorded');
		}

		return c.json(result, result.success ? 200 : 500);

	} catch (error) {
		if (error instanceof HTTPException) {
			throw error;
		}
		
		console.error('Migration error:', error);
		throw new HTTPException(500, { 
			message: error instanceof Error ? error.message : String(error)
		});
	}
}
