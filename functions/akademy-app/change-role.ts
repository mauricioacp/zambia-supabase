import { Context } from "jsr:@hono/hono@4";
import { HTTPException } from "jsr:@hono/hono@4/http-exception";
import { ZodError } from "https://deno.land/x/zod@v3.22.4/mod.ts";
import { createAdminSupabaseClient } from "./supabaseService.ts";
import { ChangeRoleResponse, ChangeRoleSchema } from "./user.ts";

export async function changeUserRole(c: Context): Promise<Response> {
  const userLevel = c.get("userLevel") as number;

  try {
    const body = await c.req.json();
    const { agreement_id, new_role_id } = ChangeRoleSchema.parse(body);
    const supabaseAdmin = createAdminSupabaseClient();

      const { data: originalAgreement, error: originalError } = await supabaseAdmin
          .from("agreements")
          .select("role_id, updated_at")
          .eq("id", agreement_id)
          .single();

      if (originalError || !originalAgreement) {
          throw new HTTPException(404, {
              message: "Agreement not found",
          });
      }

      const { data: targetRole, error: roleError } = await supabaseAdmin
      .from("roles")
      .select("id,level,code,name")
      .eq("id", new_role_id)
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
          `Cannot change to role level ${targetRole.level}. Lack of permissions`,
      });
    }

    const { error: agreementUpdateError } = await supabaseAdmin
      .from("agreements")
      .update({
        role_id: new_role_id,
        updated_at: new Date().toISOString(),
      })
      .eq("id", agreement_id);

    if (agreementUpdateError) {
      throw new HTTPException(500, {
        message: `Failed to update agreement: ${agreementUpdateError.message}`,
      });
    }

    const {data: agreement, error: agreementError } = await supabaseAdmin
      .from("agreements")
      .select(
        `id, user_id, headquarter_id, phone, last_name, season_id, name, role_id, updated_at,
        role:roles(id, code, name, level)`,
      )
      .eq("id", agreement_id)
      .single();

    if (agreementError || !agreement) {
      throw new HTTPException(404, {
        message: "Agreement not found after update",
      });
    }

    if (agreement.user_id) {
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
        const { error: rollbackError } = await supabaseAdmin
          .from("agreements")
          .update({
            role_id: originalAgreement.role_id,
            updated_at: originalAgreement.updated_at,
          })
          .eq("id", agreement_id);

        if (rollbackError) {
          console.error("Failed to rollback agreement:", rollbackError);
        }

        throw new HTTPException(500, {
          message: `Failed to update user metadata: ${userUpdateError.message}`,
        });
      }
    }

    const response: ChangeRoleResponse = {
      message: "Role changed successfully",
      agreement_id: agreement_id,
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
        message: "Invalid request data",
        details: error.errors,
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
