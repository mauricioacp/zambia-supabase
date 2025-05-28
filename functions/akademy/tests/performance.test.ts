import { assert, assertEquals } from "@std/assert";

/**
 * Performance and load testing for Akademy API
 */

interface PerformanceMetrics {
  totalRequests: number;
  successfulRequests: number;
  failedRequests: number;
  averageResponseTime: number;
  minResponseTime: number;
  maxResponseTime: number;
  p95ResponseTime: number;
  requestsPerSecond: number;
}

class PerformanceTestSuite {
  private baseUrl = "http://localhost:54321/functions/v1/akademy";
  private authToken = "mock-level-30-token"; // Use appropriate test token

  private async makeRequest(
    endpoint: string,
    method: string = "GET",
    body?: unknown,
  ): Promise<{ responseTime: number; status: number; success: boolean }> {
    const startTime = performance.now();

    try {
      const response = await fetch(`${this.baseUrl}${endpoint}`, {
        method,
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${this.authToken}`,
        },
        body: body ? JSON.stringify(body) : undefined,
      });

      const endTime = performance.now();

      return {
        responseTime: endTime - startTime,
        status: response.status,
        success: response.ok,
      };
    } catch (error) {
      const endTime = performance.now();
      console.error("Request failed:", error);

      return {
        responseTime: endTime - startTime,
        status: 0,
        success: false,
      };
    }
  }

  private calculateMetrics(
    results: Array<{ responseTime: number; success: boolean }>,
  ): PerformanceMetrics {
    const responseTimes = results.map((r) => r.responseTime);
    const successfulRequests = results.filter((r) => r.success).length;

    responseTimes.sort((a, b) => a - b);

    const p95Index = Math.floor(responseTimes.length * 0.95);

    return {
      totalRequests: results.length,
      successfulRequests,
      failedRequests: results.length - successfulRequests,
      averageResponseTime: responseTimes.reduce((a, b) => a + b, 0) /
        responseTimes.length,
      minResponseTime: Math.min(...responseTimes),
      maxResponseTime: Math.max(...responseTimes),
      p95ResponseTime: responseTimes[p95Index] || 0,
      requestsPerSecond: 0, // Will be calculated based on test duration
    };
  }

  private printMetrics(
    testName: string,
    metrics: PerformanceMetrics,
    duration: number,
  ): void {
    metrics.requestsPerSecond = metrics.totalRequests / (duration / 1000);

    console.log(`\n📊 ${testName} Performance Metrics:`);
    console.log(`  Total Requests: ${metrics.totalRequests}`);
    console.log(`  Successful: ${metrics.successfulRequests}`);
    console.log(`  Failed: ${metrics.failedRequests}`);
    console.log(
      `  Success Rate: ${
        ((metrics.successfulRequests / metrics.totalRequests) * 100).toFixed(2)
      }%`,
    );
    console.log(
      `  Average Response Time: ${metrics.averageResponseTime.toFixed(2)}ms`,
    );
    console.log(`  Min Response Time: ${metrics.minResponseTime.toFixed(2)}ms`);
    console.log(`  Max Response Time: ${metrics.maxResponseTime.toFixed(2)}ms`);
    console.log(`  P95 Response Time: ${metrics.p95ResponseTime.toFixed(2)}ms`);
    console.log(`  Requests/Second: ${metrics.requestsPerSecond.toFixed(2)}`);
  }

  // Test sequential requests performance
  async testSequentialRequests(): Promise<void> {
    console.log("🔥 Testing sequential request performance...");

    const startTime = performance.now();
    const results = [];
    const requestCount = 100;

    for (let i = 0; i < requestCount; i++) {
      const result = await this.makeRequest("/health");
      results.push(result);

      if (i % 20 === 0) {
        console.log(`  Completed ${i + 1}/${requestCount} requests`);
      }
    }

    const endTime = performance.now();
    const metrics = this.calculateMetrics(results);
    this.printMetrics("Sequential Requests", metrics, endTime - startTime);

    // Assertions for performance
    assert(
      metrics.averageResponseTime < 1000,
      "Average response time should be under 1 second",
    );
    assert(
      metrics.p95ResponseTime < 2000,
      "P95 response time should be under 2 seconds",
    );
    assert(
      (metrics.successfulRequests / metrics.totalRequests) > 0.95,
      "Success rate should be above 95%",
    );
  }

  // Test concurrent requests performance
  async testConcurrentRequests(): Promise<void> {
    console.log("🚀 Testing concurrent request performance...");

    const startTime = performance.now();
    const concurrency = 20;
    const requestsPerWorker = 10;

    const promises = Array.from({ length: concurrency }, async () => {
      const results = [];
      for (let i = 0; i < requestsPerWorker; i++) {
        const result = await this.makeRequest("/health");
        results.push(result);
      }
      return results;
    });

    const allResults = (await Promise.all(promises)).flat();
    const endTime = performance.now();

    const metrics = this.calculateMetrics(allResults);
    this.printMetrics("Concurrent Requests", metrics, endTime - startTime);

    // Assertions for concurrent performance
    assert(
      metrics.averageResponseTime < 1500,
      "Average response time under load should be under 1.5 seconds",
    );
    assert(
      (metrics.successfulRequests / metrics.totalRequests) > 0.90,
      "Success rate under load should be above 90%",
    );
  }

  // Test API endpoints under load
  async testEndpointPerformance(): Promise<void> {
    console.log("🎯 Testing individual endpoint performance...");

    const endpoints = [
      { path: "/health", method: "GET" },
      { path: "/", method: "GET" },
      {
        path: "/create-user",
        method: "POST",
        body: { agreement_id: "550e8400-e29b-41d4-a716-446655440000" },
      },
    ];

    for (const endpoint of endpoints) {
      console.log(`  Testing ${endpoint.method} ${endpoint.path}...`);

      const startTime = performance.now();
      const results = [];

      for (let i = 0; i < 50; i++) {
        const result = await this.makeRequest(
          endpoint.path,
          endpoint.method,
          endpoint.body,
        );
        results.push(result);
      }

      const endTime = performance.now();
      const metrics = this.calculateMetrics(results);

      console.log(
        `    Avg: ${metrics.averageResponseTime.toFixed(2)}ms, ` +
          `P95: ${metrics.p95ResponseTime.toFixed(2)}ms, ` +
          `Success: ${
            ((metrics.successfulRequests / metrics.totalRequests) * 100)
              .toFixed(1)
          }%`,
      );
    }
  }

  // Test memory usage patterns
  async testMemoryUsage(): Promise<void> {
    console.log("💾 Testing memory usage patterns...");

    // Test with varying payload sizes
    const payloadSizes = [100, 1000, 10000, 50000]; // bytes

    for (const size of payloadSizes) {
      const largePayload = {
        agreement_id: "550e8400-e29b-41d4-a716-446655440000",
        data: "x".repeat(size),
      };

      const startTime = performance.now();
      const results = [];

      for (let i = 0; i < 20; i++) {
        const result = await this.makeRequest(
          "/create-user",
          "POST",
          largePayload,
        );
        results.push(result);
      }

      const endTime = performance.now();
      const metrics = this.calculateMetrics(results);

      console.log(
        `  Payload size ${size} bytes: ` +
          `Avg: ${metrics.averageResponseTime.toFixed(2)}ms, ` +
          `Success: ${
            ((metrics.successfulRequests / metrics.totalRequests) * 100)
              .toFixed(1)
          }%`,
      );
    }
  }

  // Test sustained load
  async testSustainedLoad(): Promise<void> {
    console.log("⏰ Testing sustained load (30 seconds)...");

    const duration = 30000; // 30 seconds
    const interval = 100; // Request every 100ms
    const startTime = performance.now();
    const results = [];

    while (performance.now() - startTime < duration) {
      const result = await this.makeRequest("/health");
      results.push(result);

      // Wait for interval
      await new Promise((resolve) => setTimeout(resolve, interval));

      // Progress indicator
      const elapsed = performance.now() - startTime;
      if (
        Math.floor(elapsed / 5000) > Math.floor((elapsed - interval) / 5000)
      ) {
        console.log(
          `  ${
            Math.floor(elapsed / 1000)
          }s elapsed, ${results.length} requests completed`,
        );
      }
    }

    const endTime = performance.now();
    const metrics = this.calculateMetrics(results);
    this.printMetrics("Sustained Load", metrics, endTime - startTime);

    // Check for performance degradation
    const firstHalf = results.slice(0, Math.floor(results.length / 2));
    const secondHalf = results.slice(Math.floor(results.length / 2));

    const firstHalfAvg = firstHalf.reduce((sum, r) => sum + r.responseTime, 0) /
      firstHalf.length;
    const secondHalfAvg =
      secondHalf.reduce((sum, r) => sum + r.responseTime, 0) /
      secondHalf.length;

    const degradation = ((secondHalfAvg - firstHalfAvg) / firstHalfAvg) * 100;

    console.log(`  Performance degradation: ${degradation.toFixed(2)}%`);
    assert(
      degradation < 50,
      "Performance should not degrade more than 50% under sustained load",
    );
  }

  // Run all performance tests
  async runAllTests(): Promise<void> {
    console.log("🏁 Starting performance test suite...\n");

    try {
      await this.testSequentialRequests();
      await this.testConcurrentRequests();
      await this.testEndpointPerformance();
      await this.testMemoryUsage();
      await this.testSustainedLoad();

      console.log("\n✅ All performance tests completed!");
    } catch (error) {
      console.error("❌ Performance test failed:", error);
      throw error;
    }
  }
}

// Run performance tests
if (import.meta.main) {
  const perfSuite = new PerformanceTestSuite();
  await perfSuite.runAllTests();
}
