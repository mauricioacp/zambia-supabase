import {EXTERNAL_KEY, SUPER_PASSWORD} from "../_environment.ts";

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
  ".\\functions\\.env",
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

const url = "http://127.0.0.1:54321/functions/v1/strapi-migration";

console.log(`\nGET ${url}`);

if (!SUPER_PASSWORD) {
    console.warn("\nWARNING: SUPER_PASSWORD environment variable is not set.");
}

const response = await fetch(url, {
    method: "GET",
    headers: {
        Accept: "application/json",
        Authorization: `Bearer ${EXTERNAL_KEY}`,
        "x-super-password": SUPER_PASSWORD || "",
    },
});

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
