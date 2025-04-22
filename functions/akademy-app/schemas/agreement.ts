import { z } from "zod";

// Agreement schema for validation
export const AgreementSchema = z.object({
  id: z.string().uuid().optional(),
  role_id: z.string().uuid(),
  headquarter_id: z.string().uuid(),
  season_id: z.string().uuid().optional(),
  status: z.enum(["active", "graduated", "inactive", "prospect"]).default("prospect"),
  email: z.string().email(),
  document_number: z.string().optional(),
  phone: z.string().optional(),
  name: z.string().optional(),
  last_name: z.string().optional(),
  address: z.string().optional(),
  volunteering_agreement: z.boolean().default(false),
  ethical_document_agreement: z.boolean().default(false),
  mailing_agreement: z.boolean().default(false),
  age_verification: z.boolean().default(false),
  signature_data: z.string().optional(),
});

export type Agreement = z.infer<typeof AgreementSchema>;