import {
	createClient,
	SupabaseClient,
} from 'https://esm.sh/@supabase/supabase-js@2.39.8';
import 'jsr:@supabase/functions-js/edge-runtime.d.ts';
import { corsHeaders } from '../_shared/cors.ts';
import { fetchAllStrapiAgreements } from './services/strapiService.ts';
import { preloadLookupTable } from './services/supabaseService.ts';
import { StrapiAgreement } from './interfaces.ts';
import 'jsr:@std/dotenv/load';
import { matchData } from './services/mappingService.ts';
import {
	getLastSuccessfulMigrationTimestamp,
	recordMigration,
} from './services/migrationService.ts';
import { timingSafeEqual } from "@std/crypto/timing-safe-equal";


interface AppConfig {
	supabaseClient: SupabaseClient;
	strapiApiUrl: string;
	strapiToken: string;
}

const verifyPassword = (password: string): boolean => {
	const superPassword = Deno.env.get('SUPER_PASSWORD');
    console.log(superPassword)

	if (!superPassword) {
		console.error('SUPER_PASSWORD environment variable is not set');
		return false;
	}

	const providedPasswordBytes = new TextEncoder().encode(password);
	const storedPasswordBytes = new TextEncoder().encode(superPassword);

	if (providedPasswordBytes.length !== storedPasswordBytes.length) {
		const dummyBytes = new Uint8Array(providedPasswordBytes.length);
		timingSafeEqual(providedPasswordBytes, dummyBytes);
		return false;
	}

	return timingSafeEqual(providedPasswordBytes, storedPasswordBytes);
};

const setupConfiguration = (authHeader: string): AppConfig => {
	const supabaseUrl = Deno.env.get('SUPABASE_URL');
	const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY');
	const strapiApiUrl = Deno.env.get('STRAPI_API_URL');
	const strapiToken = Deno.env.get('STRAPI_API_TOKEN');

	if (!supabaseUrl || !supabaseAnonKey) {
		throw new Error(
			'Supabase URL or Service Anon Key environment variable is missing.',
		);
	}
	if (!strapiApiUrl || !strapiToken) {
		throw new Error(
			'Strapi API URL or Token environment variable is missing.',
		);
	}

	const supabaseClient = createClient(supabaseUrl, supabaseAnonKey, {
		global: {
			headers: { Authorization: authHeader! },
		},
	});

	console.log('Environment variables loaded and Supabase client created.');

	return {
		supabaseClient,
		strapiApiUrl,
		strapiToken,
	};
};

Deno.serve(async (req) => {
	try {
		if (req.method === 'OPTIONS') {
			return new Response('ok', { headers: corsHeaders });
		}

		const superPasswordHeader = req.headers.get('x-super-password');
		if (!superPasswordHeader || !verifyPassword(superPasswordHeader)) {
			return new Response(
				JSON.stringify({ 
					error: 'Unauthorized: Invalid or missing credentials'
				}),
				{ 
					status: 401, 
					headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
				},
			);
		}

		const authHeader = req.headers.get('Authorization');
		if (!authHeader) {
			return new Response(
				JSON.stringify({ error: 'No autorizado' }),
				{ 
					status: 401,
					headers: { ...corsHeaders, 'Content-Type': 'application/json' }
				},
			);
		}

		const { supabaseClient, strapiToken, strapiApiUrl } =
			setupConfiguration(
				authHeader,
			);

		const { strapiAgreements, headquartersSet, rolesSet } =
			await connectToStrapi(strapiToken, strapiApiUrl, supabaseClient);

		const { rolesMap, headquartersMap } = await preloadSupabaseTableRecords(
			supabaseClient,
		);

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

		return new Response(JSON.stringify(result), {
			headers: { ...corsHeaders, 'Content-Type': 'application/json' },
			status: result.success ? 200 : 500,
		});

		/*  return new Response(csvData?.content, {
        headers: {
          ...corsHeaders,
          'Content-Type': 'text/csv',
          'Content-Disposition': `attachment; filename="${csvData?.filename}"`,
        },
        status: 200,
      });*/
	} catch (error: unknown) {
		return new Response(
			String(error instanceof Error ? error.message : error),
			{ status: 500 },
		);
	}
});

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
