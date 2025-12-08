#!/usr/bin/env -S deno run -A

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";

interface TestResult {
	testName: string;
	success: boolean;
	message: string;
	status?: number;
}

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const supabaseAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

const { data: agreement, error: agreementError } = await supabaseAdmin
	.from("agreements")
	.select(`
				*,
				role:roles(*),
				user_id
			`)
	.eq("id", validatedData.agreement_id)
	.single();

const { data: targetRole, error: roleError } = await supabaseAdmin
	.from("roles")
	.select("*")
	.eq("id", validatedData.new_role_id)
	.eq("status", "active")
	.single();

const { error: agreementUpdateError } = await supabaseAdmin
	.from("agreements")
	.update({
		role_id: validatedData.new_role_id,
		updated_at: new Date().toISOString(),
	})
	.eq("id", validatedData.agreement_id);

const { error: userUpdateError } =
	await supabaseAdmin.auth.admin.updateUserById(agreement.user_id, {
		user_metadata: {
			role: targetRole.code,
			hq_id: agreement.headquarter_id,
			phone: agreement.phone,
			role_id: targetRole.id,
			last_name: agreement.last_name,
			season_id: agreement.season_id,
			first_name: agreement.name,
			role_level: targetRole.level,
			agreement_id: agreement.id,
		},
	});
