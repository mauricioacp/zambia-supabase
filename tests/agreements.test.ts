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

Deno.test("agreements - RLS and CRUD operations by role", { sanitizeOps: false, sanitizeResources: false }, async (t) => {
    // Base test data with required fields from agreements.sql
    const testAgreementBase = {
        email: `test-${generateUniqueId()}@example.com`,
        headquarter_id: "", // Will be populated in setup
        season_id: "", // Will be populated in setup
        role_id: "", // Will be populated in setup
        status: "prospect",
        name: `Test User ${generateUniqueId()}`,
        last_name: `Test Last ${generateUniqueId()}`
    };

    let superadminAgreementId: string | undefined;
    let generalDirectorAgreementId: string | undefined;
    let studentAgreementId: string | undefined;
    let anonAgreementId: string | undefined;

    try {
        // ==========================================
        // 0. Setup: Get reference IDs needed for testing
        // ==========================================
        await t.step("Setup: Get reference IDs", async () => {
            const setupClient = await getClientForRole("superadmin");

            // Get a headquarter ID
            const { data: headquarterData, error: headquarterError } = await setupClient
                .from("headquarters")
                .select("id")
                .limit(1)
                .single();

            if (headquarterError || !headquarterData) {
                throw new Error(`Failed to get headquarter ID: ${headquarterError?.message}`);
            }
            testAgreementBase.headquarter_id = headquarterData.id;

            // Get a season ID
            const { data: seasonData, error: seasonError } = await setupClient
                .from("seasons")
                .select("id")
                .limit(1)
                .single();

            if (seasonError || !seasonData) {
                throw new Error(`Failed to get season ID: ${seasonError?.message}`);
            }
            testAgreementBase.season_id = seasonData.id;

            const { data: roleData, error: roleError } = await setupClient
                .from("roles")
                .select("id,code")
                .in("code", ["student", "general_director"])
                .limit(10);

            if (roleError || !roleData || roleData.length < 2) {
                throw new Error(`Failed to get role IDs: ${roleError?.message}`);
            }

            const studentRole = roleData.find(r => r.code === "student");
            const generalDirectorRole = roleData.find(r => r.code === "general_director");

            if (!studentRole || !generalDirectorRole) {
                throw new Error("Could not find required roles");
            }

            testAgreementBase.role_id = studentRole.id;

            await setupClient.auth.signOut();
        });

        // ==========================================
        // 1. Superadmin Role Tests
        // ==========================================
        await t.step("Superadmin: CRUD operations", async (t) => {
            const superadminClient = await getClientForRole("superadmin");
            const superadminTestAgreement = { 
                ...testAgreementBase, 
                name: `Superadmin Test ${generateUniqueId()}`,
                email: `superadmin-${generateUniqueId()}@example.com`
            };

            await t.step("can create agreements", async () => {
                const { data, error } = await superadminClient
                    .from("agreements")
                    .insert([superadminTestAgreement])
                    .select();

                assertOperationAllowed({ data, error }, "Superadmin should be allowed to create");
                assertExists(data);
                assertEquals(data[0].name, superadminTestAgreement.name);
                superadminAgreementId = data[0].id;
                createdIds.superadmin = superadminAgreementId;
            });

            if (!superadminAgreementId) {
                throw new Error("Superadmin test agreement creation failed, cannot proceed.");
            }

            await t.step("can read created agreement", async () => {
                const { data, error } = await superadminClient.from("agreements").select().eq("id", superadminAgreementId!);
                assertOperationAllowed({ data, error }, "Superadmin should be allowed to read");
                assertExists(data);
                assertEquals(data.length, 1);
                assertEquals(data[0].name, superadminTestAgreement.name);
            });

            await t.step("can update agreements", async () => {
                const updatedName = `Updated Agreement SA ${generateUniqueId()}`;
                const { data, error } = await superadminClient.from("agreements").update({ name: updatedName }).eq("id", superadminAgreementId!).select();
                assertOperationAllowed({ data, error }, "Superadmin should be allowed to update");
                assertExists(data);
                assertEquals(data.length, 1);
                assertEquals(data[0].name, updatedName);
            });

            await t.step("can delete agreements", async () => {
                const { error } = await superadminClient.from("agreements").delete().eq("id", superadminAgreementId!);
                assert(error === null, `Superadmin should be allowed to delete: ${error?.message}`);
                superadminAgreementId = undefined; // Mark as deleted
            });
        });

        console.log("Signing out superadmin...");
        await supabaseClient.auth.signOut();

        // ==========================================
        // 2. General Director Role Tests
        // ==========================================
        await t.step("General Director: CRUD operations", async (t) => {
            const generalDirectorClient = await getClientForRole("general_director");
            const generalDirectorTestAgreement = { 
                ...testAgreementBase, 
                name: `General Director Test ${generateUniqueId()}`,
                email: `gd-${generateUniqueId()}@example.com`
            };

            await t.step("can create agreements", async () => {
                const { data, error } = await generalDirectorClient
                    .from("agreements")
                    .insert([generalDirectorTestAgreement])
                    .select();

                assertOperationAllowed({ data, error }, "General Director should be allowed to create");
                assertExists(data);
                assertEquals(data[0].name, generalDirectorTestAgreement.name);
                generalDirectorAgreementId = data[0].id;
                createdIds.general_director = generalDirectorAgreementId;
            });

            if (!generalDirectorAgreementId) {
                throw new Error("General Director test agreement creation failed, cannot proceed.");
            }

            await t.step("can read created agreement", async () => {
                const { data, error } = await generalDirectorClient.from("agreements").select().eq("id", generalDirectorAgreementId!);
                assertOperationAllowed({ data, error }, "General Director should be allowed to read");
                assertExists(data);
                assertEquals(data.length, 1);
                assertEquals(data[0].name, generalDirectorTestAgreement.name);
            });

            await t.step("can update agreements", async () => {
                const updatedName = `Updated Agreement GD ${generateUniqueId()}`;
                const { data, error } = await generalDirectorClient.from("agreements").update({ name: updatedName }).eq("id", generalDirectorAgreementId!).select();
                assertOperationAllowed({ data, error }, "General Director should be allowed to update");
                assertExists(data);
                assertEquals(data.length, 1);
                assertEquals(data[0].name, updatedName);
            });

            await t.step("can delete agreements", async () => {
                const { error } = await generalDirectorClient.from("agreements").delete().eq("id", generalDirectorAgreementId!);
                assert(error === null, `General Director should be allowed to delete: ${error?.message}`);
                generalDirectorAgreementId = undefined; // Mark as deleted
            });
        });

        console.log("Signing out general director...");
        await supabaseClient.auth.signOut();

        // ==========================================
        // Setup data for student/anon tests
        // ==========================================
        await t.step("Setup: Create data for student/anon tests", async () => {
            const setupClient = await getClientForRole("superadmin");
            const studentTestAgreement = { 
                ...testAgreementBase, 
                name: `Student Test ${generateUniqueId()}`,
                email: `student-${generateUniqueId()}@example.com`
            };

            const { data, error } = await setupClient.from("agreements").insert([studentTestAgreement]).select();

            if (error || !data || data.length === 0) {
                throw new Error(`Failed to create test data for student/anon tests: ${error?.message}`);
            }
            studentAgreementId = data[0].id;
            createdIds.student_anon_setup = studentAgreementId;
            console.log(`Created agreement ${studentAgreementId} for student/anon tests.`);
            await setupClient.auth.signOut();
        });

        if (!studentAgreementId) {
            throw new Error("Setup for student/anon tests failed, cannot proceed.");
        }

        // ==========================================
        // 3. Student Role Tests
        // ==========================================
        await t.step("Student: CRUD operations", async (t) => {
            const studentClient = await getClientForRole("student");

            await t.step("can read own agreements", async () => {
                // First, get the user_id for the student
                const { data: userData } = await studentClient.auth.getUser();
                const userId = userData.user?.id;

                // Create an agreement for this student
                const superadminClient = await getClientForRole("superadmin");
                const ownAgreement = { 
                    ...testAgreementBase, 
                    name: `Student Own ${generateUniqueId()}`,
                    email: `student-own-${generateUniqueId()}@example.com`,
                    user_id: userId
                };

                const { data: ownData, error: ownError } = await superadminClient.from("agreements").insert([ownAgreement]).select();
                assertOperationAllowed({ data: ownData, error: ownError }, "Failed to create own agreement for student");
                const ownAgreementId = ownData?.[0]?.id;
                createdIds.student_own = ownAgreementId;

                await superadminClient.auth.signOut();

                // Now test if student can read their own agreement
                const { data, error } = await studentClient.from("agreements").select().eq("id", ownAgreementId!);
                assertOperationAllowed({ data, error }, "Student should be allowed to read own agreements");
                assertExists(data);
                assertEquals(data.length, 1);
            });

            await t.step("cannot read other agreements", async () => {
                const { data, error } = await studentClient.from("agreements").select().eq("id", studentAgreementId!);
                console.log('data ', data, 'error ', error);
                assertOperationDenied({ data, error }, "Student should NOT be allowed to read other agreements");
            });

            await t.step("cannot create agreements for others", async () => {
                const studentCreateAttempt = { 
                    ...testAgreementBase, 
                    name: `Student Create ${generateUniqueId()}`,
                    email: `student-create-${generateUniqueId()}@example.com`
                };
                const { data, error } = await studentClient.from("agreements").insert([studentCreateAttempt]).select();
                console.log('data ', data, 'error ', error);
                assertOperationDenied({ data, error }, "Student should NOT be allowed to create agreements for others");
            });

            await t.step("cannot update other agreements", async () => {
                const { data, error } = await studentClient.from("agreements").update({ name: `Updated by Student ${generateUniqueId()}` }).eq("id", studentAgreementId!).select();
                console.log('data ', data, 'error ', error);
                assertOperationDenied({ data, error }, "Student should NOT be allowed to update other agreements");
            });

            await t.step("cannot delete agreements", async () => {
                const { error } = await studentClient.from("agreements").delete().eq("id", studentAgreementId!);
                console.log('error ', error);
                assertOperationDenied({ data: null, error }, "Student should NOT be allowed to delete agreements");
            });
        });

        console.log("Signing out student...");
        await supabaseClient.auth.signOut();

        // ==========================================
        // 4. Anonymous User Tests
        // ==========================================
        await t.step("Anonymous: CRUD operations", async (t) => {
            const anonClient = supabaseClient;
            const session = await anonClient.auth.getSession();
            assert(session.data.session === null, "Client should be anonymous/signed out");

            await t.step("can create prospect agreements", async () => {
                const anonCreateAttempt = { 
                    ...testAgreementBase, 
                    name: `Anon Create ${generateUniqueId()}`,
                    email: `anon-${generateUniqueId()}@example.com`,
                    status: 'prospect' // Must be prospect
                };
                const { data, error } = await anonClient.from("agreements").insert([anonCreateAttempt]).select();
                assertOperationAllowed({ data, error }, "Anonymous user should be allowed to create prospect agreements");
                assertExists(data);
                assertEquals(data[0].status, 'prospect');
                anonAgreementId = data[0].id;
                createdIds.anon = anonAgreementId;
            });

            await t.step("cannot create non-prospect agreements", async () => {
                const anonCreateAttempt = { 
                    ...testAgreementBase, 
                    name: `Anon Active ${generateUniqueId()}`,
                    email: `anon-active-${generateUniqueId()}@example.com`,
                    status: 'active' // Not prospect
                };
                const { data, error } = await anonClient.from("agreements").insert([anonCreateAttempt]).select();
                console.log('data ', data, 'error ', error);
                assertOperationDenied({ data, error }, "Anonymous user should NOT be allowed to create non-prospect agreements");
            });

            await t.step("cannot read agreements", async () => {
                const { data, error } = await anonClient.from("agreements").select().eq("id", studentAgreementId!);
                console.log('data ', data, 'error ', error);
                assertOperationDenied({ data, error }, "Anonymous user should NOT be allowed to read agreements");
            });

            await t.step("cannot update agreements", async () => {
                const { data, error } = await anonClient.from("agreements").update({ name: `Updated by Anon ${generateUniqueId()}` }).eq("id", anonAgreementId!).select();
                console.log('data ', data, 'error ', error);
                assertOperationDenied({ data, error }, "Anonymous user should NOT be allowed to update agreements");
            });

            await t.step("cannot delete agreements", async () => {
                const { error } = await anonClient.from("agreements").delete().eq("id", anonAgreementId!);
                console.log('error ', error);
                assertOperationDenied({ data: null, error }, "Anonymous user should NOT be allowed to delete agreements");
            });
        });
    } finally {
        // ==========================================
        // Cleanup (runs even if tests fail)
        // ==========================================
        console.log("Running cleanup for RLS and CRUD tests...");
        try {
            const cleanupClient = await getClientForRole("superadmin");

            // Cleanup all created agreements
            const idsToCleanup = Object.values(createdIds).filter(id => id !== undefined) as string[];

            if (idsToCleanup.length > 0) {
                console.log(`Attempting cleanup for ${idsToCleanup.length} agreements`);
                const { error } = await cleanupClient.from("agreements").delete().in("id", idsToCleanup);
                if (error) {
                    console.error(`Cleanup failed: ${error.message}`);
                } else {
                    console.log(`Cleaned up ${idsToCleanup.length} agreements`);
                }
            }

            await cleanupClient.auth.signOut();
        } catch (cleanupError) {
            console.error("Error during cleanup phase:", cleanupError);
        }
        console.log("Cleanup finished for RLS and CRUD tests.");
    }
});

