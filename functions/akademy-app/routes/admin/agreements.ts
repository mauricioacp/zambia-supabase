import { corsHeaders } from '../../middleware/cors.ts';
import { supabaseAdmin } from '../../services/supabase.ts';
import { AgreementSchema } from '../../schemas/agreement.ts';

// Handle GET request for agreements
export async function getAgreements() {
	// TODO: Implement getAgreements function
	// const { data: agreements, error: agreementsError } = await supabaseAdmin
	//   .from("agreements")
	//   .select(`
	//     *,
	//     roles:agreement_roles(role_id)
	//   `);

	// if (agreementsError) throw agreementsError;

	// return new Response(JSON.stringify({ data: agreements }), {
	// headers: { ...corsHeaders, "Content-Type": "application/json" },
	// });
}

// Handle POST request for creating an agreement
export async function createAgreement(req: Request) {
	const body = await req.json();
	const validatedData = AgreementSchema.parse(body);

	// Extract roles from validated data
	const roles = validatedData.roles || [];
	delete validatedData.roles;

	// Start a transaction
	const { data: agreement, error: agreementError } = await supabaseAdmin
		.from('agreements')
		.insert(validatedData)
		.select()
		.single();

	if (agreementError) throw agreementError;

	// If roles are provided, insert them into the agreement_roles table
	if (roles.length > 0) { // doesnt exist anymore
		const roleEntries = roles.map((roleId) => ({
			agreement_id: agreement.id,
			role_id: roleId,
		}));

		const { error: rolesError } = await supabaseAdmin
			.from('agreement_roles') // doesnt exist anymore
			.insert(roleEntries);

		if (rolesError) throw rolesError;
	}

	// Return the created agreement with its roles
	const { data: agreementWithRoles, error: fetchError } = await supabaseAdmin
		.from('agreements')
		.select(`
      *,
      roles:agreement_roles(role_id) // doesnt exist anymore
    `)
		.eq('id', agreement.id)
		.single();

	if (fetchError) throw fetchError;

	return new Response(JSON.stringify({ data: agreementWithRoles }), {
		status: 201,
		headers: { ...corsHeaders, 'Content-Type': 'application/json' },
	});
}

// Handle PUT request for updating an agreement
export async function updateAgreement(req: Request) {
	const body = await req.json();
	const validatedData = AgreementSchema.parse(body);

	if (!validatedData.id) {
		return new Response(
			JSON.stringify({ error: 'Agreement ID is required' }),
			{
				status: 400,
				headers: { ...corsHeaders, 'Content-Type': 'application/json' },
			},
		);
	}

	// Extract roles from validated data
	const roles = validatedData.roles || [];
	delete validatedData.roles;

	const { data: agreement, error: agreementError } = await supabaseAdmin
		.from('agreements')
		.update(validatedData)
		.eq('id', validatedData.id)
		.select()
		.single();

	if (agreementError) throw agreementError;

	if (roles.length > 0) {
		const { error: deleteError } = await supabaseAdmin
			.from('agreement_roles') // doesnt exist anymore
			.delete()
			.eq('agreement_id', validatedData.id);

		if (deleteError) throw deleteError;

		const roleEntries = roles.map((roleId) => ({
			agreement_id: validatedData.id,
			role_id: roleId,
		}));

		const { error: rolesError } = await supabaseAdmin
			.from('agreement_roles') // doesnt exist anymore
			.insert(roleEntries);

		if (rolesError) throw rolesError;
	}

	// TODO
	return new Response(JSON.stringify({ data: null }), {
		headers: { ...corsHeaders, 'Content-Type': 'application/json' },
	});
}

export async function deleteAgreement(req: Request) {
	const body = await req.json();
	const { id } = body;

	if (!id) {
		return new Response(
			JSON.stringify({ error: 'Agreement ID is required' }),
			{
				status: 400,
				headers: { ...corsHeaders, 'Content-Type': 'application/json' },
			},
		);
	}

	const { error: agreementError } = await supabaseAdmin
		.from('agreements')
		.delete()
		.eq('id', id);

	if (agreementError) throw agreementError;

	return new Response(JSON.stringify({ success: true }), {
		headers: { ...corsHeaders, 'Content-Type': 'application/json' },
	});
}
