import { z } from 'zod';

// Schema for creating a user from agreement data
export const CreateUserFromAgreementSchema = z.object({
	agreement_id: z.string().uuid(),
});

// Schema for resetting user password
export const ResetPasswordSchema = z.object({
	email: z.string().email(),
	document_number: z.string().min(1),
	new_password: z.string().min(8),
	phone: z.string().min(1),
	first_name: z.string().min(1),
	last_name: z.string().min(1),
});

// Schema for deactivating a user
export const DeactivateUserSchema = z.object({
	user_id: z.string().uuid(),
});

// Response schemas
export const UserCreationResponseSchema = z.object({
	user_id: z.string().uuid(),
	email: z.string().email(),
	password: z.string(),
	headquarter_name: z.string(),
	country_name: z.string(),
	season_name: z.string(),
	role_name: z.string(),
	phone: z.string().nullable(),
});

export const PasswordResetResponseSchema = z.object({
	message: z.string(),
	new_password: z.string(),
	user_email: z.string(),
});

export const DeactivateUserResponseSchema = z.object({
	message: z.string(),
	user_id: z.string().uuid(),
});

// Type exports
export type CreateUserFromAgreement = z.infer<typeof CreateUserFromAgreementSchema>;
export type ResetPassword = z.infer<typeof ResetPasswordSchema>;
export type DeactivateUser = z.infer<typeof DeactivateUserSchema>;
export type UserCreationResponse = z.infer<typeof UserCreationResponseSchema>;
export type PasswordResetResponse = z.infer<typeof PasswordResetResponseSchema>;
export type DeactivateUserResponse = z.infer<typeof DeactivateUserResponseSchema>;