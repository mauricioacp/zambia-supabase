import { StrapiAgreement, SupabaseAgreement } from '../interfaces.ts';
import { parseBoolean, formatIsoDate } from '../utils/helpers.ts';

/**
 * @param strapiAgreement
 * @param rolesMap
 * @param headquartersMap
 * @param defaultSeasonId
 * @returns SupabaseAgreement | null
 */
export function mapStrapiToSupabase(
    strapiAgreement: StrapiAgreement,
    rolesMap: Map<string, string>,
    headquartersMap: Map<string, string>,
    defaultSeasonId: string | null
): SupabaseAgreement | null {

    if (!strapiAgreement.email || !strapiAgreement.email.trim()) {
        console.warn(`Skipping Strapi record ID ${JSON.stringify(strapiAgreement)}: Missing or empty email.`);
        return null;
    }
     const email = strapiAgreement.email.trim();

    const headquarterName = strapiAgreement.head_quarters?.trim().toLowerCase();
    let headquarterId: string | null = null;
    if (headquarterName) {
         headquarterId = headquartersMap.get(headquarterName) || null;
         if (!headquarterId) {
             console.warn(`Supabase Headquarter ID not found for Strapi name: '${strapiAgreement.head_quarters}' (Record ID: ${strapiAgreement.id}). Setting to NULL.`);
             // Decide strategy: skip, set null, or attempt to create? Setting null is often safest initially.
         }
    }

    const roleName = strapiAgreement.role?.trim().toLowerCase();
    let roleId: string | null = null;
    if (roleName) {
        roleId = rolesMap.get(roleName) || null;
         if (!roleId) {
             console.warn(`Supabase Role ID not found for Strapi name: '${strapiAgreement.role}' (Record ID: ${strapiAgreement.id}). Setting to NULL.`);
         }
    }

    const userId: string | null = null;

    const supabaseRecord: SupabaseAgreement = {
        email: email,
        document_number: strapiAgreement.document_number || null,
        phone: strapiAgreement.phone || null,
        name: strapiAgreement.name || null,
        last_name: strapiAgreement.last_name || null,
        address: strapiAgreement.address || null,
        status: 'prospect',
        role_id: roleId,
        user_id: userId,
        headquarter_id: headquarterId,
        season_id: defaultSeasonId,


        created_at: formatIsoDate(strapiAgreement.created_at),
        updated_at: formatIsoDate(strapiAgreement.updated_at),
        volunteering_agreement: parseBoolean(strapiAgreement.volunteering_agreement),
        ethical_document_agreement: parseBoolean(strapiAgreement.ethical_document_agreement),
        mailing_agreement: parseBoolean(strapiAgreement.mailing_agreement),
        age_verification: parseBoolean(strapiAgreement.age_verification),

        signature_data: null
    };

    return supabaseRecord;
}