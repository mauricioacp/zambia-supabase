import { HTTPException } from "jsr:@hono/hono@4/http-exception";

export interface SendEmailParams {
	recipient: string;
	subject: string;
	msgBody: string;
	variables?: Record<string, string>;
}

export async function trackEvent(variables) {
	const key = Deno.env.get("PLUNK_SECRET_KEY") as string;

	await fetch("https://api.useplunk.com/v1/track", {
		method: "POST",
		headers: {
			"Content-Type": "application/json",
			Authorization: `Bearer ${key}`,
		},
		body: JSON.stringify({
			event: "on-boarding",
			email: variables.email,
			data: {
				...variables,
			},
		}),
	});
}

export async function sendEmail({
	recipient,
	subject,
	msgBody,
	variables,
}: SendEmailParams): Promise<void> {
	const key = Deno.env.get("PLUNK_SECRET_KEY") as string;

	if (!key) {
		throw new HTTPException(401, { message: "Missing Plunk secret key" });
	}

	try {
		let processedBody = msgBody;
		if (variables) {
			for (const [key, value] of Object.entries(variables)) {
				const placeholder = `{{${key}}}`;
				processedBody = processedBody.replaceAll(placeholder, value);
			}
		}

		const response = await fetch("https://api.useplunk.com/v1/send", {
			method: "POST",
			headers: {
				"Content-Type": "application/json",
				Authorization: `Bearer ${key}`,
			},
			body: JSON.stringify({
				to: recipient,
				subject,
				body: processedBody,
			}),
		});

		if (!response.ok) {
			const errorData = await response.text();
			console.error("Plunk API error:", errorData);
			throw new Error(
				`Failed to send email: ${response.status} ${response.statusText}`,
			);
		}

		console.log(`Email sent successfully to ${recipient}`);
	} catch (error) {
		console.error("Error sending email:", error);
	}
}
