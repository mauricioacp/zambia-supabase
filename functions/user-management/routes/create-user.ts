import { Context } from 'hono';
import { HTTPException } from 'hono/http-exception';
import { ZodError } from 'zod';
import { supabaseAdmin } from '../services/supabase.ts';
import { CreateUserFromAgreementSchema, UserCreationResponse } from '../schemas/user.ts';
import { generatePassword } from '../utils/auth.ts';

export async function createUserFromAgreement(c: Context): Promise<Response> {
	try {
		const body = await c.req.json();
		const validatedData = CreateUserFromAgreementSchema.parse(body);
		const userLevel = c.get('userLevel') as number;

		// Get agreement data with related information
		const { data: agreement, error: agreementError } = await supabaseAdmin
			.from('agreements')
			.select(`
				*,
				role:roles(*),
				headquarter:headquarters(*, country:countries(*)),
				season:seasons(*)
			`)
			.eq('id', validatedData.agreement_id)
			.eq('status', 'prospect')
			.is('user_id', null)
			.single();

		if (agreementError || !agreement) {
			throw new HTTPException(404, { 
				message: 'Agreement not found or already activated' 
			});
		}

		// Check if user can create this role level
		if (agreement.role.level > userLevel) {
			throw new HTTPException(403, { 
				message: `Cannot create user with role level ${agreement.role.level}. Your level: ${userLevel}` 
			});
		}

		// Generate password
		const password = generatePassword();

		// Create user with Supabase auth
		const { data: userData, error: userError } = await supabaseAdmin.auth.admin
			.createUser({
				email: agreement.email,
				password,
				email_confirm: true,
				user_metadata: {
					role: agreement.role.code,
					role_level: agreement.role.level,
					role_id: agreement.role_id,
					hq_id: agreement.headquarter_id,
					season_id: agreement.season_id,
					agreement_id: agreement.id,
					name: agreement.name,
					last_name: agreement.last_name,
					phone: agreement.phone,
				},
			});

		if (userError) {
			throw new HTTPException(500, { message: `Failed to create user: ${userError.message}` });
		}

		// Update agreement with user_id and change status to active
		const { error: updateError } = await supabaseAdmin
			.from('agreements')
			.update({ 
				user_id: userData.user.id,
				status: 'active',
				activation_date: new Date().toISOString()
			})
			.eq('id', agreement.id);

		if (updateError) {
			// Try to delete the created user if agreement update fails
			await supabaseAdmin.auth.admin.deleteUser(userData.user.id);
			throw new HTTPException(500, { message: `Failed to update agreement: ${updateError.message}` });
		}

		const response: UserCreationResponse = {
			user_id: userData.user.id,
			email: agreement.email,
			password,
			headquarter_name: agreement.headquarter.name,
			country_name: agreement.headquarter.country.name,
			season_name: agreement.season.name,
			role_name: agreement.role.name,
			phone: agreement.phone || null,
		};

		return c.json({ data: response }, 201);
	} catch (error) {
		if (error instanceof HTTPException) {
			throw error;
		}
		if (error instanceof ZodError) {
			throw new HTTPException(400, { message: 'Invalid request data' });
		}
		
		console.error('Error creating user:', error);
		throw new HTTPException(500, { message: 'Internal server error' });
	}
}