import {
  createClient,
  SupabaseClient,
} from "https://esm.sh/@supabase/supabase-js@2.39.8";
import "jsr:@std/dotenv/load";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const TEST_USER_PASSWORD = Deno.env.get("TEST_USER_PASSWORD") || "Test123!";
const TEST_USER_EMAIL_PREFIX = Deno.env.get("TEST_USER_EMAIL_PREFIX") ||
  "test-user-";

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  console.error(
    "Error: SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY environment variables are required",
  );
  Deno.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

interface Role {
  id: string;
  code: string;
  name: string;
  description?: string;
  status: string;
}

interface Credentials {
  role: string;
  email: string;
  password: string;
  jwt: string;
}

async function fetchActiveRoles(): Promise<Role[]> {
  const { data, error } = await supabase
    .from("roles")
    .select("*")
    .eq("status", "active");

  if (error) {
    console.error("Error fetching roles:", error.message);
    throw error;
  }

  return data || [];
}

async function checkTestUserExists(roleCode: string): Promise<string | null> {
  const email = `${TEST_USER_EMAIL_PREFIX}${roleCode}@example.com`;

  const { data, error } = await supabase
    .auth
    .admin
    .listUsers();

  if (error) {
    console.error("Error checking if user exists:", error.message);
    throw error;
  }

  const user = data.users.find((u) => u.email === email);
  return user ? user.id : null;
}


async function deleteTestUser(userId: string): Promise<void> {
  const { error } = await supabase
    .auth
    .admin
    .deleteUser(userId);

  if (error) {
    console.error("Error deleting user:", error.message);
    throw error;
  }
}

async function createTestUser(
  role: Role,
): Promise<{ userId: string; email: string; password: string }> {
  const email = `${TEST_USER_EMAIL_PREFIX}${role.code}@example.com`;

  const { data, error } = await supabase
    .auth
    .admin
    .createUser({
      email,
      password: TEST_USER_PASSWORD,
      email_confirm: true,
      user_metadata: { roles:  [role]}
    });

  if (error) {
    console.error(`Error creating user for role ${role.name}:`, error.message);
    throw error;
  }

  return {
    userId: data.user.id,
    email,
    password: TEST_USER_PASSWORD,
  };
}

async function generateJWT(email: string, password: string): Promise<string> {
  const { data, error } = await supabase.auth.signInWithPassword({
    email,
    password,
  });

  if (error) {
    console.error("Error generating JWT:", error.message);
    throw error;
  }

  return data.session.access_token;
}

async function manageTestUsers() {
  try {
    console.log("Fetching active roles...");
    const roles = await fetchActiveRoles();
    console.log(`Found ${roles.length} active roles`);

    const credentials: Credentials[] = [];

    for (const role of roles) {
      console.log(`\nProcessing role: ${role.name} (${role.code})`);

      const existingUserId = await checkTestUserExists(role.code);

      if (existingUserId) {
        console.log(`Deleting existing test user for role ${role.name}...`);
        await deleteTestUser(existingUserId);
      }

      console.log(`Creating new test user for role ${role.name}...`);
      const { email, password } = await createTestUser(role);

      const jwt = await generateJWT(email, password);

      console.log("\n=== TEST USER CREDENTIALS ===");
      console.log(`Role: ${role.name}`);
      console.log(`Email: ${email}`);
      console.log(`Password: ${password}`);
      console.log(`JWT: ${jwt}`);
      console.log("============================\n");
      credentials.push({
        role: role.name,
        email,
        password,
        jwt,
      });
    }

    await writeCredentialsToJsonFile(credentials);
    console.log("Test user management completed successfully!");
  } catch (error) {
    console.error("Error managing test users:", error);
  }
}

async function writeCredentialsToJsonFile(credentials: Credentials []
) {
  const credentialsJson = JSON.stringify(credentials, null, 2);
  const credentialsFilePath = "./credentials.json";
  await Deno.writeTextFile(credentialsFilePath, credentialsJson);
}

await manageTestUsers();
