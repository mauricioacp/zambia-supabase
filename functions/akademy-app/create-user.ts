import { Context } from "jsr:@hono/hono@4";
import { HTTPException } from "jsr:@hono/hono@4/http-exception";
import { ZodError } from "https://deno.land/x/zod@v3.22.4/mod.ts";
import { createAdminSupabaseClient } from "./supabaseService.ts";
import { CreateUserFromAgreementSchema, UserCreationResponse } from "./user.ts";
import { generatePassword } from "./auth.ts";
import { trackEvent } from "./emailService.ts";

export async function createUserFromAgreement(c: Context): Promise<Response> {
  const userMetadata = await c.get("userMetadata");

  try {
    const body = await c.req.json();
    const validatedData = CreateUserFromAgreementSchema.parse(body);
    const userLevel = c.get("userLevel") as number;
    const supabaseAdmin = createAdminSupabaseClient();

    const { data: agreement, error: agreementError } = await supabaseAdmin
      .from("agreements")
      .select(`
        id, email, name, last_name, phone, user_id, status, role_id, headquarter_id, season_id,
        role:roles(code, level, name),
        headquarter:headquarters(name, country:countries(name))
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

    if (agreement.role.level > userLevel) {
      throw new HTTPException(403, {
        message:
          `Cannot create user with role level ${agreement.role.level}. Your level: ${userLevel}`,
      });
    }

    const password = generatePassword();

    const { data: userData, error: userError } = await supabaseAdmin.auth.admin
      .createUser({
        email: agreement.email,
        password,
        email_confirm: true,
        user_metadata: {
          role: agreement.role.code,
          role_level: agreement.role.level,
          role_id: agreement.role_id,
          hq_id: agreement.headquarter_id,
          season_id: agreement.season_id,
          agreement_id: agreement.id,
          first_name: agreement.name,
          last_name: agreement.last_name,
          phone: agreement.phone,
        },
      });

    if (userError) {
      throw new HTTPException(500, {
        message: `Failed to create user: ${userError.message}`,
      });
    }

    const { error: updateError } = await supabaseAdmin
      .from("agreements")
      .update({
        user_id: userData.user.id,
        status: "active",
        activation_date: new Date().toISOString(),
      })
      .eq("id", agreement.id);

    if (updateError) {
      await supabaseAdmin.auth.admin.deleteUser(userData.user.id);

      throw new HTTPException(500, {
        message: `Failed to update agreement: ${updateError.message}`,
      });
    }

    const response: UserCreationResponse = {
      user_id: userData.user.id,
      email: agreement.email,
      password,
      headquarter_name: agreement.headquarter.name,
      country_name: agreement.headquarter.country.name,
      season_name: agreement.season.name,
      role_name: agreement.role.name,
      phone: agreement.phone || null,
    };

    try {
      const invitedBy = userMetadata.first_name + " " + userMetadata.last_name +
        " " + userMetadata.role;

      const variables = {
        name: `${agreement.name || ""} ${agreement.last_name || ""}`.trim(),
        email: response.email,
        password: {
          value: response.password,
          persistent: false,
        },
        role: response.role_name,
        app_url: {
          value: "https://app.laakademia.digital",
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
