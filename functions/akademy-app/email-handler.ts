import { ZodError } from "https://deno.land/x/zod@v3.22.4/mod.ts";
import type { Context } from "jsr:@hono/hono@4";
import { HTTPException } from "jsr:@hono/hono@4/http-exception";
import { EmailHandlerSchema as schema } from "./emailSchema.ts";

export async function emailHandler(c: Context): Promise<Response> {
	try {
		const body = await c.req.json();
		const { recipient, subject, msgBody } = schema.parse(body);
		const key = Deno.env.get("PLUNK_SECRET_KEY") as string;

		if (!key)
			throw new HTTPException(401, { message: "Missing Plunk secret key" });

		await fetch("https://api.useplunk.com/v1/send", {
			method: "POST",
			headers: {
				"Content-Type": "application/json",
				Authorization: `Bearer ${key}`,
			},
			body: JSON.stringify({
				to: recipient,
				subject,
				body: msgBody,
			}),
		});

		return c.json({ data: "Email sent successfully", ok: true });
	} catch (error) {
		if (error instanceof HTTPException) {
			throw error;
		}
		if (error instanceof ZodError) {
			throw new HTTPException(400, { message: "Invalid request data" });
		}

		throw new HTTPException(500, { message: "Internal server error" });
	}
}
