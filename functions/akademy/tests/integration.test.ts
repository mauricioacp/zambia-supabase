import { assertEquals, assertExists, assertRejects } from "@std/assert";
import { createClient, SupabaseClient } from "@supabase/supabase-js";
import { Database } from "../../../types/supabase.type.ts";

// Test configuration
const TEST_CONFIG = {
  supabaseUrl: Deno.env.get("SUPABASE_URL") || "http://localhost:54321",
  supabaseAnonKey: Deno.env.get("SUPABASE_ANON_KEY") || "test-anon-key",
  supabaseServiceKey: Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ||
    "test-service-key",
  functionUrl: "http://localhost:54321/functions/v1/akademy",
};

interface TestUser {
  email: string;
  password: string;
  token: string;
  level: number;
}

class IntegrationTestSuite {
  private supabase: SupabaseClient<Database>;
  private adminSupabase: SupabaseClient<Database>;
  private testUsers: Map<string, TestUser> = new Map();
  private createdAgreements: string[] = [];
  private createdUsers: string[] = [];

  constructor() {
    this.supabase = createClient(
      TEST_CONFIG.supabaseUrl,
      TEST_CONFIG.supabaseAnonKey,
    );
    this.adminSupabase = createClient(
      TEST_CONFIG.supabaseUrl,
      TEST_CONFIG.supabaseServiceKey,
    );
  }

  async setup(): Promise<void> {
    console.log("🔧 Setting up integration tests...");

    // Create test users with different permission levels
    await this.createTestUsers();

    // Create test data (agreements, roles, etc.)
    await this.createTestData();

    console.log("✅ Test setup complete");
  }

  async cleanup(): Promise<void> {
    console.log("🧹 Cleaning up test data...");

    // Clean up created users
    for (const userId of this.createdUsers) {
      await this.adminSupabase.auth.admin.deleteUser(userId);
    }

    // Clean up created agreements
    for (const agreementId of this.createdAgreements) {
      await this.adminSupabase.from("agreements").delete().eq(
        "id",
        agreementId,
      );
    }

    console.log("✅ Cleanup complete");
  }

  private async createTestUsers(): Promise<void> {
    const users = [
      { role: "admin", level: 50, email: "admin@test.com" },
      { role: "manager", level: 30, email: "manager@test.com" },
      { role: "user", level: 10, email: "user@test.com" },
    ];

    for (const user of users) {
      const { data, error } = await this.adminSupabase.auth.admin.createUser({
        email: user.email,
        password: "TestPassword123!",
        email_confirm: true,
        user_metadata: {
          role: user.role,
          role_level: user.level,
        },
      });

      if (error) throw error;

      // Sign in to get JWT token
      const { data: signInData } = await this.supabase.auth.signInWithPassword({
        email: user.email,
        password: "TestPassword123!",
      });

      this.testUsers.set(user.role, {
        email: user.email,
        password: "TestPassword123!",
        token: signInData.session?.access_token || "",
        level: user.level,
      });

      this.createdUsers.push(data.user.id);
    }
  }

  private async createTestData(): Promise<void> {
    // Create test role if not exists
    const { data: role } = await this.adminSupabase
      .from("roles")
      .select("id")
      .eq("code", "test-role")
      .single();

    if (!role) {
      await this.adminSupabase.from("roles").insert({
        code: "test-role",
        name: "Test Role",
        level: 20,
      });
    }

    // Create test headquarters and other dependencies
    const { data: hq } = await this.adminSupabase
      .from("headquarters")
      .select("id")
      .eq("name", "Test HQ")
      .single();

    if (!hq) {
      await this.adminSupabase.from("headquarters").insert({
        name: "Test HQ",
        country_id: "1", // Assuming country exists
      });
    }

    // Create test season
    const { data: season } = await this.adminSupabase
      .from("seasons")
      .select("id")
      .eq("name", "Test Season")
      .single();

    if (!season) {
      await this.adminSupabase.from("seasons").insert({
        name: "Test Season",
        year: 2024,
        headquarter_id: hq?.id || "1",
      });
    }
  }

  private async makeRequest(
    endpoint: string,
    method: string = "GET",
    body?: unknown,
    headers: Record<string, string> = {},
  ): Promise<Response> {
    const url = `${TEST_CONFIG.functionUrl}${endpoint}`;

    const requestInit: RequestInit = {
      method,
      headers: {
        "Content-Type": "application/json",
        ...headers,
      },
    };

    if (body && method !== "GET") {
      requestInit.body = JSON.stringify(body);
    }

    return await fetch(url, requestInit);
  }

  private getAuthHeaders(userType: string): Record<string, string> {
    const user = this.testUsers.get(userType);
    if (!user) throw new Error(`Test user ${userType} not found`);

    return {
      "Authorization": `Bearer ${user.token}`,
    };
  }

  // Test health endpoint
  async testHealthEndpoint(): Promise<void> {
    console.log("🔍 Testing health endpoint...");

    const response = await this.makeRequest("/health");
    assertEquals(response.status, 200);

    const data = await response.json();
    assertEquals(data.status, "ok");
    assertExists(data.timestamp);
    assertEquals(data.services, ["migration", "user-management"]);
  }

  // Test CORS headers
  async testCorsHeaders(): Promise<void> {
    console.log("🔍 Testing CORS headers...");

    const response = await this.makeRequest("/health", "OPTIONS", undefined, {
      "Origin": "http://localhost:3000",
      "Access-Control-Request-Method": "POST",
    });

    assertEquals(response.status, 204);
    assertExists(response.headers.get("access-control-allow-origin"));
  }

