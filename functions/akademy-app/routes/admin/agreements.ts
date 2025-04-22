import { corsHeaders } from "../../middleware/cors.ts";
import { supabaseAdmin } from "../../services/supabase.ts";
import { AgreementSchema } from "../../schemas/agreement.ts";

// Handle GET request for agreements
export async function getAgreements() {
  const { data: agreements, error: agreementsError } = await supabaseAdmin
    .from("agreements")
    .select("*");

  if (agreementsError) throw agreementsError;

  return new Response(JSON.stringify({ data: agreements }), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

// Handle POST request for creating an agreement
export async function createAgreement(req: Request) {
  const body = await req.json();
  const validatedData = AgreementSchema.parse(body);

  const { data: agreement, error: agreementError } = await supabaseAdmin
    .from("agreements")
    .insert(validatedData)
    .select()
    .single();

  if (agreementError) throw agreementError;

  return new Response(JSON.stringify({ data: agreement }), {
    status: 201,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

// Handle PUT request for updating an agreement
export async function updateAgreement(req: Request) {
  const body = await req.json();
  const validatedData = AgreementSchema.parse(body);

  if (!validatedData.id) {
    return new Response(JSON.stringify({ error: "Agreement ID is required" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const { data: agreement, error: agreementError } = await supabaseAdmin
    .from("agreements")
    .update(validatedData)
    .eq("id", validatedData.id)
    .select()
    .single();

  if (agreementError) throw agreementError;

  return new Response(JSON.stringify({ data: agreement }), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

// Handle DELETE request for deleting an agreement
export async function deleteAgreement(req: Request) {
  const body = await req.json();
  const { id } = body;

  if (!id) {
    return new Response(JSON.stringify({ error: "Agreement ID is required" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const { error: agreementError } = await supabaseAdmin
    .from("agreements")
    .delete()
    .eq("id", id);

  if (agreementError) throw agreementError;

  return new Response(JSON.stringify({ success: true }), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}