Deno.test("agreements - Constraint and trigger tests", { sanitizeOps: false, sanitizeResources: false }, async (t) => {
    let createdIdForConstraintTest: string | undefined;
    let activeStatusTestId: string | undefined;
    let inactiveStatusTestId: string | undefined;
    let prospectStatusTestId: string | undefined;
    let graduatedStatusTestId: string | undefined;
    const superadminClient = await getClientForRole("superadmin");

    // Base test data with required fields
    const testAgreementBase = {
        email: `test-${generateUniqueId()}@example.com`,
        headquarter_id: "", // Will be populated in setup
        season_id: "", // Will be populated in setup
        role_id: "", // Will be populated in setup
        status: "prospect",
        name: `Test User ${generateUniqueId()}`,
        last_name: `Test Last ${generateUniqueId()}`
    };

    try {
        // ==========================================
        // 0. Setup: Get reference IDs needed for testing
        // ==========================================
        await t.step("Setup: Get reference IDs", async () => {

            const { data: headquarterData, error: headquarterError } = await superadminClient
                .from("headquarters")
                .select("id")
                .limit(1)
                .single();

            if (headquarterError || !headquarterData) {
                throw new Error(`Failed to get headquarter ID: ${headquarterError?.message}`);
            }
            testAgreementBase.headquarter_id = headquarterData.id;

            // Get a season ID
            const { data: seasonData, error: seasonError } = await superadminClient
                .from("seasons")
                .select("id")
                .limit(1)
                .single();

            if (seasonError || !seasonData) {
                throw new Error(`Failed to get season ID: ${seasonError?.message}`);
            }
            testAgreementBase.season_id = seasonData.id;

            // Get a role ID
            const { data: roleData, error: roleError } = await superadminClient
                .from("roles")
                .select("id")
                .limit(1)
                .single();

            if (roleError || !roleData) {
                throw new Error(`Failed to get role ID: ${roleError?.message}`);
            }
            testAgreementBase.role_id = roleData.id;
        });

        const agreementForConstraintTest = { 
            ...testAgreementBase,
            name: `Constraint Test ${generateUniqueId()}`,
            email: `constraint-${generateUniqueId()}@example.com`
        };

        await t.step("Setup: Create initial agreement for constraint tests", async () => {
            const { data, error } = await superadminClient.from("agreements").insert(agreementForConstraintTest).select('id').single();
            assertOperationAllowed({data, error}, "Superadmin failed to create initial agreement for constraint test");
            assertExists(data?.id);
            createdIdForConstraintTest = data.id;
        });

        if (!createdIdForConstraintTest) {
            throw new Error("Setup for constraint tests failed.");
        }

        await t.step("status check constraint (active)", async () => {
            const { data, error } = await superadminClient
                .from("agreements")
                .insert([{ 
                    ...testAgreementBase, 
                    name: `Active Status Test ${generateUniqueId()}`, 
                    email: `active-${generateUniqueId()}@example.com`,
                    status: 'active' 
                }])
                .select('id');
            assertOperationAllowed({data, error}, "Insert with active status should succeed");
            if (data && data.length > 0 && data[0].id) {
                 activeStatusTestId = data[0].id; // Track ID for cleanup
            }
        });

        await t.step("status check constraint (inactive)", async () => {
            const { data, error } = await superadminClient
                .from("agreements")
                .insert([{ 
                    ...testAgreementBase, 
                    name: `Inactive Status Test ${generateUniqueId()}`, 
                    email: `inactive-${generateUniqueId()}@example.com`,
                    status: 'inactive' 
                }])
                .select('id');
            assertOperationAllowed({data, error}, "Insert with inactive status should succeed");
            if (data && data.length > 0 && data[0].id) {
                inactiveStatusTestId = data[0].id; // Track ID for cleanup
            }
        });

        await t.step("status check constraint (prospect)", async () => {
            const { data, error } = await superadminClient
                .from("agreements")
                .insert([{ 
                    ...testAgreementBase, 
                    name: `Prospect Status Test ${generateUniqueId()}`, 
                    email: `prospect-${generateUniqueId()}@example.com`,
                    status: 'prospect' 
                }])
                .select('id');
            assertOperationAllowed({data, error}, "Insert with prospect status should succeed");
            if (data && data.length > 0 && data[0].id) {
                prospectStatusTestId = data[0].id; // Track ID for cleanup
            }
        });

        await t.step("status check constraint (graduated)", async () => {
            const { data, error } = await superadminClient
                .from("agreements")
                .insert([{ 
                    ...testAgreementBase, 
                    name: `Graduated Status Test ${generateUniqueId()}`, 
                    email: `graduated-${generateUniqueId()}@example.com`,
                    status: 'graduated' 
                }])
                .select('id');
            assertOperationAllowed({data, error}, "Insert with graduated status should succeed");
            if (data && data.length > 0 && data[0].id) {
                graduatedStatusTestId = data[0].id; // Track ID for cleanup
            }
        });

        await t.step("status check constraint (invalid)", async () => {
            const { data, error } = await superadminClient
                .from("agreements")
                .insert([{ 
                    ...testAgreementBase, 
                    name: `Invalid Status Test ${generateUniqueId()}`, 
                    email: `invalid-${generateUniqueId()}@example.com`,
                    status: 'invalid_status' 
                }])
                .select();
            assert(error !== null, "Insert with invalid status should fail");
            assert(error?.message.includes('violates check constraint'), "Error message should indicate check constraint violation");
        });

        await t.step("gender check constraint (valid values)", async () => {
            for (const gender of ['male', 'female', 'other', 'unknown']) {
                const { data, error } = await superadminClient
                    .from("agreements")
                    .insert([{ 
                        ...testAgreementBase, 
                        name: `Gender ${gender} Test ${generateUniqueId()}`, 
                        email: `gender-${gender}-${generateUniqueId()}@example.com`,
                        gender 
                    }])
                    .select();
                assertOperationAllowed({data, error}, `Insert with gender=${gender} should succeed`);
                // Cleanup these right away to avoid too many test records
                if (data && data.length > 0) {
                    await superadminClient.from("agreements").delete().eq("id", data[0].id);
                }
            }
        });

        await t.step("gender check constraint (invalid)", async () => {
            const { data, error } = await superadminClient
                .from("agreements")
                .insert([{ 
                    ...testAgreementBase, 
                    name: `Invalid Gender Test ${generateUniqueId()}`, 
                    email: `invalid-gender-${generateUniqueId()}@example.com`,
                    gender: 'invalid_gender' 
                }])
                .select();
            assert(error !== null, "Insert with invalid gender should fail");
            assert(error?.message.includes('violates check constraint'), "Error message should indicate check constraint violation");
        });

        await t.step("unique constraint (user_id, season_id)", async () => {
            // First create an agreement with a specific user_id and season_id
            const { data: userData } = await superadminClient.auth.getUser();
            const userId = userData.user?.id;

            if (!userId) {
                console.log("Skipping unique constraint test - no user ID available");
                return;
            }

            const uniqueAgreement = { 
                ...testAgreementBase, 
                name: `Unique Test ${generateUniqueId()}`, 
                email: `unique-${generateUniqueId()}@example.com`,
                user_id: userId
            };

            const { data: firstData, error: firstError } = await superadminClient
                .from("agreements")
                .insert([uniqueAgreement])
                .select();

            assertOperationAllowed({data: firstData, error: firstError}, "First insert for unique constraint test should succeed");

            // Now try to create another agreement with the same user_id and season_id
            const duplicateAgreement = { 
                ...uniqueAgreement, 
                name: `Duplicate Test ${generateUniqueId()}`, 
                email: `duplicate-${generateUniqueId()}@example.com`
            };

            const { data: secondData, error: secondError } = await superadminClient
                .from("agreements")
                .insert([duplicateAgreement])
                .select();

            assert(secondError !== null, "Insert with duplicate (user_id, season_id) should fail");
            assert(secondError?.message.includes('duplicate key value violates unique constraint'), 
                   "Error message should indicate unique constraint violation");

            // Cleanup the first agreement
            if (firstData && firstData.length > 0) {
                await superadminClient.from("agreements").delete().eq("id", firstData[0].id);
            }
        });

        await t.step("updated_at trigger on update", async () => {
            const initialRead = await superadminClient.from("agreements").select('updated_at').eq('id', createdIdForConstraintTest!).single();
            const initialTimestamp = initialRead.data?.updated_at;
            assertExists(initialTimestamp, "Could not read initial timestamp");

            await new Promise(resolve => setTimeout(resolve, 50));

            const { data, error } = await superadminClient
                .from("agreements")
                .update({ name: `Trigger Test Update ${generateUniqueId()}` })
                .eq("id", createdIdForConstraintTest!)
                .select('updated_at')
                .single();

            assertOperationAllowed({data, error}, "Update for trigger test failed");
            assertExists(data?.updated_at, "Updated timestamp missing");
            assert(new Date(data.updated_at) > new Date(initialTimestamp), "updated_at timestamp did not increase after update");
        });

        await t.step("activation_date trigger on status change to active", async () => {
            // Create a prospect agreement
            const prospectAgreement = { 
                ...testAgreementBase, 
                name: `Activation Test ${generateUniqueId()}`, 
                email: `activation-${generateUniqueId()}@example.com`,
                status: 'prospect'
            };

            const { data: createData, error: createError } = await superadminClient
                .from("agreements")
                .insert([prospectAgreement])
                .select('id')
                .single();

            assertOperationAllowed({data: createData, error: createError}, "Create for activation date trigger test failed");
            const activationTestId = createData?.id;

            // Verify activation_date is null
            const initialRead = await superadminClient.from("agreements").select('activation_date').eq('id', activationTestId!).single();
            assert(initialRead.data?.activation_date === null, "Initial activation_date should be null");

            // Update status to active
            const { data: updateData, error: updateError } = await superadminClient
                .from("agreements")
                .update({ status: 'active' })
                .eq("id", activationTestId!)
                .select('activation_date')
                .single();

            assertOperationAllowed({data: updateData, error: updateError}, "Update for activation date trigger test failed");
            assertExists(updateData?.activation_date, "activation_date should be set after status change to active");

            // Cleanup
            await superadminClient.from("agreements").delete().eq("id", activationTestId!);
        });

        await t.step("fts_name_lastname trigger on insert", async () => {
            const testName = `FTS Test ${generateUniqueId()}`;
            const testLastName = `FTS Last ${generateUniqueId()}`;

            const ftsAgreement = { 
                ...testAgreementBase, 
                name: testName, 
                last_name: testLastName,
                email: `fts-${generateUniqueId()}@example.com`
            };

            const { data, error } = await superadminClient
                .from("agreements")
                .insert([ftsAgreement])
                .select('id, fts_name_lastname')
                .single();

            assertOperationAllowed({data, error}, "Insert for FTS trigger test failed");
            assertExists(data?.fts_name_lastname, "fts_name_lastname should be set on insert");

            // Search using the FTS vector
            const { data: searchData, error: searchError } = await superadminClient
                .from("agreements")
                .select()
                .textSearch('fts_name_lastname', testName.split(' ')[0]);

            assertOperationAllowed({data: searchData, error: searchError}, "FTS search failed");
            assert(searchData && searchData.length > 0, "Should find at least one result with FTS search");

            // Cleanup
            if (data?.id) {
                await superadminClient.from("agreements").delete().eq("id", data.id);
            }
        });

    } finally {
        // Cleanup for constraint tests
        console.log("Running cleanup for Constraint tests...");
        try {
            // No need to sign in again if superadminClient is still valid
             if (createdIdForConstraintTest) {
                 await superadminClient.from("agreements").delete().eq("id", createdIdForConstraintTest);
                 console.log(`Cleaned up constraint test base agreement ${createdIdForConstraintTest}`);
             }
             if (activeStatusTestId) {
                 await superadminClient.from("agreements").delete().eq("id", activeStatusTestId);
                 console.log(`Cleaned up active status test agreement ${activeStatusTestId}`);
             }
             if (inactiveStatusTestId) {
                 await superadminClient.from("agreements").delete().eq("id", inactiveStatusTestId);
                 console.log(`Cleaned up inactive status test agreement ${inactiveStatusTestId}`);
             }
             if (prospectStatusTestId) {
                 await superadminClient.from("agreements").delete().eq("id", prospectStatusTestId);
                 console.log(`Cleaned up prospect status test agreement ${prospectStatusTestId}`);
             }
             if (graduatedStatusTestId) {
                 await superadminClient.from("agreements").delete().eq("id", graduatedStatusTestId);
                 console.log(`Cleaned up graduated status test agreement ${graduatedStatusTestId}`);
             }
            await superadminClient.auth.signOut();
        } catch (cleanupError) {
             console.error("Error during Constraint test cleanup:", cleanupError);
        }
         console.log("Cleanup finished for Constraint tests.");
    }
});

