import { Context } from 'jsr:@hono/hono@4';
import { HTTPException } from 'jsr:@hono/hono@4/http-exception';
import { ZodError } from 'https://deno.land/x/zod@v3.22.4/mod.ts';
import { createAdminSupabaseClient } from './supabaseService.ts';
import { ResetPasswordSchema, PasswordResetResponse } from './user.ts';

export async function resetUserPassword(c: Context): Promise<Response> {
	try {
		const body = await c.req.json();
		const validatedData = ResetPasswordSchema.parse(body);

		const supabaseAdmin = createAdminSupabaseClient();

		const { data: agreement, error: agreementError } = await supabaseAdmin
			.from('agreements')
			.select('user_id, email')
			.eq('email', validatedData.email)
			.eq('document_number', validatedData.document_number)
			.eq('phone', validatedData.phone)
			.ilike('name', validatedData.first_name)
			.ilike('last_name', validatedData.last_name)
			.not('user_id', 'is', null)
			.single();

		if (agreementError || !agreement) {
			throw new HTTPException(404, { 
				message: 'User not found or data mismatch' 
			});
		}

		const { error: passwordError } = await supabaseAdmin.auth.admin
			.updateUserById(agreement.user_id, {
				password: validatedData.new_password
			});

		if (passwordError) {
			throw new HTTPException(500, { 
				message: `Failed to update password: ${passwordError.message}` 
			});
		}

		const response: PasswordResetResponse = {
			message: `Password successfully updated for user ${validatedData.email}`,
			new_password: validatedData.new_password,
			user_email: validatedData.email,
		};

		return c.json({ data: response });
	} catch (error) {
		if (error instanceof HTTPException) {
			throw error;
		}
		if (error instanceof ZodError) {
			throw new HTTPException(400, { message: 'Invalid request data' });
		}
		
		console.error('Error resetting password:', error);
		throw new HTTPException(500, { message: 'Internal server error' });
	}
}
