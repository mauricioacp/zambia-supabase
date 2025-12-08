import { z } from "https://deno.land/x/zod@v3.22.4/mod.ts";
export const EmailHandlerSchema = z.object({
	userId: z.string(),
	recipient: z.string().email(),
	subject: z.string(),
	msgBody: z.string(),
});
