import { createClient } from "supabase";
import { SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY } from "../config/env.ts";

export const supabaseAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);