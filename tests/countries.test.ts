import {
    assert,
    assertEquals,
    assertExists
} from "@std/assert";

import {
    getClientForRole,
    generateUniqueId,
    assertOperationAllowed,
    assertOperationDenied,
} from "./_testHelpers.ts";
import { supabaseClient } from "../_environment.ts";

const createdIds: Record<string, string | undefined> = {};

Deno.test("countries - RLS and CRUD operations by role", { sanitizeOps: false, sanitizeResources: false }, async (t) => {
    const testCountryBase = {
        name: `Test Country ${generateUniqueId()}`,
        code: `TC${Math.floor(Math.random() * 10000)}`,
        status: 'active'
    };
    let studentTestCountryId: string | undefined;

    try {
        // ==========================================
        // 1. Superadmin Role Tests
        // ==========================================
        await t.step("Superadmin: CRUD operations", async (t) => {
            const superadminClient = await getClientForRole("superadmin");
            let countryId: string | undefined;
            const superAdminTestCountry = { ...testCountryBase, name: `Superadmin Test ${generateUniqueId()}`, code: `SA${generateUniqueId().slice(-4)}` };

            await t.step("can create countries", async () => {
                const { data, error } = await superadminClient
                    .from("countries")
                    .insert([superAdminTestCountry])
                    .select();

                assertOperationAllowed({ data, error }, "Superadmin should be allowed to create");
                assertExists(data);
                assertEquals(data[0].name, superAdminTestCountry.name);
                countryId = data[0].id;
                createdIds.superadmin = countryId; // Track if needed elsewhere, otherwise cleanup uses its own query
            });

            if (!countryId) {
                throw new Error("Superadmin test country creation failed, cannot proceed.");
            }

            await t.step("can read created country", async () => {
                const { data, error } = await superadminClient.from("countries").select().eq("id", countryId!);
                assertOperationAllowed({ data, error }, "Superadmin should be allowed to read");
                assertExists(data);
                assertEquals(data.length, 1);
                assertEquals(data[0].name, superAdminTestCountry.name);
            });

            await t.step("can update countries", async () => {
                const updatedName = `Updated Country SA ${generateUniqueId()}`;
                const { data, error } = await superadminClient.from("countries").update({ name: updatedName }).eq("id", countryId!).select();
                assertOperationAllowed({ data, error }, "Superadmin should be allowed to update");
                assertExists(data);
                assertEquals(data.length, 1);
                assertEquals(data[0].name, updatedName);
            });

            // Delete step now part of cleanup in finally block for this item
            // await t.step("can delete countries", ...);
        });

        console.log("Signing out superadmin...");
        await supabaseClient.auth.signOut();

        // ==========================================
        // Setup data for non-superadmin tests
        // ==========================================
        await t.step("Setup: Create data for student/anon tests", async () => {
            const setupClient = await getClientForRole("superadmin"); // Need superadmin to create
            const studentTestCountry = { ...testCountryBase, name: `Student Test ${generateUniqueId()}`, code: `ST${generateUniqueId().slice(-4)}` };
            const { data, error } = await setupClient.from("countries").insert([studentTestCountry]).select();

            if (error || !data || data.length === 0) {
                throw new Error(`Failed to create test data for student/anon tests: ${error?.message}`);
            }
            studentTestCountryId = data[0].id; // Assign to the outer variable
            createdIds.student_anon_setup = studentTestCountryId;
            console.log(`Created country ${studentTestCountryId} for student/anon tests.`);
            await setupClient.auth.signOut();
        });

        if (!studentTestCountryId) {
             throw new Error("Setup for student/anon tests failed, cannot proceed.");
        }

        // ==========================================
        // 2. Authenticated Non-Superadmin (Student) Tests
        // ==========================================
        await t.step("Student: CRUD operations", async (t) => {
            const studentClient = await getClientForRole("student");

            await t.step("can read countries", async () => {
                const { data, error } = await studentClient.from("countries").select().eq("id", studentTestCountryId!);
                assertOperationAllowed({ data, error }, "Student should be allowed to read countries");
                assertExists(data);
                assertEquals(data.length, 1);
            });

            await t.step("cannot create countries", async () => {
                const studentCreateAttempt = { ...testCountryBase, name: `Student Create ${generateUniqueId()}`, code: `SC${generateUniqueId().slice(-4)}` };
                const { data, error } = await studentClient.from("countries").insert([studentCreateAttempt]).select();
                console.log('data ', data, 'error ', error)
                assertOperationDenied({ data, error }, "Student should NOT be allowed to create countries");
            });

            await t.step("cannot update countries", async () => {
                const { data, error } = await studentClient.from("countries").update({ name: `Updated by Student ${generateUniqueId()}` }).eq("id", studentTestCountryId!).select();;
                console.log('data ', data, 'error ', error)
                assertOperationDenied({ data, error }, "Student should NOT be allowed to update countries");
            });

            await t.step("cannot delete countries", async () => {
                const { error } = await studentClient.from("countries").delete().eq("id", studentTestCountryId!);
                console.log( 'error ', error)
                assertOperationDenied({ data: null, error }, "Student should NOT be allowed to delete countries");
            });
        });

        console.log("Signing out student...");
        await supabaseClient.auth.signOut();

        // ==========================================
        // 3. Anonymous User Tests
        // ==========================================
        await t.step("Anonymous: CRUD operations", async (t) => {
            const anonClient = supabaseClient;
            const session = await anonClient.auth.getSession();
            assert(session.data.session === null, "Client should be anonymous/signed out");

            await t.step("cannot read countries", async () => {
                const { data, error } = await anonClient.from("countries").select().eq("id", studentTestCountryId!);
                console.log('data ', data, 'error ', error)
                assertOperationDenied({ data, error }, "Anonymous user should NOT be allowed to read countries");
            });

            await t.step("cannot create countries", async () => {
                const anonCreateAttempt = { ...testCountryBase, name: `Anon Create ${generateUniqueId()}`, code: `AC${generateUniqueId().slice(-4)}` };
                const { data, error } = await anonClient.from("countries").insert([anonCreateAttempt]).select();
                console.log('data ', data, 'error ', error)
                assertOperationDenied({ data, error }, "Anonymous user should NOT be allowed to create countries");
            });

            await t.step("cannot update countries", async () => {
                const { data, error } = await anonClient.from("countries").update({ name: `Updated by Anon ${generateUniqueId()}` }).eq("id", studentTestCountryId!).select();
                console.log('data ', data, 'error ', error)
                assertOperationDenied({ data, error }, "Anonymous user should NOT be allowed to update countries");
            });

            await t.step("cannot delete countries", async () => {
                const { error } = await anonClient.from("countries").delete().eq("id", studentTestCountryId!);
                console.log( 'error ', error)
                assertOperationDenied({ data: null, error }, "Anonymous user should NOT be allowed to delete countries");
            });
        });

    } finally {
        // ==========================================
        // 4. Cleanup (runs even if tests fail)
        // ==========================================
        console.log("Running cleanup for RLS and CRUD tests...");
        try {
            const cleanupClient = await getClientForRole("superadmin");
            if (studentTestCountryId) {
                console.log(`Attempting cleanup for country ID: ${studentTestCountryId}`);
                const { error } = await cleanupClient.from("countries").delete().eq("id", studentTestCountryId);
                if (error) {
                    console.error(`Cleanup failed for country ${studentTestCountryId}:`, error.message);
                } else {
                    console.log(`Cleaned up country ${studentTestCountryId}`);
                }
            }
            // Cleanup any item created directly by superadmin test if its ID was tracked
            if (createdIds.superadmin) {
                 console.log(`Attempting cleanup for superadmin created country ID: ${createdIds.superadmin}`);
                 const { error } = await cleanupClient.from("countries").delete().eq("id", createdIds.superadmin);
                 if (error) console.error(`Cleanup failed for superadmin country ${createdIds.superadmin}:`, error.message);
                 else console.log(`Cleaned up superadmin country ${createdIds.superadmin}`);
            }
            await cleanupClient.auth.signOut();
        } catch (cleanupError) {
            console.error("Error during cleanup phase:", cleanupError);
        }
        console.log("Cleanup finished for RLS and CRUD tests.");
    }
});


