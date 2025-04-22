import { assertEquals } from "@std/assert";

// Mock environment variables
Deno.env.set("SUPABASE_URL", "https://example.supabase.co");
Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", "mock-service-role-key");
Deno.env.set("ADMIN_SECRET", "mock-admin-secret");
Deno.env.set("SUPER_ADMIN_JWT_SECRET", "mock-super-admin-jwt-secret");

// Mock Supabase client
const mockSupabaseClient = {
  from: () => ({
    select: () => ({
      eq: () => Promise.resolve({ data: [], error: null }),
    }),
    insert: () => ({
      select: () => ({
        single: () => Promise.resolve({ data: { id: "mock-id" }, error: null }),
      }),
    }),
    update: () => ({
      eq: () => ({
        select: () => ({
          single: () => Promise.resolve({ data: { id: "mock-id" }, error: null }),
        }),
      }),
    }),
    delete: () => ({
      eq: () => Promise.resolve({ error: null }),
    }),
  }),
  auth: {
    admin: {
      listUsers: () => Promise.resolve({ data: { users: [] }, error: null }),
      createUser: () => Promise.resolve({
        data: {
          user: {
            id: "mock-user-id",
            email: "test@example.com",
          },
        },
        error: null,
      }),
    },
  },
};

// Mock the supabase module
import * as supabaseModule from "supabase";
supabaseModule.createClient = () => mockSupabaseClient;

// Import the corsHeaders after mocking
import { corsHeaders } from "./middleware/cors.ts";

// Import the handler after setting environment variables and mocks
import handler from "./main.ts";

Deno.test("Handler returns 404 for unknown routes", async () => {
  const req = new Request("https://example.com/unknown-route");
  const res = await handler.fetch(req);
  assertEquals(res.status, 404);

  const body = await res.json();
  assertEquals(body.error, "Not found");
});

Deno.test("Handler returns home page for root endpoint", async () => {
  const req = new Request("https://example.com/akademy-app");
  const res = await handler.fetch(req);
  assertEquals(res.status, 200);

  const body = await res.json();
  assertEquals(body.message, "Akademy App API");
});

Deno.test("Handler returns 401 for admin routes without authentication", async () => {
  const req = new Request("https://example.com/akademy-app/admin/agreements");
  const res = await handler.fetch(req);
  assertEquals(res.status, 401);

  const body = await res.json();
  assertEquals(body.error, "Unauthorized");
});

Deno.test("Handler returns 200 for admin routes with authentication", async () => {
  const req = new Request("https://example.com/akademy-app/admin/agreements", {
    headers: {
      "admin": "mock-admin-secret",
    },
  });
  const res = await handler.fetch(req);
  assertEquals(res.status, 200);
});

Deno.test("Handler returns 401 for super admin creation without JWT", async () => {
  const req = new Request("https://example.com/akademy-app/super-admin", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      email: "admin@example.com",
      password: "password123",
      agreement_id: "00000000-0000-0000-0000-000000000000",
      role_id: "00000000-0000-0000-0000-000000000000",
      headquarter_id: "00000000-0000-0000-0000-000000000000",
    }),
  });
  const res = await handler.fetch(req);
  assertEquals(res.status, 401);

  const body = await res.json();
  assertEquals(body.error, "Unauthorized");
});

Deno.test("Handler returns CORS headers for OPTIONS requests", async () => {
  const req = new Request("https://example.com/akademy-app", {
    method: "OPTIONS",
  });
  const res = await handler.fetch(req);
  assertEquals(res.status, 204);

  for (const [key, value] of Object.entries(corsHeaders)) {
    assertEquals(res.headers.get(key), value);
  }
});
