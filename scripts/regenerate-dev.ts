import {SUPABASE_ANON_KEY, level95Token} from "../_environment.ts";

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
        Authorization: `Bearer ${level95Token || SUPABASE_ANON_KEY}`,
    },
});

console.log("Health Status:", healthResponse.status);

if (healthResponse.status !== 200) {
    console.error("Function not healthy, skipping migration");
    Deno.exit(1);
}

const migrationUrl = "http://127.0.0.1:54321/functions/v1/akademy-app/migrate";

console.log(`\nPOST ${migrationUrl} (Strapi migration)`);

const migrationResponse = await fetch(migrationUrl, {
    method: "POST",
    headers: {
        Accept: "application/json",
        Authorization: `Bearer ${level95Token || SUPABASE_ANON_KEY}`,
        "Content-Type": "application/json",
    },
});

console.log("Migration Status:", migrationResponse.status);

if (migrationResponse.ok) {
    const migrationData = await migrationResponse.json();
    console.log("Migration Success:");
    console.log("- Records from Strapi:", migrationData.statistics?.strapiCount || 0);
    console.log("- Records inserted:", migrationData.statistics?.supabaseInserted || 0);
    console.log("- Records excluded:", migrationData.statistics?.excludedCount || 0);
} else {
    const errorData = await migrationResponse.text();
    console.error("Migration failed:", errorData);
}

const response = healthResponse;

console.log("Status:", response.status);

console.log("\n$ deno task generate:test:users");
const genProcess = new Deno.Command("deno", {
    args: ["task", "generate:test:users"],
    stdout: "inherit",
    stderr: "inherit",
    stdin: "inherit",
});
const { code: genCode } = await genProcess.spawn().status;
if (genCode !== 0) {
    console.error("Error in deno task generate:test:users");
    Deno.exit(genCode);
}

console.log("\n$ deno task generate:supabase:types");
const genSupabaseTypesProcess = new Deno.Command("deno", {
    args: ["task", "generate:supabase:types"],
    stdout: "inherit",
    stderr: "inherit",
    stdin: "inherit",
});
const { code: genSupabaseTypesProcessCode } = await genSupabaseTypesProcess.spawn().status;
if (genCode !== 0) {
    console.error("Error in deno generate:supabase:types");
    Deno.exit(genSupabaseTypesProcessCode);
}

console.log("\n¡Script completado!");
