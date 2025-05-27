import { Context } from 'hono';
import { HTTPException } from 'hono/http-exception'
import { ZodError } from 'zod';
import { createAdminSupabaseClient } from '../services/supabaseService.ts';
import { DeactivateUserSchema, DeactivateUserResponse } from '../schemas/user.ts';

export async function deactivateUser(c: Context): Promise<Response> {
	try {
		const body = await c.req.json();
		const validatedData = DeactivateUserSchema.parse(body);

		const supabaseAdmin = createAdminSupabaseClient();

		// Get user data to verify it exists
		const { data: userData, error: userError } = await supabaseAdmin.auth.admin
			.getUserById(validatedData.user_id);

		if (userError || !userData.user) {
			throw new HTTPException(404, { message: 'User not found' });
		}

		// Update user to be disabled
		const { error: updateError } = await supabaseAdmin.auth.admin
			.updateUserById(validatedData.user_id, {
                ban_duration : new Date(Date.now() + 100 * 365 * 24 * 60 * 60 * 1000).toISOString() // 100 years from now
			});

		if (updateError) {
			throw new HTTPException(500, { 
				message: `Failed to deactivate user: ${updateError.message}` 
			});
		}

		// Update agreements status to inactive
		const { error: agreementError } = await supabaseAdmin
			.from('agreements')
			.update({ status: 'inactive' })
			.eq('user_id', validatedData.user_id);

		if (agreementError) {
			console.error('Warning: Failed to update agreement status:', agreementError);
			// Don't fail the request as user is already deactivated
		}

		const response: DeactivateUserResponse = {
			message: `User ${userData.user.email} has been deactivated`,
			user_id: validatedData.user_id,
		};

		return c.json({ data: response });
	} catch (error) {
		if (error instanceof HTTPException) {
			throw error;
		}
		if (error instanceof ZodError) {
			throw new HTTPException(400, { message: 'Invalid request data' });
		}
		
		console.error('Error deactivating user:', error);
		throw new HTTPException(500, { message: 'Internal server error' });
	}
}