Deno.test("countries - Constraint and trigger tests", { sanitizeOps: false, sanitizeResources: false }, async (t) => {
    let createdIdForConstraintTest: string | undefined;
    let activeStatusTestId: string | undefined;
    let inactiveStatusTestId: string | undefined;
    const superadminClient = await getClientForRole("superadmin");

    try {
        const uniqueCodeBase = `UQC${generateUniqueId().slice(-5)}`;
        const countryForUniqueTest = { name: `Unique Test ${generateUniqueId()}`, code: uniqueCodeBase, status: 'active' };

        await t.step("Setup: Create initial country for constraint tests", async () => {
            const { data, error } = await superadminClient.from("countries").insert(countryForUniqueTest).select('id').single();
            assertOperationAllowed({data, error}, "Superadmin failed to create initial country for constraint test");
            assertExists(data?.id);
            createdIdForConstraintTest = data.id;
        });

        if (!createdIdForConstraintTest) {
            throw new Error("Setup for constraint tests failed.");
        }

        await t.step("unique code constraint", async () => {
            const { data, error } = await superadminClient
                .from("countries")
                .insert([{ ...countryForUniqueTest, name: `Duplicate Code Test ${generateUniqueId()}` }]) // Use same code
                .select();

            assert(error !== null, "Insert with duplicate code should fail");
            assert(error?.message.includes('duplicate key value violates unique constraint'), "Error message should indicate unique constraint violation");
        });

        await t.step("status check constraint (active)", async () => {
            const { data, error } = await superadminClient
                .from("countries")
                .insert([{ name: `Active Status Test ${generateUniqueId()}`, code: `AS${generateUniqueId().slice(-4)}`, status: 'active' }])
                .select('id');
            assertOperationAllowed({data, error}, "Insert with active status should succeed");
            if (data && data.length > 0 && data[0].id) {
                 activeStatusTestId = data[0].id; // Track ID for cleanup
            }
        });

         await t.step("status check constraint (inactive)", async () => {
            const { data, error } = await superadminClient
                .from("countries")
                .insert([{ name: `Inactive Status Test ${generateUniqueId()}`, code: `IS${generateUniqueId().slice(-4)}`, status: 'inactive' }])
                .select('id');
            assertOperationAllowed({data, error}, "Insert with inactive status should succeed");
             if (data && data.length > 0 && data[0].id) {
                inactiveStatusTestId = data[0].id; // Track ID for cleanup
            }
        });

        await t.step("status check constraint (invalid)", async () => {
            const { data, error } = await superadminClient
                .from("countries")
                .insert([{ name: `Invalid Status Test ${generateUniqueId()}`, code: `IVS${generateUniqueId().slice(-4)}`, status: 'invalid_status' }])
                .select();
            assert(error !== null, "Insert with invalid status should fail");
            assert(error?.message.includes('violates check constraint'), "Error message should indicate check constraint violation");
        });

        await t.step("updated_at trigger on update", async () => {
            const initialRead = await superadminClient.from("countries").select('updated_at').eq('id', createdIdForConstraintTest!).single();
            const initialTimestamp = initialRead.data?.updated_at;
            assertExists(initialTimestamp, "Could not read initial timestamp");

            await new Promise(resolve => setTimeout(resolve, 50));

            const { data, error } = await superadminClient
                .from("countries")
                .update({ name: `Trigger Test Update ${generateUniqueId()}` })
                .eq("id", createdIdForConstraintTest!)
                .select('updated_at')
                .single();

            assertOperationAllowed({data, error}, "Update for trigger test failed");
            assertExists(data?.updated_at, "Updated timestamp missing");
            assert(new Date(data.updated_at) > new Date(initialTimestamp), "updated_at timestamp did not increase after update");
        });

    } finally {
        // Cleanup for constraint tests
        console.log("Running cleanup for Constraint tests...");
        try {
            // No need to sign in again if superadminClient is still valid
             if (createdIdForConstraintTest) {
                 await superadminClient.from("countries").delete().eq("id", createdIdForConstraintTest);
                 console.log(`Cleaned up constraint test base country ${createdIdForConstraintTest}`);
             }
             if (activeStatusTestId) {
                 await superadminClient.from("countries").delete().eq("id", activeStatusTestId);
                 console.log(`Cleaned up active status test country ${activeStatusTestId}`);
             }
              if (inactiveStatusTestId) {
                 await superadminClient.from("countries").delete().eq("id", inactiveStatusTestId);
                 console.log(`Cleaned up inactive status test country ${inactiveStatusTestId}`);
             }
            await superadminClient.auth.signOut();
        } catch (cleanupError) {
             console.error("Error during Constraint test cleanup:", cleanupError);
        }
         console.log("Cleanup finished for Constraint tests.");
    }
});


