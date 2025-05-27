import { createClient, SupabaseClient } from "@supabase/supabase-js";
import { Database } from "../../../types/supabase.type.ts";

/**
 * Test helpers and utilities for integration testing
 */

export interface TestEnvironment {
  supabase: SupabaseClient<Database>;
  adminSupabase: SupabaseClient<Database>;
  functionUrl: string;
  testData: TestDataManager;
}

export class TestDataManager {
  private createdRecords: Map<string, string[]> = new Map();
  private adminClient: SupabaseClient<Database>;

  constructor(adminClient: SupabaseClient<Database>) {
    this.adminClient = adminClient;
  }

  // Track created records for cleanup
  trackRecord(table: string, id: string): void {
    const records = this.createdRecords.get(table) || [];
    records.push(id);
    this.createdRecords.set(table, records);
  }

  // Create test agreement
  async createTestAgreement(overrides: Partial<any> = {}): Promise<string> {
    const defaultAgreement = {
      email: `test-${Date.now()}@example.com`,
      name: "Test",
      last_name: "User",
      status: "prospect",
      role_id: await this.getOrCreateTestRole(),
      headquarter_id: await this.getOrCreateTestHeadquarter(),
      season_id: await this.getOrCreateTestSeason(),
      ...overrides,
    };

    const { data, error } = await this.adminClient
      .from("agreements")
      .insert(defaultAgreement)
      .select("id")
      .single();

    if (error) throw error;

    this.trackRecord("agreements", data.id);
    return data.id;
  }

  // Create test user
  async createTestUser(
    level: number = 30,
  ): Promise<{ id: string; token: string }> {
    const email = `testuser-${Date.now()}@example.com`;

    const { data, error } = await this.adminClient.auth.admin.createUser({
      email,
      password: "TestPassword123!",
      email_confirm: true,
      user_metadata: {
        role_level: level,
      },
    });

    if (error) throw error;

    // Get token by signing in
    const client = createClient(
      this.adminClient.supabaseUrl,
      this.adminClient.supabaseKey,
    );

    const { data: signInData } = await client.auth.signInWithPassword({
      email,
      password: "TestPassword123!",
    });

    this.trackRecord("auth.users", data.user.id);

    return {
      id: data.user.id,
      token: signInData.session?.access_token || "",
    };
  }

  private async getOrCreateTestRole(): Promise<string> {
    let { data } = await this.adminClient
      .from("roles")
      .select("id")
      .eq("code", "test-role")
      .single();

    if (!data) {
      const { data: newRole, error } = await this.adminClient
        .from("roles")
        .insert({
          code: "test-role",
          name: "Test Role",
          level: 20,
        })
        .select("id")
        .single();

      if (error) throw error;
      data = newRole;
      this.trackRecord("roles", data.id);
    }

    return data.id;
  }

  private async getOrCreateTestHeadquarter(): Promise<string> {
    let { data } = await this.adminClient
      .from("headquarters")
      .select("id")
      .eq("name", "Test HQ")
      .single();

    if (!data) {
      const { data: newHQ, error } = await this.adminClient
        .from("headquarters")
        .insert({
          name: "Test HQ",
          country_id: await this.getOrCreateTestCountry(),
        })
        .select("id")
        .single();

      if (error) throw error;
      data = newHQ;
      this.trackRecord("headquarters", data.id);
    }

    return data.id;
  }

  private async getOrCreateTestCountry(): Promise<string> {
    let { data } = await this.adminClient
      .from("countries")
      .select("id")
      .eq("name", "Test Country")
      .single();

    if (!data) {
      const { data: newCountry, error } = await this.adminClient
        .from("countries")
        .insert({
          name: "Test Country",
          code: "TC",
        })
        .select("id")
        .single();

      if (error) throw error;
      data = newCountry;
      this.trackRecord("countries", data.id);
    }

    return data.id;
  }

