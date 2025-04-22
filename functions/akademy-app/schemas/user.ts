import { z } from "zod";

// User creation schema for validation
export const UserCreationSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8),
  agreement_id: z.string().uuid(),
  role_id: z.string().uuid(),
  headquarter_id: z.string().uuid(),
});

// Super admin creation schema for validation
export const SuperAdminCreationSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8),
  agreement_id: z.string().uuid(),
  role_id: z.string().uuid(),
  headquarter_id: z.string().uuid(),
});

export type UserCreation = z.infer<typeof UserCreationSchema>;
export type SuperAdminCreation = z.infer<typeof SuperAdminCreationSchema>;