import {SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY} from "../_environment.ts";
import { createClient }  from 'https://esm.sh/@supabase/supabase-js@2.45.0';

console.log("\n🧹 Cleaning up old migrations...");
try {
  for await (const dirEntry of Deno.readDir("./migrations")) {
    if (dirEntry.isFile && dirEntry.name.endsWith(".sql")) {
      console.log(`Removing: ./migrations/${dirEntry.name}`);
      await Deno.remove(`./migrations/${dirEntry.name}`);
    }
  }
  console.log("✅ Old migrations cleaned up");
} catch (error) {
  console.log("ℹ️  No migrations directory or files to clean up");
}

const commands = [
  ["supabase", "stop"],
  ["supabase", "db", "diff", "-f", "initial_migration"],
  ["supabase", "start"],
  ["supabase", "db", "reset"],
];

for (const cmd of commands) {
  console.log(`\n$ ${cmd.join(" ")}`);
  const process = new Deno.Command(cmd[0], {
    args: cmd.slice(1),
    stdout: "inherit",
    stderr: "inherit",
    stdin: "inherit",
  });
  const { code } = await process.spawn().status;
  if (code !== 0) {
    console.error(`Command failed: ${cmd.join(" ")}`);
    Deno.exit(code);
  }
}

const lastCmd = [
  "supabase",
  "functions",
  "serve",
  "akademy-app",
  "--env-file",
  ".env.local",
];

console.log(`\n$ ${lastCmd.join(" ")} (background)`);

const backgroundProcess = new Deno.Command(lastCmd[0], {
  args: lastCmd.slice(1),
  stdout: "inherit",
  stderr: "inherit",
  stdin: "null",
}).spawn();

console.log(`Started background process with PID: ${backgroundProcess.pid}`);

console.log("Waiting for server to start...");
await new Promise((res) => setTimeout(res, 3000));

// First check if the function is healthy
const healthUrl = "http://127.0.0.1:54321/functions/v1/akademy-app/health";
console.log(`\nGET ${healthUrl} (health check)`);

const healthResponse = await fetch(healthUrl, {
    method: "GET",
    headers: {
        Accept: "application/json",
        Authorization: `Bearer ${SUPABASE_ANON_KEY}`,
    },
});

console.log("Health Status:", healthResponse.status);

if (healthResponse.status !== 200) {
    console.error("Function not healthy");
    Deno.exit(1);
}

console.log("\n🦸 Creating superadmin user...");

const supabaseUrl = 'http://127.0.0.1:54321';
const supabase = createClient(supabaseUrl, SUPABASE_SERVICE_ROLE_KEY);

try {
  const { data: role, error: roleError } = await supabase
    .from('roles')
    .select('*')
    .order('level', { ascending: false })
    .limit(1)
    .single();

  if (roleError || !role) {
    throw new Error('Could not find superadmin role');
  }

  const { data: season, error: seasonError } = await supabase
    .from('seasons')
    .select('*')
    .eq('status', 'active')
    .order('created_at', { ascending: true })
    .limit(1)
    .single();

  if (seasonError || !season) {
    throw new Error('Could not find active season');
  }

  const { data: headquarter, error: hqError } = await supabase
    .from('headquarters')
    .select('*')
    .order('created_at', { ascending: true })
    .limit(1)
    .single();

  if (hqError || !headquarter) {
    throw new Error('Could not find headquarter');
  }

  const email = 'test@test.com';
  const password = '123456789';
  
  const { data: authUser, error: authError } = await supabase.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: {
      role: role.code,
      role_level: role.level,
      role_id: role.id,
      hq_id: headquarter.id,
      season_id: season.id,
      first_name: 'Super',
      last_name: 'Admin',
      phone: '+1234567890',
    },
  });

  if (authError) {
    throw new Error(`Failed to create auth user: ${authError.message}`);
  }

  const { error: agreementError } = await supabase
    .from('agreements')
    .insert({
      name: 'Super',
      last_name: 'Admin',
      email,
      phone: '+1234567890',
      role_id: role.id,
      headquarter_id: headquarter.id,
      season_id: season.id,
      user_id: authUser.user.id,
      status: 'active',
      activation_date: new Date().toISOString(),
    });

  if (agreementError) {
    await supabase.auth.admin.deleteUser(authUser.user.id);
    throw new Error(`Failed to create agreement: ${agreementError.message}`);
  }

  console.log('✅ Superadmin user created successfully!');
  console.log(`   Email: ${email}`);
  console.log(`   Password: ${password}`);
  console.log(`   Role: ${role.name} (Level ${role.level})`);
  console.log(`   Headquarter: ${headquarter.name}`);
  console.log(`   Season: ${season.name}`);

} catch (error) {
  console.error('❌ Error creating superadmin:', error);
  Deno.exit(1);
}

console.log("\n$ deno task generate:supabase:types");
const genSupabaseTypesProcess = new Deno.Command("deno", {
    args: ["task", "generate:supabase:types"],
    stdout: "inherit",
    stderr: "inherit",
    stdin: "inherit",
});
const { code: genSupabaseTypesProcessCode } = await genSupabaseTypesProcess.spawn().status;
if (genSupabaseTypesProcessCode !== 0) {
    console.error("Error in deno generate:supabase:types");
    Deno.exit(genSupabaseTypesProcessCode);
}

console.log("\n¡Script completado!");
