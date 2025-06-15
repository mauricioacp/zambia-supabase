import { StrapiAgreement } from './interfaces.ts';

/**
 * @param apiUrl
 * @param apiToken
 * @param endpoint
 * @param lastMigratedAt
 * @returns Promise<StrapiAgreement[]>
 */
export async function fetchAllStrapiAgreements(
	apiUrl: string,
	apiToken: string,
	endpoint: string = '/api/acuerdo-akademias',
	lastMigratedAt: string | null,
): Promise<StrapiAgreement[]> {
	const allAgreements: StrapiAgreement[] = [];
	let page = 1;
	const pageSize = 100;
	let hasMorePages = true;

	while (hasMorePages) {
		// Fix double slash issue by ensuring proper URL construction
		const baseUrl = apiUrl.endsWith('/') ? apiUrl.slice(0, -1) : apiUrl;
		const cleanEndpoint = endpoint.startsWith('/') ? endpoint : `/${endpoint}`;
		let url = `${baseUrl}${cleanEndpoint}?pagination[page]=${page}&pagination[pageSize]=${pageSize}&populate=*`;
		
		// Re-enable server-side filtering now that URL construction is fixed
		if (lastMigratedAt) {
			url += `&filters[$or][0][createdAt][$gt]=${
				encodeURIComponent(lastMigratedAt)
			}`;
			url += `&filters[$or][1][updatedAt][$gt]=${
				encodeURIComponent(lastMigratedAt)
			}`;
			console.log(
				`Filtering records created or updated after: ${lastMigratedAt}`,
			);
		}

		try {
			const response = await fetch(url, {
				method: 'GET',
				headers: {
					'Authorization': `Bearer ${apiToken}`,
					'Accept': 'application/json',
					'Content-Type': 'application/json',
				},
			});

			if (!response.ok) {
				const errorBody = await response.text();
				throw new Error(
					`Strapi API request failed (Page ${page}): ${response.status} ${response.statusText} - ${errorBody}`,
				);
			}

			const strapiResponse = await response.json();

			// deno-lint-ignore no-explicit-any
			const agreements = (strapiResponse.data || []).map((item: any) => ({
				id: item.id,
				...(item?.attributes || item),
			})) as StrapiAgreement[];

			if (agreements.length > 0) {
				allAgreements.push(...agreements);
			}

			const pagination = strapiResponse.meta?.pagination;
			if (pagination) {
				hasMorePages = pagination.page < pagination.pageCount;
				page++;
			} else {
				hasMorePages = agreements.length === pageSize;
				page++;
			}
		} catch (error) {
			console.log(JSON.stringify(error, null, 2));
			console.error(`Error fetching page ${page} from Strapi:`, error);
			throw error;
		}
	}

	console.log(
		`Finished fetching from Strapi. Total records: ${allAgreements.length}`,
	);
	return allAgreements;
}