Deno.test("countries - Search and filter capabilities", { sanitizeOps: false, sanitizeResources: false }, async (t) => {
    let createdIdsForSearch: string[] = [];
    const superadminClient = await getClientForRole("superadmin");

    try {
        const searchBaseCode = `SF${generateUniqueId().slice(-5)}`;
        const countriesToCreate = [
            { name: `SearchFilter One ${generateUniqueId()}`, code: `${searchBaseCode}A`, status: 'active' },
            { name: `SearchFilter Two ${generateUniqueId()}`, code: `${searchBaseCode}B`, status: 'inactive' },
            { name: `Another One ${generateUniqueId()}`, code: `AO${generateUniqueId().slice(-4)}`, status: 'active' }
        ];

        await t.step("Setup: Create data for search/filter tests", async () => {
            const { data, error } = await superadminClient.from("countries").insert(countriesToCreate).select('id');
            assertOperationAllowed({data, error}, "Failed to create search/filter test data");
            createdIdsForSearch = data?.map(d => d.id) || [];
            assertEquals(createdIdsForSearch.length, countriesToCreate.length, "Did not create expected number of countries for search test");
            console.log("Created search/filter test data");
        });

        if (createdIdsForSearch.length !== countriesToCreate.length) {
            throw new Error("Setup for search/filter tests failed");
        }

        await t.step("search by name (partial match)", async () => {
            const { data, error } = await superadminClient
                .from("countries")
                .select()
                .ilike('name', '%searchfilter%'); // Case-insensitive partial match
            assertOperationAllowed({data, error}, "Search by name failed");
            assertExists(data);
            assertEquals(data.length, 2, "Should find 2 countries with 'searchfilter' in name");
        });

        await t.step("filter by code (exact match)", async () => {
            const targetCode = `${searchBaseCode}A`;
            const { data, error } = await superadminClient
                .from("countries")
                .select()
                .eq('code', targetCode);
            assertOperationAllowed({data, error}, "Filter by code failed");
            assertExists(data);
            assertEquals(data.length, 1, `Should find 1 country with code ${targetCode}`);
            assertEquals(data[0].code, targetCode);
        });

        await t.step("filter by status (active)", async () => {
            const { data, error } = await superadminClient
                .from("countries")
                .select()
                .eq('status', 'active');
            assertOperationAllowed({data, error}, "Filter by status=active failed");
            assertExists(data);
            assert(data.length >= 2, "Should find at least 2 active countries (test setup ones)");
        });

         await t.step("filter by status (inactive)", async () => {
            const { data, error } = await superadminClient
                .from("countries")
                .select()
                .eq('status', 'inactive');
            assertOperationAllowed({data, error}, "Filter by status=inactive failed");
            assertExists(data);
            assertEquals(data.length, 1, "Should find 1 inactive country from test setup");
            assertEquals(data[0].code, `${searchBaseCode}B`);
        });

        // Combine filters (e.g., active status and specific name pattern)
        await t.step("combine filters (status and name)", async () => {
             const { data, error } = await superadminClient
                .from("countries")
                .select()
                .eq('status', 'active')
                .ilike('name', '%another%');
            assertOperationAllowed({data, error}, "Combined filter failed");
            assertExists(data);
            assertEquals(data.length, 1, "Should find 1 active country with 'another' in name");
            assertEquals(data[0].name, countriesToCreate[2].name);
        });

    } finally {
        console.log("Running cleanup for Search/Filter tests...");
        try {
            if (createdIdsForSearch.length > 0) {
                const { error } = await superadminClient.from("countries").delete().in("id", createdIdsForSearch);
                if (error) {
                    console.error("Cleanup failed for search/filter data:", error.message);
                } else {
                     console.log("Cleaned up search/filter test data");
                }
            }
            await superadminClient.auth.signOut();
        } catch (cleanupError) {
            console.error("Error during Search/Filter test cleanup:", cleanupError);
        }
        console.log("Cleanup finished for Search/Filter tests.");
    }
});
