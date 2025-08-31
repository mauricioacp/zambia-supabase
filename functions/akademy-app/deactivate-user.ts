import { Context } from 'jsr:@hono/hono@4';
import { HTTPException } from 'jsr:@hono/hono@4/http-exception';
import { ZodError } from 'https://deno.land/x/zod@v3.22.4/mod.ts';
import { createAdminSupabaseClient } from './supabaseService.ts';
import { DeactivateUserSchema, DeactivateUserResponse } from './user.ts';

export async function deactivateUser(c: Context): Promise<Response> {
	try {
		const body = await c.req.json();
		const validatedData: DeactivateUserSchema = DeactivateUserSchema.parse(body);

		const supabaseAdmin = createAdminSupabaseClient();

		const { data: userData, error: userError } = await supabaseAdmin.auth.admin
			.getUserById(validatedData.user_id);

		if (userError || !userData.user) {
			throw new HTTPException(404, { message: 'User not found' });
		}

    const { error: updateError } =await supabase.auth.admin.updateUserById(id, {
      ban_duration: validatedData.active ? "none" : "876600h", // 100 years
    });

		if (updateError) {
			throw new HTTPException(500, { 
				message: `Failed to deactivate user: ${updateError.message}` 
			});
		}

		const { error: agreementError } = await supabaseAdmin
			.from('agreements')
			.update({ status: 'inactive' })
			.eq('user_id', validatedData.user_id);

		if (agreementError) {
			console.error('Warning: Failed to update agreement status:', agreementError);
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
