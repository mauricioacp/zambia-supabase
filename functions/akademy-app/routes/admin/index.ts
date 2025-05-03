import { corsHeaders } from '../../middleware/cors.ts';
import {
	createAgreement,
	deleteAgreement,
	getAgreements,
	updateAgreement,
} from './agreements.ts';
import { getUsers } from './users.ts';

// Handle admin routes
export async function handleAdminRoute(req: Request, resource: string) {
	// Handle agreements resource
	if (resource === 'agreements') {
		if (req.method === 'GET') {
			return getAgreements();
		} else if (req.method === 'POST') {
			return createAgreement(req);
		} else if (req.method === 'PUT') {
			return updateAgreement(req);
		} else if (req.method === 'DELETE') {
			return deleteAgreement(req);
		}
	} // Handle users resource
	else if (resource === 'users') {
		if (req.method === 'GET') {
			return getUsers();
		}
	}

	// Handle unknown resource
	return new Response(JSON.stringify({ error: 'Resource not found' }), {
		status: 404,
		headers: { ...corsHeaders, 'Content-Type': 'application/json' },
	});
}
