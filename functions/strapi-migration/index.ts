import {createClient, SupabaseClient,} from "https://esm.sh/@supabase/supabase-js@2.39.8";
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import {corsHeaders} from "../_shared/cors.ts";
import {fetchAllStrapiAgreements} from "./services/strapiService.ts";
import {preloadLookupTable,} from "./services/supabaseService.ts";
import {StrapiAgreement} from "./interfaces.ts";
import "jsr:@std/dotenv/load";

interface AppConfig {
  supabaseClient: SupabaseClient;
  strapiApiUrl: string;
  strapiToken: string;
}

const setupConfiguration = (authHeader: string): AppConfig => {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const strapiApiUrl = Deno.env.get("STRAPI_API_URL");
  const strapiToken = Deno.env.get("STRAPI_API_TOKEN");

  if (!supabaseUrl || !supabaseAnonKey) {
    throw new Error(
      "Supabase URL or Service Anon Key environment variable is missing.",
    );
  }
  if (!strapiApiUrl || !strapiToken) {
    throw new Error(
      "Strapi API URL or Token environment variable is missing.",
    );
  }

  const supabaseClient = createClient(supabaseUrl, supabaseAnonKey, {
    global: {
      headers: { Authorization: authHeader! },
    },
  });

  console.log("Environment variables loaded and Supabase client created.");

  return {
    supabaseClient,
    strapiApiUrl,
    strapiToken,
  };
};

Deno.serve(async (req) => {
  try {
    if (req.method === "OPTIONS") {
      return new Response("ok", { headers: corsHeaders });
    }

    const authHeader = req.headers.get("Authorization");

    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "No autorizado" }),
        { status: 401 },
      );
    }

    const { supabaseClient, strapiToken, strapiApiUrl } = setupConfiguration(
      authHeader,
    );

    const { strapiAgreements, headquartersSet, rolesSet } =
      await connectToStrapi(strapiToken, strapiApiUrl);

    const { rolesMap, headquartersMap } = await preloadSupabaseTableRecords(
      supabaseClient,
    );

    await matchData(
      strapiAgreements,
      headquartersSet,
      rolesSet,
      rolesMap,
      headquartersMap,
    );

    return new Response(JSON.stringify({ "message": "Connected to Strapi." }), {
      headers: { "Content-Type": "application/json" },
      status: 200,
    });
  } catch (error: unknown) {
    return new Response(String(error instanceof Error ? error.message : error), {status: 500});
  }
});

const matchData = async (
  strapiAgreements: StrapiAgreement[],
  headquartersSet: Set<string>,
  rolesSet: Set<string>,
  rolesMap: Map<string, string>,
  headquartersMap: Map<string, string>,
) => {
  const mergedHeadquarters = new Map<string, string | null>();
  headquartersSet.forEach((a) => {
    mergedHeadquarters.set(a, headquartersMap.get(a) || null);
  });
  console.log(mergedHeadquarters);

  const mergedRoles = new Map<string, string | null>();
  rolesSet.forEach((a) => {
    mergedRoles.set(a, rolesMap.get(a) || null);
  });

  console.log(mergedRoles);
};

const connectToStrapi = async (strapiToken: string, strapiApiUrl: string) => {
  const strapiAgreements: StrapiAgreement[] = await fetchAllStrapiAgreements(
    strapiApiUrl,
    strapiToken,
  );

  const rolesSet = new Set<string>();
  const headquartersSet = new Set<string>();
  strapiAgreements.forEach((agreement) => {
    if (agreement.role) {
      rolesSet.add(agreement.role.trim().toLowerCase());
    }
    if (agreement.headQuarters) {
      headquartersSet.add(agreement.headQuarters.trim().toLowerCase());
    }
  });

  console.log(`Roles size in strapi: ${rolesSet.size}`);
  console.log(`Headquarters size in strapi: ${headquartersSet.size}`);
  return {
    rolesSet,
    headquartersSet,
    strapiAgreements,
  };
};

const preloadSupabaseTableRecords = async (supabaseClient: SupabaseClient) => {
  const [rolesMap, headquartersMap] = await Promise.all([
    preloadLookupTable(supabaseClient, "roles", "name"),
    preloadLookupTable(supabaseClient, "headquarters", "name"),
  ]);
  return {
    rolesMap,
    headquartersMap,
  };
};