  private async getOrCreateTestSeason(): Promise<string> {
    let { data } = await this.adminClient
      .from("seasons")
      .select("id")
      .eq("name", "Test Season 2024")
      .single();

    if (!data) {
      const { data: newSeason, error } = await this.adminClient
        .from("seasons")
        .insert({
          name: "Test Season 2024",
          year: 2024,
          headquarter_id: await this.getOrCreateTestHeadquarter(),
        })
        .select("id")
        .single();

      if (error) throw error;
      data = newSeason;
      this.trackRecord("seasons", data.id);
    }

    return data.id;
  }

  // Clean up all created test data
  async cleanup(): Promise<void> {
    console.log("🧹 Cleaning up test data...");

    const tables = [
      "agreements",
      "auth.users",
      "seasons",
      "headquarters",
      "countries",
      "roles",
    ];

    for (const table of tables) {
      const records = this.createdRecords.get(table) || [];

      for (const id of records) {
        try {
          if (table === "auth.users") {
            await this.adminClient.auth.admin.deleteUser(id);
          } else {
            await this.adminClient.from(table).delete().eq("id", id);
          }
        } catch (error) {
          console.warn(`Failed to delete ${table} record ${id}:`, error);
        }
      }
    }

    this.createdRecords.clear();
    console.log("✅ Test data cleanup complete");
  }
}

export class ApiTestHelper {
  constructor(private baseUrl: string) {}

  async makeRequest(
    endpoint: string,
    options: {
      method?: string;
      body?: unknown;
      headers?: Record<string, string>;
      expectedStatus?: number;
    } = {},
  ): Promise<Response> {
    const {
      method = "GET",
      body,
      headers = {},
      expectedStatus,
    } = options;

    const response = await fetch(`${this.baseUrl}${endpoint}`, {
      method,
      headers: {
        "Content-Type": "application/json",
        ...headers,
      },
      body: body ? JSON.stringify(body) : undefined,
    });

    if (expectedStatus && response.status !== expectedStatus) {
      const responseText = await response.text();
      throw new Error(
        `Expected status ${expectedStatus}, got ${response.status}. Response: ${responseText}`,
      );
    }

    return response;
  }

  async makeAuthenticatedRequest(
    endpoint: string,
    token: string,
    options: {
      method?: string;
      body?: unknown;
      headers?: Record<string, string>;
      expectedStatus?: number;
    } = {},
  ): Promise<Response> {
    return this.makeRequest(endpoint, {
      ...options,
      headers: {
        "Authorization": `Bearer ${token}`,
        ...options.headers,
      },
    });
  }

  async expectError(
    endpoint: string,
    token: string,
    expectedStatus: number,
    options: {
      method?: string;
      body?: unknown;
      headers?: Record<string, string>;
    } = {},
  ): Promise<void> {
    const response = await this.makeAuthenticatedRequest(endpoint, token, {
      ...options,
      expectedStatus,
    });

    const data = await response.json();
    if (!data.error) {
      throw new Error(`Expected error response, got: ${JSON.stringify(data)}`);
    }
  }
}

// Setup test environment
export async function setupTestEnvironment(): Promise<TestEnvironment> {
  const supabaseUrl = Deno.env.get("SUPABASE_URL") || "http://localhost:54321";
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") || "test-anon-key";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ||
    "test-service-key";
  const functionUrl = "http://localhost:54321/functions/v1/akademy";

  const supabase = createClient(supabaseUrl, anonKey);
  const adminSupabase = createClient(supabaseUrl, serviceKey);

  const testData = new TestDataManager(adminSupabase);

  return {
    supabase,
    adminSupabase,
    functionUrl,
    testData,
  };
}

// Test assertions
export function assertResponseTime(responseTime: number, maxMs: number): void {
  if (responseTime > maxMs) {
    throw new Error(
      `Response time ${responseTime}ms exceeded maximum ${maxMs}ms`,
    );
  }
}

export function assertSuccessRate(
  successful: number,
  total: number,
  minRate: number,
): void {
  const rate = successful / total;
  if (rate < minRate) {
    throw new Error(
      `Success rate ${
        (rate * 100).toFixed(2)
      }% below minimum ${(minRate * 100)}%`,
    );
  }
}

// Wait utility for timing tests
export function wait(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