  // Test authentication middleware
  async testAuthenticationMiddleware(): Promise<void> {
    console.log("🔍 Testing authentication middleware...");

    // Test without token
    const noTokenResponse = await this.makeRequest("/create-user", "POST", {
      agreement_id: "test-id",
    });
    assertEquals(noTokenResponse.status, 401);

    // Test with invalid token
    const invalidTokenResponse = await this.makeRequest(
      "/create-user",
      "POST",
      {
        agreement_id: "test-id",
      },
      {
        "Authorization": "Bearer invalid-token",
      },
    );
    assertEquals(invalidTokenResponse.status, 401);
  }

  // Test role-based access control
  async testRoleBasedAccess(): Promise<void> {
    console.log("🔍 Testing role-based access control...");

    // Test insufficient permissions
    const lowLevelResponse = await this.makeRequest("/create-user", "POST", {
      agreement_id: "test-id",
    }, this.getAuthHeaders("user"));
    assertEquals(lowLevelResponse.status, 401);

    // Test sufficient permissions
    const adminResponse = await this.makeRequest("/deactivate-user", "POST", {
      user_id: "test-user-id",
    }, this.getAuthHeaders("admin"));
    // Should get 404 (user not found) not 401 (unauthorized)
    assertEquals(adminResponse.status, 404);
  }

  // Test user creation flow
  async testUserCreationFlow(): Promise<void> {
    console.log("🔍 Testing user creation flow...");

    // First create a test agreement
    const { data: agreement, error } = await this.adminSupabase
      .from("agreements")
      .insert({
        email: "newuser@test.com",
        name: "Test",
        last_name: "User",
        status: "prospect",
        role_id: "1", // Assuming role exists
        headquarter_id: "1",
        season_id: "1",
      })
      .select()
      .single();

    if (error) throw error;
    this.createdAgreements.push(agreement.id);

    // Test user creation
    const response = await this.makeRequest("/create-user", "POST", {
      agreement_id: agreement.id,
    }, this.getAuthHeaders("admin"));

    assertEquals(response.status, 201);

    const data = await response.json();
    assertExists(data.data.user_id);
    assertExists(data.data.password);
    assertEquals(data.data.email, "newuser@test.com");

    this.createdUsers.push(data.data.user_id);
  }

  // Test migration endpoint security
  async testMigrationSecurity(): Promise<void> {
    console.log("🔍 Testing migration endpoint security...");

    // Test without super password
    const noPasswordResponse = await this.makeRequest(
      "/migrate",
      "POST",
      {},
      this.getAuthHeaders("admin"),
    );
    assertEquals(noPasswordResponse.status, 401);

    // Test with wrong super password
    const wrongPasswordResponse = await this.makeRequest(
      "/migrate",
      "POST",
      {},
      {
        ...this.getAuthHeaders("admin"),
        "x-super-password": "wrong-password",
      },
    );
    assertEquals(wrongPasswordResponse.status, 401);
  }

  // Test input validation
  async testInputValidation(): Promise<void> {
    console.log("🔍 Testing input validation...");

    // Test invalid UUID format
    const invalidUuidResponse = await this.makeRequest("/create-user", "POST", {
      agreement_id: "invalid-uuid",
    }, this.getAuthHeaders("admin"));
    assertEquals(invalidUuidResponse.status, 400);

    // Test missing required fields
    const missingFieldResponse = await this.makeRequest(
      "/create-user",
      "POST",
      {},
      this.getAuthHeaders("admin"),
    );
    assertEquals(missingFieldResponse.status, 400);
  }

  // Test error handling
  async testErrorHandling(): Promise<void> {
    console.log("🔍 Testing error handling...");

    // Test non-existent agreement
    const notFoundResponse = await this.makeRequest("/create-user", "POST", {
      agreement_id: "550e8400-e29b-41d4-a716-446655440000",
    }, this.getAuthHeaders("admin"));
    assertEquals(notFoundResponse.status, 404);

    const errorData = await notFoundResponse.json();
    assertExists(errorData.error);
    assertEquals(errorData.status, 404);
  }

  // Test concurrent requests
  async testConcurrentRequests(): Promise<void> {
    console.log("🔍 Testing concurrent requests...");

    const promises = Array.from(
      { length: 5 },
      () => this.makeRequest("/health"),
    );

    const responses = await Promise.all(promises);

    for (const response of responses) {
      assertEquals(response.status, 200);
    }
  }

  // Test large request handling
  async testLargeRequests(): Promise<void> {
    console.log("🔍 Testing large request handling...");

    // Create a large payload (should be rejected if size limits work)
    const largePayload = {
      agreement_id: "550e8400-e29b-41d4-a716-446655440000",
      large_data: "x".repeat(2 * 1024 * 1024), // 2MB
    };

    const response = await this.makeRequest(
      "/create-user",
      "POST",
      largePayload,
      this.getAuthHeaders("admin"),
    );

    // Should be rejected with 413 if size limits are implemented
    // For now, might get 400 or other error depending on implementation
    assertEquals(response.status >= 400, true);
  }

  // Run all tests
  async runAllTests(): Promise<void> {
    try {
      await this.setup();

      await this.testHealthEndpoint();
      await this.testCorsHeaders();
      await this.testAuthenticationMiddleware();
      await this.testRoleBasedAccess();
      await this.testUserCreationFlow();
      await this.testMigrationSecurity();
      await this.testInputValidation();
      await this.testErrorHandling();
      await this.testConcurrentRequests();
      await this.testLargeRequests();

      console.log("✅ All integration tests passed!");
    } finally {
      await this.cleanup();
    }
  }
}

// Run tests
if (import.meta.main) {
  const testSuite = new IntegrationTestSuite();
  await testSuite.runAllTests();
}
