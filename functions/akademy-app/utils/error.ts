import { corsHeaders } from '../middleware/cors.ts';

export function handleError(error: unknown, status = 500) {
	console.error('Error:', error);
	const message = error instanceof Error
		? error.message
		: 'Unknown error occurred';
	return new Response(JSON.stringify({ error: message }), {
		status,
		headers: { ...corsHeaders, 'Content-Type': 'application/json' },
	});
}
