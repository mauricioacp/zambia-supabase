import * as path from "@std/path";
import { ensureDir } from "@std/fs";

const rootDir = path.dirname(path.dirname(path.fromFileUrl(import.meta.url)));
const typesDir = path.join(rootDir, "types");
const typesFile = path.join(typesDir, "supabase.type.ts");

try {
    await ensureDir(typesDir);
    console.log(`Ensured directory exists: ${typesDir}`);

    const command = new Deno.Command("npx", {
        args: ["supabase", "gen", "types", "typescript", "--local"],
        stdout: "piped",
        stderr: "piped",
    });

    console.log("Generating Supabase types...");
    const { code, stdout, stderr } = await command.output();

    const outputText = new TextDecoder().decode(stdout);
    const errorText = new TextDecoder().decode(stderr);

    if (code === 0) {
        await Deno.writeTextFile(typesFile, outputText);
        console.log(`Supabase types generated successfully at: ${typesFile}`);
        if (errorText) {
             console.warn("Supabase CLI stderr:", errorText);
        }
    } else {
        console.error(`Error generating Supabase types (Exit code: ${code}):`);
        console.error("stdout:", outputText);
        console.error("stderr:", errorText);
        Deno.exit(1);
    }

} catch (error) {
    console.error("Failed to generate Supabase types:", error);
    Deno.exit(1);
}