Deno.test("agreements - Search and filter capabilities", { sanitizeOps: false, sanitizeResources: false }, async (t) => {
    let createdIdsForSearch: string[] = [];
    const superadminClient = await getClientForRole("superadmin");

    // Base test data with required fields
    const testAgreementBase = {
        email: `test-${generateUniqueId()}@example.com`,
        headquarter_id: "", // Will be populated in setup
        season_id: "", // Will be populated in setup
        role_id: "", // Will be populated in setup
        status: "prospect",
        name: `Test User ${generateUniqueId()}`,
        last_name: `Test Last ${generateUniqueId()}`
    };

    try {
        // ==========================================
        // 0. Setup: Get reference IDs needed for testing
        // ==========================================
        await t.step("Setup: Get reference IDs", async () => {
            // Get a headquarter ID
            const { data: headquarterData, error: headquarterError } = await superadminClient
                .from("headquarters")
                .select("id")
                .limit(1)
                .single();

            if (headquarterError || !headquarterData) {
                throw new Error(`Failed to get headquarter ID: ${headquarterError?.message}`);
            }
            testAgreementBase.headquarter_id = headquarterData.id;

            // Get a season ID
            const { data: seasonData, error: seasonError } = await superadminClient
                .from("seasons")
                .select("id")
                .limit(1)
                .single();

            if (seasonError || !seasonData) {
                throw new Error(`Failed to get season ID: ${seasonError?.message}`);
            }
            testAgreementBase.season_id = seasonData.id;

            // Get a role ID
            const { data: roleData, error: roleError } = await superadminClient
                .from("roles")
                .select("id")
                .limit(1)
                .single();

            if (roleError || !roleData) {
                throw new Error(`Failed to get role ID: ${roleError?.message}`);
            }
            testAgreementBase.role_id = roleData.id;
        });

        const searchBaseEmail = `search-${generateUniqueId()}`;
        const agreementsToCreate = [
            { 
                ...testAgreementBase, 
                name: `SearchFilter One ${generateUniqueId()}`, 
                last_name: `LastOne ${generateUniqueId()}`,
                email: `${searchBaseEmail}-one@example.com`, 
                status: 'active' 
            },
            { 
                ...testAgreementBase, 
                name: `SearchFilter Two ${generateUniqueId()}`, 
                last_name: `LastTwo ${generateUniqueId()}`,
                email: `${searchBaseEmail}-two@example.com`, 
                status: 'inactive' 
            },
            { 
                ...testAgreementBase, 
                name: `Another One ${generateUniqueId()}`, 
                last_name: `LastThree ${generateUniqueId()}`,
                email: `another-${generateUniqueId()}@example.com`, 
                status: 'active' 
            },
            { 
                ...testAgreementBase, 
                name: `Prospect Test ${generateUniqueId()}`, 
                last_name: `LastFour ${generateUniqueId()}`,
                email: `prospect-${generateUniqueId()}@example.com`, 
                status: 'prospect' 
            }
        ];

        await t.step("Setup: Create data for search/filter tests", async () => {
            const { data, error } = await superadminClient.from("agreements").insert(agreementsToCreate).select('id');
            assertOperationAllowed({data, error}, "Failed to create search/filter test data");
            createdIdsForSearch = data?.map(d => d.id) || [];
            assertEquals(createdIdsForSearch.length, agreementsToCreate.length, "Did not create expected number of agreements for search test");
            console.log("Created search/filter test data");
        });

        if (createdIdsForSearch.length !== agreementsToCreate.length) {
            throw new Error("Setup for search/filter tests failed");
        }

        await t.step("search by name (partial match)", async () => {
            const { data, error } = await superadminClient
                .from("agreements")
                .select()
                .ilike('name', '%searchfilter%'); // Case-insensitive partial match
            assertOperationAllowed({data, error}, "Search by name failed");
            assertExists(data);
            assertEquals(data.length, 2, "Should find 2 agreements with 'searchfilter' in name");
        });

        await t.step("search by email (partial match)", async () => {
            const { data, error } = await superadminClient
                .from("agreements")
                .select()
                .ilike('email', `%${searchBaseEmail}%`); // Case-insensitive partial match
            assertOperationAllowed({data, error}, "Search by email failed");
            assertExists(data);
            assertEquals(data.length, 2, `Should find 2 agreements with '${searchBaseEmail}' in email`);
        });

        await t.step("filter by status (active)", async () => {
            const { data, error } = await superadminClient
                .from("agreements")
                .select()
                .eq('status', 'active');
            assertOperationAllowed({data, error}, "Filter by status=active failed");
            assertExists(data);
            assert(data.length >= 2, "Should find at least 2 active agreements (test setup ones)");
        });

        await t.step("filter by status (inactive)", async () => {
            const { data, error } = await superadminClient
                .from("agreements")
                .select()
                .eq('status', 'inactive');
            assertOperationAllowed({data, error}, "Filter by status=inactive failed");
            assertExists(data);
            assert(data.some(a => a.email === agreementsToCreate[1].email), "Should find the inactive agreement from test setup");
        });

        await t.step("filter by status (prospect)", async () => {
            const { data, error } = await superadminClient
                .from("agreements")
                .select()
                .eq('status', 'prospect');
            assertOperationAllowed({data, error}, "Filter by status=prospect failed");
            assertExists(data);
            assert(data.some(a => a.email === agreementsToCreate[3].email), "Should find the prospect agreement from test setup");
        });

        await t.step("filter by headquarter_id", async () => {
            const { data, error } = await superadminClient
                .from("agreements")
                .select()
                .eq('headquarter_id', testAgreementBase.headquarter_id);
            assertOperationAllowed({data, error}, "Filter by headquarter_id failed");
            assertExists(data);
            assert(data.length >= agreementsToCreate.length, "Should find at least the agreements from test setup");
        });

        await t.step("filter by season_id", async () => {
            const { data, error } = await superadminClient
                .from("agreements")
                .select()
                .eq('season_id', testAgreementBase.season_id);
            assertOperationAllowed({data, error}, "Filter by season_id failed");
            assertExists(data);
            assert(data.length >= agreementsToCreate.length, "Should find at least the agreements from test setup");
        });

        // Combine filters (e.g., active status and specific name pattern)
        await t.step("combine filters (status and name)", async () => {
            const { data, error } = await superadminClient
                .from("agreements")
                .select()
                .eq('status', 'active')
                .ilike('name', '%another%');
            assertOperationAllowed({data, error}, "Combined filter failed");
            assertExists(data);
            assertEquals(data.length, 1, "Should find 1 active agreement with 'another' in name");
            assertEquals(data[0].name, agreementsToCreate[2].name);
        });

        // Test full-text search
        await t.step("full-text search using fts_name_lastname", async () => {
            // First, get the first word of the name from one of our test agreements
            const searchTerm = agreementsToCreate[0].name.split(' ')[0];

            const { data, error } = await superadminClient
                .from("agreements")
                .select()
                .textSearch('fts_name_lastname', searchTerm);

            assertOperationAllowed({data, error}, "Full-text search failed");
            assertExists(data);
            assert(data.length > 0, `Should find at least one result with FTS search for '${searchTerm}'`);
            assert(data.some(a => a?.name?.includes(searchTerm)), `Should find an agreement with '${searchTerm}' in name`);
        });

    } finally {
        console.log("Running cleanup for Search/Filter tests...");
        try {
            if (createdIdsForSearch.length > 0) {
                const { error } = await superadminClient.from("agreements").delete().in("id", createdIdsForSearch);
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
