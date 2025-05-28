import { assertEquals, assertExists } from "@std/assert";
import {
  ApiTestHelper,
  setupTestEnvironment,
  TestEnvironment,
} from "./test-helpers.ts";

/**
 * End-to-End tests for complete user journeys
 */

class E2ETestSuite {
  private env!: TestEnvironment;
  private api!: ApiTestHelper;

  async setup(): Promise<void> {
    this.env = await setupTestEnvironment();
    this.api = new ApiTestHelper(this.env.functionUrl);
  }

  async cleanup(): Promise<void> {
    if (this.env?.testData) {
      await this.env.testData.cleanup();
    }
  }

  // Complete user creation journey
  async testCompleteUserCreationJourney(): Promise<void> {
    console.log("🎬 Testing complete user creation journey...");

    // Step 1: Create admin user
    const admin = await this.env.testData.createTestUser(50);

    // Step 2: Create prospect agreement
    const agreementId = await this.env.testData.createTestAgreement({
      email: "newuser@journey.test",
      name: "Journey",
      last_name: "Test",
      status: "prospect",
    });

    // Step 3: Admin creates user from agreement
    const createResponse = await this.api.makeAuthenticatedRequest(
      "/create-user",
      admin.token,
      {
        method: "POST",
        body: { agreement_id: agreementId },
        expectedStatus: 201,
      },
    );

    const createData = await createResponse.json();
    assertExists(createData.data.user_id);
    assertExists(createData.data.password);
    assertEquals(createData.data.email, "newuser@journey.test");

    // Step 4: Verify agreement was updated
    const { data: updatedAgreement } = await this.env.adminSupabase
      .from("agreements")
      .select("status, user_id, activation_date")
      .eq("id", agreementId)
      .single();

    assertEquals(updatedAgreement?.status, "active");
    assertEquals(updatedAgreement?.user_id, createData.data.user_id);
    assertExists(updatedAgreement?.activation_date);

    // Step 5: Verify user can sign in
    const { data: signInData, error } = await this.env.supabase.auth
      .signInWithPassword({
        email: createData.data.email,
        password: createData.data.password,
      });

    assertEquals(error, null);
    assertExists(signInData.user);
    assertEquals(signInData.user.email, "newuser@journey.test");

    console.log("✅ User creation journey completed successfully");
  }

  // Password reset journey
  async testPasswordResetJourney(): Promise<void> {
    console.log("🔑 Testing password reset journey...");

    // Step 1: Create admin and user
    const admin = await this.env.testData.createTestUser(30);
    const userId = await this.env.testData.createTestUser(10);

    // Step 2: Create user agreement for identity verification
    const agreementId = await this.env.testData.createTestAgreement({
      email: "reset@test.com",
      name: "Reset",
      last_name: "Test",
      user_id: userId.id,
      status: "active",
      document_number: "DOC123456",
      phone: "+1234567890",
    });

    // Step 3: Admin resets password
    const resetResponse = await this.api.makeAuthenticatedRequest(
      "/reset-password",
      admin.token,
      {
        method: "POST",
        body: {
          email: "reset@test.com",
          document_number: "DOC123456",
          new_password: "NewPassword123!",
          phone: "+1234567890",
          first_name: "Reset",
          last_name: "Test",
        },
        expectedStatus: 200,
      },
    );

    const resetData = await resetResponse.json();
    assertExists(resetData.data.message);
    assertEquals(resetData.data.user_email, "reset@test.com");

    console.log("✅ Password reset journey completed successfully");
  }

  // User deactivation journey
  async testUserDeactivationJourney(): Promise<void> {
    console.log("🚫 Testing user deactivation journey...");

    // Step 1: Create admin and target user
    const admin = await this.env.testData.createTestUser(50);
    const targetUser = await this.env.testData.createTestUser(20);

    // Step 2: Create agreement for target user
    const agreementId = await this.env.testData.createTestAgreement({
      user_id: targetUser.id,
      status: "active",
    });

    // Step 3: Admin deactivates user
    const deactivateResponse = await this.api.makeAuthenticatedRequest(
      "/deactivate-user",
      admin.token,
      {
        method: "POST",
        body: { user_id: targetUser.id },
        expectedStatus: 200,
      },
    );

    const deactivateData = await deactivateResponse.json();
    assertExists(deactivateData.data.message);
    assertEquals(deactivateData.data.user_id, targetUser.id);

    // Step 4: Verify agreement was deactivated
    const { data: updatedAgreement } = await this.env.adminSupabase
      .from("agreements")
      .select("status")
      .eq("id", agreementId)
      .single();

    assertEquals(updatedAgreement?.status, "inactive");

    console.log("✅ User deactivation journey completed successfully");
  }

