import { Context } from "jsr:@hono/hono@4";
import { HTTPException } from "jsr:@hono/hono@4/http-exception";
import { ZodError } from "https://deno.land/x/zod@v3.22.4/mod.ts";
import { createAdminSupabaseClient } from "./supabaseService.ts";
import { ChangeRoleResponse, ChangeRoleSchema } from "./user.ts";

export async function changeUserRole(c: Context): Promise<Response> {
  const userLevel = c.get("userLevel") as number;

  try {
    const body = await c.req.json();
    const validatedData = ChangeRoleSchema.parse(body);
    const supabaseAdmin = createAdminSupabaseClient();

    const { data: agreement, error: agreementError } = await supabaseAdmin
      .from("agreements")
      .select(`
				*,
				role:roles(*),
				user_id
			`)
      .eq("id", validatedData.agreement_id)
      .single();

    if (agreementError || !agreement) {
      throw new HTTPException(404, {
        message: "Agreement not found",
      });
    }

    if (!agreement.user_id) {
      throw new HTTPException(400, {
        message: "Agreement does not have an associated user",
      });
    }

    const { data: targetRole, error: roleError } = await supabaseAdmin
      .from("roles")
      .select("*")
      .eq("id", validatedData.new_role_id)
      .eq("status", "active")
      .single();

    if (roleError || !targetRole) {
      throw new HTTPException(404, {
        message: "Target role not found or inactive",
      });
    }

    if (targetRole.level > userLevel) {
      throw new HTTPException(403, {
        message:
          `Cannot change to role level ${targetRole.level}. Your level: ${userLevel}`,
      });
    }

    if (agreement.role_id === validatedData.new_role_id) {
      throw new HTTPException(400, {
        message: "User already has this role",
      });
    }

    const { error: agreementUpdateError } = await supabaseAdmin
      .from("agreements")
      .update({
        role_id: validatedData.new_role_id,
        updated_at: new Date().toISOString(),
      })
      .eq("id", validatedData.agreement_id);

    if (agreementUpdateError) {
      throw new HTTPException(500, {
        message: `Failed to update agreement: ${agreementUpdateError.message}`,
      });
    }

    const { error: userUpdateError } = await supabaseAdmin.auth.admin
      .updateUserById(agreement.user_id, {
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

    if (userUpdateError) {
      await supabaseAdmin
        .from("agreements")
        .update({
          role_id: agreement.role_id,
          updated_at: agreement.updated_at,
        })
        .eq("id", validatedData.agreement_id);

      throw new HTTPException(500, {
        message: `Failed to update user metadata: ${userUpdateError.message}`,
      });
    }

    const response: ChangeRoleResponse = {
      message: "Role changed successfully",
      agreement_id: validatedData.agreement_id,
      user_id: agreement.user_id,
      old_role: {
        id: agreement.role.id,
        code: agreement.role.code,
        name: agreement.role.name,
        level: agreement.role.level,
      },
      new_role: {
        id: targetRole.id,
        code: targetRole.code,
        name: targetRole.name,
        level: targetRole.level,
      },
    };

    return c.json(response);
  } catch (error) {
    if (error instanceof ZodError) {
      throw new HTTPException(400, {
        message: `Validation error: ${
          error.errors.map((e) => `${e.path.join(".")}: ${e.message}`).join(
            ", ",
          )
        }`,
      });
    }

    if (error instanceof HTTPException) {
      throw error;
    }

    console.error("Unexpected error in changeUserRole:", error);
    throw new HTTPException(500, {
      message: "Internal server error",
    });
  }
}
