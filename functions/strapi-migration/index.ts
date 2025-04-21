import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import {
  createClient,
  SupabaseClient,
} from "https://esm.sh/@supabase/supabase-js@2.39.8";
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { corsHeaders } from "../_shared/cors.ts";
import { fetchAllStrapiAgreements } from "./services/strapiService.ts";
import {
  insertAgreementsBatch,
  preloadLookupTable,
} from "./services/supabaseService.ts";
import { mapStrapiToSupabase } from "./services/mappingService.ts";
import { StrapiAgreement, SupabaseAgreement } from "./interfaces.ts";
import "jsr:@std/dotenv/load";

interface AppConfig {
  supabaseClient: SupabaseClient;
  strapiApiUrl: string;
  strapiToken: string;
}

const setupConfiguration = (): AppConfig => {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const strapiApiUrl = Deno.env.get("STRAPI_API_URL");
  const strapiToken = Deno.env.get("STRAPI_API_TOKEN");

  if (!supabaseUrl || !supabaseServiceRoleKey) {
    throw new Error(
      "Supabase URL or Service Role Key environment variable is missing.",
    );
  }
  if (!strapiApiUrl || !strapiToken) {
    throw new Error(
      "Strapi API URL or Token environment variable is missing.",
    );
  }

  const supabaseClient = createClient(supabaseUrl, supabaseServiceRoleKey);

  console.log("Environment variables loaded and Supabase client created.");

  return {
    supabaseClient,
    strapiApiUrl,
    strapiToken,
  };
};

Deno.serve(async (req) => {
  try {
    const { supabaseClient, strapiToken, strapiApiUrl } = setupConfiguration();

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
  } catch (error) {
    return new Response(String(error?.message ?? error), { status: 500 });
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
