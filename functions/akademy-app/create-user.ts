import { ZodError } from "https://deno.land/x/zod@v3.22.4/mod.ts";
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
import {
	CreateUserFromAgreementSchema,
	type UserCreationResponse,
	UserCreationResponseSchema,
} from "./user.ts";

export async function createUserFromAgreement(c: Context): Promise<Response> {
	const userMetadata = c.get("userMetadata") as UserMetadata | undefined;

	try {
		const body = await c.req.json();
		const validatedData = CreateUserFromAgreementSchema.parse(body);
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
			.eq("status", "prospect")
			.is("user_id", null)
			.single();

		if (agreementError || !agreement) {
			throw new HTTPException(404, {
				message: "Agreement not found or already activated",
			});
		}

		const agreementRecord = parseAgreementRow(agreement, "activation");
		const { role } = agreementRecord;

		if (role.role_level > userLevel) {
			throw new HTTPException(403, {
				message: `Cannot create user with role level ${role.role_level}. Your level: ${userLevel}`,
			});
		}

		const password = generatePassword();

		const { data: userData, error: userError } =
			await supabaseAdmin.auth.admin.createUser({
				email: agreementRecord.email,
				password,
				email_confirm: true,
				user_metadata: {
					role: role.role_code,
					role_level: role.role_level,
					role_id: role.role_id,
					hq_id: agreementRecord.headquarter_id,
					season_id: agreementRecord.season_id,
					agreement_id: agreementRecord.id,
					first_name: agreementRecord.name,
					last_name: agreementRecord.last_name,
					phone: agreementRecord.phone,
				},
			});

		if (userError || !userData?.user) {
			throw new HTTPException(500, {
				message: `Failed to create user: ${userError?.message ?? "Unknown error"}`,
			});
		}

		const { error: updateError } = await supabaseAdmin
			.from("agreements")
			.update({
				user_id: userData.user.id,
				status: "active",
				activation_date: new Date().toISOString(),
			})
			.eq("id", agreementRecord.id);

		if (updateError) {
			await supabaseAdmin.auth.admin.deleteUser(userData.user.id);

			throw new HTTPException(500, {
				message: `Failed to update agreement: ${updateError.message}`,
			});
		}

		const { headquarterName, countryName, seasonName } =
			ensureAgreementContext(agreementRecord);

		const response: UserCreationResponse = {
			user_id: userData.user.id,
			email: agreementRecord.email,
			password,
			headquarter_name: headquarterName,
			country_name: countryName,
			season_name: seasonName,
			role_name: role.role_name,
			phone: agreementRecord.phone || null,
		};

		UserCreationResponseSchema.parse(response);

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

			console.log(`Welcome email sent successfully to ${response.email}`);
		} catch (emailError) {
			console.error("Failed to send welcome email:", emailError);
		}

		return c.json({ data: response }, 201);
	} catch (error) {
		if (error instanceof HTTPException) {
			throw error;
		}
		if (error instanceof ZodError) {
			throw new HTTPException(400, { message: "Invalid request data" });
		}

		console.error("Error creating user:", error);
		throw new HTTPException(500, { message: "Internal server error" });
	}
}
