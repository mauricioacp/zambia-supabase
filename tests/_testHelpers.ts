import { SupabaseClient, PostgrestError } from "supabase";
import credentials from "../credentials.json" with { type: "json" };
import { assert } from "jsr:@std/assert";
import { supabaseClient } from '../_environment.ts';

const roles = credentials.map((cred) => cred.role);
export type UserRoles = typeof roles[number];

export async function getClientForRole(role: UserRoles) {
    const supabase = supabaseClient;
    const { error: signOutError } = await supabase.auth.signOut();
    if (signOutError) {
        console.warn(`Warning: Failed to sign out before signing in as ${role}: ${signOutError.message}`);
    }
    const userCreds = credentials.find(cred => cred.role === role);

    if (!userCreds) {
        throw new Error(`No credentials found for role: ${role}`);
    }

    if (role !== 'anon') {
        const { error }  = await supabase.auth.signInWithPassword({
            email:  userCreds.email,
            password: userCreds.password,
        })

        if (error) {
            throw new Error(`Authentication failed for role '${role}' (email: ${userCreds.email}). Supabase error: ${error.message}`);
        }
        console.log(`signed in as ${userCreds.email} with role ${role}`)
    } else {
        const { data: { session } } = await supabase.auth.getSession();
        if (session) {
            console.warn(`Warning: Expected anon client but found active session for user: ${session.user.email}`);
            await supabase.auth.signOut();
        }
        console.log('Using anonymous client');
    }
    return supabase;
}


export async function cleanupTestData(tableName: string, identifiers: Record<string, unknown>) {
    // Ensure cleanup is done by a superadmin
    const adminClient = await getClientForRole('superadmin');

    const { error } = await adminClient
        .from(tableName)
        .delete()
        .match(identifiers); // match works like eq for single identifier

    if (error) {
        console.warn(`Warning: Failed to clean up test data from ${tableName} with identifiers ${JSON.stringify(identifiers)}: ${error.message}`);
    } else {
        console.log(`Cleaned up data from ${tableName} with identifiers ${JSON.stringify(identifiers)}`);
    }
    await adminClient.auth.signOut();
}

interface SupabaseResult<T> {
    data: T | null;
    error: PostgrestError | null;
}

/** Asserts that a Supabase operation was allowed (no error and data is not null/empty array) */
export function assertOperationAllowed<T>(result: SupabaseResult<T>, message = "Operation should be allowed but failed") {
    if (result.error) {
        console.error("Assertion Failed: Operation unexpectedly denied.", { message, error: result.error });
    }
    assert(result.error === null && (result.data !== null && (Array.isArray(result.data) ? result.data.length > 0 : true)), `${message}: ${result.error?.message || 'Returned no data.'}`);
}

/**
 * Asserts that a Supabase operation was denied.
 * Handles both explicit errors (e.g., 42501 RLS error on INSERT)
 * and implicit denials (data is null or empty array, error is null, common for SELECT/UPDATE/DELETE denials by RLS).
 */
export function assertOperationDenied<T>(result: SupabaseResult<T>, message = "Operation should be denied but was allowed") {
    const deniedWithError = result.error !== null;

    const deniedImplicitly = result.error === null && (result.data === null || (Array.isArray(result.data) && result.data.length === 0));

    if (!deniedWithError && !deniedImplicitly) {
        // If it's neither denied with an error NOR denied implicitly,
        console.error("Assertion Failed: Operation unexpectedly allowed.", { message, data: result.data, error: result.error });
    }
    assert(deniedWithError || deniedImplicitly, message);
}


export function generateUniqueId() {
    return `test_${Date.now()}_${Math.floor(Math.random() * 10000)}`;
}
