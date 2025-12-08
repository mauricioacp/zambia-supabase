import { z } from "https://deno.land/x/zod@v3.22.4/mod.ts";
import type {
	ChangeRoleRequest,
	ChangeRoleResponse,
	CreateUserFromAgreementRequest,
	DeactivateUserRequest,
	DeactivateUserResponse,
	PasswordResetResponse,
	ResendCredentialsResponse,
	ResetPasswordRequest,
	UserCreationResponse,
} from "./interfaces.ts";

export const CreateUserFromAgreementSchema = z.object({
	agreement_id: z.string().uuid("Invalid agreement ID format"),
});

export const UserCreationResponseSchema = z.object({
	user_id: z.string().uuid(),
	email: z.string().email(),
	password: z.string(),
	headquarter_name: z.string().min(1),
	country_name: z.string().min(1),
	season_name: z.string().min(1),
	role_name: z.string().min(1),
	phone: z.string().nullable(),
});

export const ResetPasswordSchema = z.object({
	email: z.string().email("Invalid email format"),
	document_number: z.string().min(1, "Document number is required"),
	new_password: z.string().min(8, "Password must be at least 8 characters"),
	phone: z.string().min(1, "Phone number is required"),
	first_name: z.string().min(1, "First name is required"),
	last_name: z.string().min(1, "Last name is required"),
});

export const PasswordResetResponseSchema = z.object({
	message: z.string(),
	new_password: z.string(),
	user_email: z.string().email(),
});

export const DeactivateUserSchema = z.object({
	user_id: z.string().uuid("Invalid user ID format"),
	active: z.boolean().optional(),
});

export const DeactivateUserResponseSchema = z.object({
	message: z.string(),
	user_id: z.string().uuid(),
});

export const ChangeRoleSchema = z.object({
	agreement_id: z.string().uuid("Invalid agreement ID format"),
	new_role_id: z.string().uuid("Invalid role ID format"),
});

export type {
	ChangeRoleRequest,
	ChangeRoleResponse,
	CreateUserFromAgreementRequest,
	DeactivateUserRequest,
	DeactivateUserResponse,
	PasswordResetResponse,
	ResetPasswordRequest,
	ResendCredentialsResponse,
	UserCreationResponse,
};
