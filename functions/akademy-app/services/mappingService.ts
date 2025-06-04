import { SupabaseClient } from "@supabase/supabase-js";
import { StrapiAgreement, SupabaseAgreement } from "../interfaces.ts";
import {
  formatIsoDate,
  isCreatedMoreThanOneYearAgo,
} from "../utils/helpers.ts";
import { getSeasonIdByHeadQuarterId } from "./supabaseService.ts";
import {
  normalizeHeadquarters,
  normalizeRole,
  normalizeText,
} from "../utils/dataNormalization.ts";
import { checkExistingAgreementsInBatches } from "./agreementChecks.ts";

export async function matchData(
  strapiAgreements: StrapiAgreement[],
  headquartersSet: Set<string>,
  rolesSet: Set<string>,
  rolesMap: Map<string, string>,
  headquartersMap: Map<string, string>,
  supabaseClient: SupabaseClient,
) {
  const STUDENT_ROLE_ID = rolesMap.get("alumno");
  let agreementStatus = "prospect";

  const mergedHeadquarters = new Map<string, string | null>();
  headquartersSet.forEach((headquarters) => {
    const normalizedHeadquarters = normalizeHeadquarters(headquarters);
    mergedHeadquarters.set(
      normalizeText(headquarters),
      headquartersMap.get(normalizedHeadquarters) || null,
    );
  });

  const mergedRoles = new Map<string, string | null>();
  rolesSet.forEach((role) => {
    const normalizedRole = normalizeRole(role);
    mergedRoles.set(
      normalizeText(role),
      rolesMap.get(normalizedRole) || null,
    );
  });

  console.log("Merged Headquarters Map Size:", mergedHeadquarters.size);
  console.log("Merged Roles Map size:", mergedRoles.size);

  const supabaseAgreements: SupabaseAgreement[] = [];

  for (const strapiAgreement of strapiAgreements) {
    const normalizedHeadquarters = normalizeText(
      strapiAgreement.headQuarters,
    );
    const normalizedRole = normalizeText(strapiAgreement.role);
    const hqFromMerged = mergedHeadquarters.get(normalizedHeadquarters);
    
    if (!hqFromMerged) {
      const normalizedHqForMapping = normalizeHeadquarters(strapiAgreement.headQuarters);
      const mappedHeadquarters = headquartersMap.get(normalizedHqForMapping);
      
      if (!mappedHeadquarters) {
        console.error(`[ERROR] Agreement ID ${strapiAgreement.id}: Headquarters "${strapiAgreement.headQuarters}" not found in mapping`);
        strapiAgreement.headQuarters = null!;
      } else {
        strapiAgreement.headQuarters = mappedHeadquarters;
      }
    } else {
      strapiAgreement.headQuarters = hqFromMerged;
    }

    const roleFromMerged = mergedRoles.get(normalizedRole);
    
    if (!roleFromMerged) {
      const normalizedRoleForMapping = normalizeRole(strapiAgreement.role);
      const mappedRole = rolesMap.get(normalizedRoleForMapping);
      
      if (!mappedRole) {
        console.error(`[ERROR] Agreement ID ${strapiAgreement.id}: Role "${strapiAgreement.role}" not found in mapping`);
        strapiAgreement.role = null!;
      } else {
        strapiAgreement.role = mappedRole;
      }
    } else {
      strapiAgreement.role = roleFromMerged;
    }

    if (!strapiAgreement.headQuarters || !strapiAgreement.role) {
      console.error(
        `[ERROR] Agreement ID ${strapiAgreement.id}: Missing mapping - HQ: ${strapiAgreement.headQuarters || 'null'}, Role: ${strapiAgreement.role || 'null'}`,
      );
    }

    if (strapiAgreement.role === STUDENT_ROLE_ID) {
      agreementStatus = isCreatedMoreThanOneYearAgo(strapiAgreement.createdAt)
        ? "graduated"
        : "prospect";
    } else {
      agreementStatus = "prospect";
    }

    const seasonId = await getSeasonIdByHeadQuarterId(
      strapiAgreement.headQuarters,
      supabaseClient,
    );

    supabaseAgreements.push({
      address: strapiAgreement.address,
      email: strapiAgreement.email,
      document_number: strapiAgreement.documentNumber,
      phone: strapiAgreement.phone,
      created_at: formatIsoDate(strapiAgreement.createdAt),
      updated_at: formatIsoDate(strapiAgreement.updatedAt),
      name: strapiAgreement.name,
      last_name: strapiAgreement.lastName,
      volunteering_agreement: strapiAgreement.volunteeringAgreement,
      ethical_document_agreement: strapiAgreement.ethicalDocumentAgreement,
      mailing_agreement: strapiAgreement.mailingAgreement,
      age_verification: strapiAgreement.ageVerification,
      signature_data: strapiAgreement.signDataPath,
      role_id: strapiAgreement.role,
      headquarter_id: strapiAgreement.headQuarters,
      status: agreementStatus,
      user_id: null,
      season_id: seasonId,
    });
  }

  const strapiCount = strapiAgreements.length;
  let existingAgreements: {
    email: string;
    document_number: string;
  }[] = [];

  if (supabaseAgreements.length > 0) {
    const emails = supabaseAgreements.map((agreement) => agreement.email);
    const documentNumbers = supabaseAgreements.map((agreement) =>
      agreement.document_number
    );

    existingAgreements = await checkExistingAgreementsInBatches(
      supabaseClient,
      emails,
      documentNumbers,
      50,
    );
  }

  const existingEmails = new Set(
    existingAgreements.map((a) => a.email.toLowerCase()),
  );
  const existingDocNumbers = new Set(
    existingAgreements.map((a) => a.document_number.toLowerCase()),
  );

  const filteredAgreements = supabaseAgreements.filter((agreement) => {
    const emailExists = existingEmails.has(agreement.email.toLowerCase());
    const docNumberExists = existingDocNumbers.has(
      agreement.document_number.toLowerCase(),
    );
    return !emailExists && !docNumberExists;
  });

  const excludedCount = supabaseAgreements.length - filteredAgreements.length;

  console.log(
    `Found ${
      existingAgreements?.length || 0
    } existing agreements with matching email or document number`,
  );
  console.log(`Excluded ${excludedCount} agreements from insertion`);

  try {
    const agreementsToInsert = filteredAgreements;

    const { data, error, count } = await supabaseClient
      .from("agreements")
      .insert(agreementsToInsert, {
        count: "exact",
        defaultToNull: true,
      }).select();

    if (error) {
      throw error;
    }

    return {
      success: true,
      message: "Datos insertados correctamente",
      statistics: {
        strapiCount,
        supabaseInserted: count,
        transformedCount: supabaseAgreements.length,
        excludedCount,
        excludedReason:
          "Agreements with the same email or document number already exist in the database",
        difference: strapiCount - (count ?? 0),
      },
      data: data,
    };
  } catch (error) {
    console.error("Error en la inserción:", error);
    return {
      success: false,
      message: "Error al insertar los datos",
      statistics: {
        strapiCount,
        transformedCount: supabaseAgreements.length,
        supabaseInserted: 0,
        excludedCount,
        excludedReason:
          "Agreements with the same email or document number already exist in the database",
        difference: strapiCount,
      },
      error: error instanceof Error ? error.message : JSON.stringify(error),
    };
  }
}
