import { z } from "https://deno.land/x/zod@v3.22.4/mod.ts";
import { HTTPException } from "jsr:@hono/hono@4/http-exception";

export const AgreementRoleSchema = z.object({
	role_id: z.string().uuid(),
	role_code: z.string().min(1),
	role_name: z.string().min(1),
	role_level: z.number(),
});

export const AgreementHeadquarterSchema = z.object({
	name: z.string().min(1),
	country: z.object({
		name: z.string().min(1),
	}),
});

export const AgreementSeasonSchema = z.object({
	name: z.string().min(1),
});

export const AgreementRecordSchema = z.object({
	id: z.string().uuid(),
	email: z.string().email(),
	name: z.string().nullable(),
	last_name: z.string().nullable(),
	phone: z.string().nullable(),
	user_id: z.string().uuid().nullable(),
	status: z.string(),
	headquarter_id: z.string().uuid().nullable(),
	season_id: z.string().uuid().nullable(),
	role: AgreementRoleSchema,
	headquarter: AgreementHeadquarterSchema.nullable(),
	season: AgreementSeasonSchema.nullable(),
});

export type AgreementRecord = z.infer<typeof AgreementRecordSchema>;

export type UserMetadata = {
	first_name?: string;
	last_name?: string;
	role?: string;
};

export function parseAgreementRow(
	row: unknown,
	context: string,
): AgreementRecord {
	const result = AgreementRecordSchema.safeParse(row);

	if (!result.success) {
		console.error(
			`Agreement ${context} has unexpected shape`,
			result.error.flatten(),
		);
		throw new HTTPException(422, { message: "Agreement data is incomplete" });
	}

	return result.data;
}

export function ensureAgreementContext(agreement: AgreementRecord) {
	const headquarterName = agreement.headquarter?.name;
	const countryName = agreement.headquarter?.country?.name;
	const seasonName = agreement.season?.name;

	if (!headquarterName || !countryName || !seasonName) {
		throw new HTTPException(422, {
			message: "Agreement missing headquarter or season information",
		});
	}

	return { headquarterName, countryName, seasonName };
}

export function formatInvitedBy(metadata?: UserMetadata): string {
	return (
		[metadata?.first_name, metadata?.last_name, metadata?.role]
			.filter(Boolean)
			.join(" ") || "Akademy Team"
	);
}
