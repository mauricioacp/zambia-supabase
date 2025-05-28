import { z } from 'zod';
import { 
	CreateUserFromAgreementRequest, 
	UserCreationResponse, 
	ResetPasswordRequest, 
	PasswordResetResponse,
	DeactivateUserRequest,
	DeactivateUserResponse
} from '../interfaces.ts';

// User creation schema
export const CreateUserFromAgreementSchema = z.object({
	agreement_id: z.string().uuid('Invalid agreement ID format'),
});

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

// Password reset schema
export const ResetPasswordSchema = z.object({
	email: z.string().email('Invalid email format'),
	document_number: z.string().min(1, 'Document number is required'),
	new_password: z.string().min(8, 'Password must be at least 8 characters'),
	phone: z.string().min(1, 'Phone number is required'),
	first_name: z.string().min(1, 'First name is required'),
	last_name: z.string().min(1, 'Last name is required'),
});

export const PasswordResetResponseSchema = z.object({
	message: z.string(),
	new_password: z.string(),
	user_email: z.string().email(),
});

// User deactivation schema
export const DeactivateUserSchema = z.object({
	user_id: z.string().uuid('Invalid user ID format'),
});

export const DeactivateUserResponseSchema = z.object({
	message: z.string(),
	user_id: z.string().uuid(),
});

// Type exports for TypeScript
export type { 
	CreateUserFromAgreementRequest, 
	UserCreationResponse, 
	ResetPasswordRequest, 
	PasswordResetResponse,
	DeactivateUserRequest,
	DeactivateUserResponse
};