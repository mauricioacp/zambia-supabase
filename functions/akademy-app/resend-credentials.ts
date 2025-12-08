import { ZodError, z } from "https://deno.land/x/zod@v3.22.4/mod.ts";
import type { Context } from "jsr:@hono/hono@4";
import { HTTPException } from "jsr:@hono/hono@4/http-exception";
import {
	ensureAgreementContext,
	formatInvitedBy,
	parseAgreementRow,
	type UserMetadata,
} from "./agreementUtils.ts";
import { generatePassword } from "./auth.ts";
import { trackEvent } from "./emailService.ts";
import { createAdminSupabaseClient } from "./supabaseService.ts";

export const ResendCredentialsSchema = z.object({
	agreement_id: z.string().uuid("Invalid agreement ID format"),
});

export const ResendCredentialsResponseSchema = z.object({
	user_id: z.string().uuid(),
	email: z.string().email(),
	password: z.string(),
	headquarter_name: z.string(),
	country_name: z.string(),
	season_name: z.string(),
	role_name: z.string(),
	phone: z.string().nullable(),
});

export type ResendCredentialsResponse = z.infer<
	typeof ResendCredentialsResponseSchema
>;

export async function resendUserCredentials(c: Context): Promise<Response> {
	const userMetadata = c.get("userMetadata") as UserMetadata | undefined;

	try {
		const body = await c.req.json();
		const validatedData = ResendCredentialsSchema.parse(body);
		const userLevel = c.get("userLevel") as number;
		const supabaseAdmin = createAdminSupabaseClient();

		const { data: agreement, error: agreementError } = await supabaseAdmin
			.from("agreement_with_role")
			.select(`
        id,
        email,
        name,
        last_name,
        phone,
        user_id,
        status,
        headquarter_id,
        season_id,
        role,
        headquarter:headquarters(name, country:countries(name)),
        season:seasons(name)
      `)
			.eq("id", validatedData.agreement_id)
			.eq("status", "active")
			.not("user_id", "is", null)
			.single();

		if (agreementError || !agreement) {
			throw new HTTPException(404, {
				message: "Active agreement with user not found",
			});
		}

		const agreementRecord = parseAgreementRow(agreement, "credential resend");

		if (!agreementRecord.user_id) {
			throw new HTTPException(422, {
				message: "Agreement missing linked user",
			});
		}
		const { role } = agreementRecord;

		if (role.role_level > userLevel) {
			throw new HTTPException(403, {
				message: `Cannot resend credentials for user with role level ${role.role_level}. Your level: ${userLevel}`,
			});
		}

		const newPassword = generatePassword();

		const { error: passwordError } =
			await supabaseAdmin.auth.admin.updateUserById(agreementRecord.user_id, {
				password: newPassword,
			});

		if (passwordError) {
			throw new HTTPException(500, {
				message: `Failed to update user password: ${passwordError.message}`,
			});
		}

		const { headquarterName, countryName, seasonName } =
			ensureAgreementContext(agreementRecord);

		const response: ResendCredentialsResponse = {
			user_id: agreementRecord.user_id,
			email: agreementRecord.email,
			password: newPassword,
			headquarter_name: headquarterName,
			country_name: countryName,
			season_name: seasonName,
			role_name: role.role_name,
			phone: agreementRecord.phone || null,
		};

		ResendCredentialsResponseSchema.parse(response);

		try {
			const invitedBy = formatInvitedBy(userMetadata);

			const variables = {
				name: `${agreementRecord.name || ""} ${agreementRecord.last_name || ""}`.trim(),
				email: response.email,
				password: {
					value: response.password,
					persistent: false,
				},
				role: response.role_name,
				app_url: {
					value: "https://laakademia.app",
					persistent: false,
				},
				hq: response.headquarter_name,
				invitedBy,
			};

			await trackEvent(variables);

			console.log(`Credentials resent successfully to ${response.email}`);
		} catch (emailError) {
			console.error("Failed to resend credentials email:", emailError);
		}

		return c.json({ data: response }, 200);
	} catch (error) {
		if (error instanceof HTTPException) {
			throw error;
		}
		if (error instanceof ZodError) {
			throw new HTTPException(400, { message: "Invalid request data" });
		}

		console.error("Error resending credentials:", error);
		throw new HTTPException(500, { message: "Internal server error" });
	}
}
