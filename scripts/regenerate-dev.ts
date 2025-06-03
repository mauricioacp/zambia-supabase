/**
 * Complete Development Environment Reset Script
 * 
 * This script performs a full reset of the local development environment:
 * 1. Cleans up old migration files from /migrations directory
 * 2. Stops and restarts Supabase stack with fresh database
 * 3. Applies schema from /schemas directory
 * 4. Starts Edge Functions server
 * 5. Invokes Akademy migration endpoint to import Strapi data
 * 6. Creates new migration file capturing the migrated data state
 * 7. Generates test users and TypeScript types
 * 
 * Usage: deno task generate:dev:environment
 */

import {SUPABASE_ANON_KEY, SUPER_PASSWORD} from "../_environment.ts";

// Clean up old migrations first
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

// Run the last command in the background
const lastCmd = [
  "supabase",
  "functions",
  "serve",
  "--env-file",
  "./functions/.env",
  "--debug",
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
const healthUrl = "http://127.0.0.1:54321/functions/v1/akademy/health";
console.log(`\nGET ${healthUrl} (health check)`);

const healthResponse = await fetch(healthUrl, {
    method: "GET",
    headers: {
        Accept: "application/json",
    },
});

console.log("Health Status:", healthResponse.status);

if (healthResponse.status !== 200) {
    console.error("Function not healthy, skipping migration");
    Deno.exit(1);
}

// Now perform the actual migration
const migrationUrl = "http://127.0.0.1:54321/functions/v1/akademy/migrate";

console.log(`\nPOST ${migrationUrl} (Strapi migration)`);

if (!SUPER_PASSWORD) {
    console.warn("\nWARNING: SUPER_PASSWORD environment variable is not set.");
    console.warn("Migration will be skipped.");
} else {
    const migrationResponse = await fetch(migrationUrl, {
        method: "POST",
        headers: {
            Accept: "application/json",
            Authorization: `Bearer ${SUPABASE_ANON_KEY}`,
            "x-super-password": SUPER_PASSWORD,
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
}

const response = healthResponse;

console.log("Status:", response.status);

// Generate a new migration with the current database state (including migrated data)
console.log("\n📦 Creating migration with current database state...");
const migrationCmd = ["supabase", "db", "diff", "-f", "post_strapi_migration"];
console.log(`\n$ ${migrationCmd.join(" ")}`);

const migrationProcess = new Deno.Command(migrationCmd[0], {
    args: migrationCmd.slice(1),
    stdout: "inherit",
    stderr: "inherit",
    stdin: "inherit",
});
const { code: migrationCode } = await migrationProcess.spawn().status;
if (migrationCode !== 0) {
    console.warn("⚠️  Migration generation failed, but continuing...");
} else {
    console.log("✅ New migration created with Strapi data");
}

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
