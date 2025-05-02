import { corsHeaders } from '../middleware/cors.ts';
import { supabaseAdmin } from '../services/supabase.ts';
import { UserCreationSchema } from '../schemas/user.ts';

// Handle user creation
export async function createUser(req: Request) {
	const body = await req.json();
	const validatedData = UserCreationSchema.parse(body);

	// Create user with Supabase auth
	const { data: userData, error: userError } = await supabaseAdmin.auth.admin
		.createUser({
			email: validatedData.email,
			password: validatedData.password,
			email_confirm: true,
			user_metadata: {
				agreement_id: validatedData.agreement_id,
				role_id: validatedData.role_id,
				headquarter_id: validatedData.headquarter_id,
			},
		});

	if (userError) throw userError;

	// Update agreement with user_id
	const { error: agreementError } = await supabaseAdmin
		.from('agreements')
		.update({ user_id: userData.user.id })
		.eq('id', validatedData.agreement_id);

	if (agreementError) throw agreementError;

	return new Response(JSON.stringify({ data: userData.user }), {
		status: 201,
		headers: { ...corsHeaders, 'Content-Type': 'application/json' },
	});
}