  // Permission escalation prevention
  async testPermissionEscalationPrevention(): Promise<void> {
    console.log("🛡️ Testing permission escalation prevention...");

    // Step 1: Create users with different levels
    const lowLevelUser = await this.env.testData.createTestUser(10);
    const midLevelUser = await this.env.testData.createTestUser(30);
    const highLevelUser = await this.env.testData.createTestUser(50);

    // Step 2: Create high-level role agreement
    const highLevelAgreementId = await this.env.testData.createTestAgreement({
      // This would be an agreement for a high-level role
      status: "prospect",
    });

    // Step 3: Low-level user tries to create high-level user (should fail)
    await this.api.expectError(
      "/create-user",
      lowLevelUser.token,
      401,
      {
        method: "POST",
        body: { agreement_id: highLevelAgreementId },
      },
    );

    // Step 4: Low-level user tries to deactivate someone (should fail)
    await this.api.expectError(
      "/deactivate-user",
      lowLevelUser.token,
      401,
      {
        method: "POST",
        body: { user_id: midLevelUser.id },
      },
    );

    // Step 5: Mid-level user tries level 50 operation (should fail)
    await this.api.expectError(
      "/deactivate-user",
      midLevelUser.token,
      401,
      {
        method: "POST",
        body: { user_id: highLevelUser.id },
      },
    );

    console.log("✅ Permission escalation prevention working correctly");
  }

  // Data integrity journey
  async testDataIntegrityJourney(): Promise<void> {
    console.log("🔐 Testing data integrity journey...");

    // Step 1: Create admin user
    const admin = await this.env.testData.createTestUser(50);

    // Step 2: Try to create user with non-existent agreement
    await this.api.expectError(
      "/create-user",
      admin.token,
      404,
      {
        method: "POST",
        body: { agreement_id: "550e8400-e29b-41d4-a716-446655440000" },
      },
    );

    // Step 3: Create agreement and user successfully
    const agreementId = await this.env.testData.createTestAgreement();

    const createResponse = await this.api.makeAuthenticatedRequest(
      "/create-user",
      admin.token,
      {
        method: "POST",
        body: { agreement_id: agreementId },
        expectedStatus: 201,
      },
    );

    const userData = await createResponse.json();

    // Step 4: Try to create user from same agreement again (should fail)
    await this.api.expectError(
      "/create-user",
      admin.token,
      404,
      {
        method: "POST",
        body: { agreement_id: agreementId },
      },
    );

    // Step 5: Verify data consistency
    const { data: agreement } = await this.env.adminSupabase
      .from("agreements")
      .select("status, user_id")
      .eq("id", agreementId)
      .single();

    assertEquals(agreement?.status, "active");
    assertEquals(agreement?.user_id, userData.data.user_id);

    console.log("✅ Data integrity journey completed successfully");
  }

  // API error handling journey
  async testErrorHandlingJourney(): Promise<void> {
    console.log("❌ Testing error handling journey...");

    const admin = await this.env.testData.createTestUser(50);

    // Test various error scenarios
    const errorTests = [
      {
        name: "Invalid UUID format",
        endpoint: "/create-user",
        body: { agreement_id: "invalid-uuid" },
        expectedStatus: 400,
      },
      {
        name: "Missing required fields",
        endpoint: "/create-user",
        body: {},
        expectedStatus: 400,
      },
      {
        name: "Invalid JSON structure",
        endpoint: "/reset-password",
        body: { email: "not-an-object" },
        expectedStatus: 400,
      },
    ];

    for (const test of errorTests) {
      try {
        await this.api.expectError(
          test.endpoint,
          admin.token,
          test.expectedStatus,
          {
            method: "POST",
            body: test.body,
          },
        );
        console.log(`  ✓ ${test.name}`);
      } catch (error) {
        console.log(`  ✗ ${test.name}: ${error.message}`);
        throw error;
      }
    }

    console.log("✅ Error handling journey completed successfully");
  }

  // Run all E2E tests
  async runAllTests(): Promise<void> {
    try {
      await this.setup();

      await this.testCompleteUserCreationJourney();
      await this.testPasswordResetJourney();
      await this.testUserDeactivationJourney();
      await this.testPermissionEscalationPrevention();
      await this.testDataIntegrityJourney();
      await this.testErrorHandlingJourney();

      console.log("\n✅ All E2E tests passed!");
    } finally {
      await this.cleanup();
    }
  }
}

// Run E2E tests
if (import.meta.main) {
  const e2eSuite = new E2ETestSuite();
  await e2eSuite.runAllTests();
}
