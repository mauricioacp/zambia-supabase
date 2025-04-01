// Import type definitions for Supabase Runtime APIs
import "jsr:@supabase/functions-js/edge-runtime.d.ts"

// Create Supabase client
import { createClient } from '@supabase/supabase-js'

Deno.serve(async (req) => {
  try {
    // Verify service role authentication
    const authHeader = req.headers.get('Authorization')
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return new Response(
          JSON.stringify({ error: 'Unauthorized' }),
          {
            status: 401,
            headers: { 'Content-Type': 'application/json' }
          }
      )
    }

    // Call Strapi endpoint
    const strapiUrl = Deno.env.get('STRAPI_URL')
    const strapiApiKey = Deno.env.get('STRAPI_API_KEY')

    if (!strapiUrl || !strapiApiKey) {
      throw new Error('Missing Strapi configuration')
    }

    const strapiResponse = await fetch(`${strapiUrl}/api/users`, {
      headers: {
        'Authorization': `Bearer ${strapiApiKey}`,
        'Content-Type': 'application/json'
      }
    })

    if (!strapiResponse.ok) {
      throw new Error(`Strapi API error: ${strapiResponse.statusText}`)
    }

    const strapiData = await strapiResponse.json()

    // Get the headquarters ID based on the name
    // Initialize Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL')
    const supabaseServiceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')

    if (!supabaseUrl || !supabaseServiceRoleKey) {
      throw new Error('Missing Supabase configuration')
    }

    const supabase = createClient(supabaseUrl, supabaseServiceRoleKey)

    // Process Strapi data and insert into Supabase
    let processedData = [];

    // Process each user from Strapi and map to the agreements table structure
    for (const user of strapiData.data) {
      const userData = user.attributes;

      // Get the headquarter_id based on the name
      const { data: headquarterData, error: headquarterError } = await supabase
          .from('headquarters')
          .select('id')
          .eq('name', userData.headQuarters)
          .single();

      if (headquarterError) {
        console.error(`Error finding headquarter ${userData.headQuarters}: ${headquarterError.message}`);
        continue;
      }

      // Get the role_id based on the code
      const { data: roleData, error: roleError } = await supabase
          .from('roles')
          .select('id')
          .eq('code', userData.role.toLowerCase())
          .single();

      if (roleError) {
        console.error(`Error finding role ${userData.role}: ${roleError.message}`);
        continue;
      }

      // Get country_id for the agreement
      const { data: countryData, error: countryError } = await supabase
          .from('countries')
          .select('id')
          .eq('code', userData.country)
          .single();

      if (countryError) {
        console.error(`Error finding country ${userData.country}: ${countryError.message}`);
        continue;
      }

      // Map Strapi user to Supabase agreements table
      const agreementRecord = {
        role_id: roleData.id,
        headquarter_id: headquarterData.id,
        email: userData.email,
        document_number: userData.documentNumber,
        phone: userData.phone,
        name: userData.name,
        last_name: userData.lastName,
        address: userData.address,
        volunteering_agreement: userData.volunteeringAgreement,
        ethical_document_agreement: userData.ethicalDocumentAgreement,
        mailing_agreement: userData.mailingAgreement,
        age_verification: userData.ageVerification,
        signature_data: userData.signDataPath,
        // Using createdAt and updatedAt from Strapi
        created_at: userData.createdAt,
        updated_at: userData.updatedAt,
        status: 'active' // Default status
      };

      processedData.push(agreementRecord);
    }

    // Insert the processed data into the agreements table
    const { data, error } = await supabase
        .from('agreements')
        .insert(processedData);

    if (error) {
      throw error;
    }

    return new Response(
        JSON.stringify({
          success: true,
          inserted: processedData.length,
          data
        }),
        { headers: { 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    return new Response(
        JSON.stringify({ error: error.message }),
        {
          status: 500,
          headers: { 'Content-Type': 'application/json' }
        }
    )
  }
})
