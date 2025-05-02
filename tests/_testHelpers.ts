import { SupabaseClient, PostgrestError } from "supabase";
import credentials from "../credentials.json" with { type: "json" };
import { assert } from "jsr:@std/assert";
import { supabaseClient } from '../_environment.ts';

const roles = credentials.map((cred) => cred.role);
export type UserRoles = typeof roles[number];

export async function getClientForRole(role: UserRoles) {
    const supabase = supabaseClient;
    await supabase.auth.signOut();

    const userCreds = credentials.find(cred => cred.role === role);

    if (!userCreds) {
        throw new Error(`No credentials found for role: ${role}`);
    }

    const {error }  = await supabase.auth.signInWithPassword({
        email:  userCreds.email,
        password: userCreds.password,
    })

    if (error) {
        throw new Error(`Authentication failed for role '${role}' (email: ${userCreds.email}). Supabase error: ${error.message}`);
    }

    console.log(`signed in as ${userCreds.email} with role ${role}`)

    return supabase;
}


export async function cleanupTestData(tableName: string, identifiers: Record<string, unknown>) {
    const adminClient = await getClientForRole('superadmin');

    const { error } = await adminClient
        .from(tableName)
        .delete()
        .match(identifiers);

    if (error) {
        console.warn(`Warning: Failed to clean up test data from ${tableName}: ${error.message}`);
    }
}

interface SupabaseResult<T> {
    data: T | null;
    error: PostgrestError | null;
}

/** Asserts that a Supabase operation was allowed (no error) */
export function assertOperationAllowed<T>(result: SupabaseResult<T>, message = "Operation should be allowed but failed") {
    if (result.error) {
        console.error("Assertion Failed: Operation unexpectedly denied.", { message, error: result.error });
    }
    assert(result.error === null, `${message}: ${result.error?.message}`);
}

/** Asserts that a Supabase operation was denied (an error occurred) */
export function assertOperationDenied<T>(result: SupabaseResult<T>, message = "Operation should be denied but was allowed") {
     if (!result.error) {
        console.error("Assertion Failed: Operation unexpectedly allowed.", { message, data: result.data });
    }
    assert(result.error !== null, message);
}

export function generateUniqueId() {
    return `test_${Date.now()}_${Math.floor(Math.random() * 10000)}`;
}

interface RlsCheckResults {
    metadata: Record<string, unknown> | null;
    metadataError: Error | null;
    roleLevel: number | null;
    roleLevelError: Error | null;
    isSuperAdmin: boolean | null;
    isSuperAdminError: Error | null;
}

export async function checkRlsFunctions(client: SupabaseClient): Promise<RlsCheckResults> {
    const results: RlsCheckResults = {
        metadata: null,
        metadataError: null,
        roleLevel: null,
        roleLevelError: null,
        isSuperAdmin: null,
        isSuperAdminError: null,
    };

    try {
        const { data, error } = await client.auth.getUser();
        results.metadata = data && data.user && data.user.user_metadata ? data.user.user_metadata : null;
        results.metadataError = error;
    } catch (e) {
        results.metadataError = e instanceof Error ? e : new Error('Unknown error getting user metadata');
    }

    try {
        const { data, error } = await client.rpc('fn_get_current_role_level');
        results.roleLevel = typeof data === 'number' ? data : null;
        results.roleLevelError = error ? new Error(error.message) : null;
    } catch (e) {
        results.roleLevelError = e instanceof Error ? e : new Error('Unknown error calling fn_get_current_role_level');
    }

    try {
        const { data, error } = await client.rpc('fn_is_super_admin');
        results.isSuperAdmin = typeof data === 'boolean' ? data : null;
        results.isSuperAdminError = error ? new Error(error.message) : null;
    } catch (e) {
        results.isSuperAdminError = e instanceof Error ? e : new Error('Unknown error calling fn_is_super_admin');
    }

    return results;
}

export function wait(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
}
