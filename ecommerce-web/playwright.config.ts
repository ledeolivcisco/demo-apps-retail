import { defineConfig, devices } from "@playwright/test";

/**
 * E2E tests drive a real browser against the deployed SPA (default http://localhost:8080).
 * Requires the stack behind nginx (or equivalent): product 8081, cart 8082, payment 8083.
 *
 * Override base URL: PLAYWRIGHT_BASE_URL=https://staging.example npx playwright test
 *
 * Docker loop tuning (set in compose for playwright-loop):
 *   PLAYWRIGHT_WORKERS=4
 *   PLAYWRIGHT_FULLY_PARALLEL=true
 *   PLAYWRIGHT_SYNTHETIC_PACE_MS=500
 */
const baseURL = process.env.PLAYWRIGHT_BASE_URL ?? "http://localhost:8080";

function parseWorkers(): number {
  const raw = process.env.PLAYWRIGHT_WORKERS;
  if (raw === undefined || raw === "") {
    return 1;
  }
  const parsed = Number(raw);
  return Number.isFinite(parsed) && parsed > 0 ? Math.floor(parsed) : 1;
}

function parseFullyParallel(): boolean {
  return process.env.PLAYWRIGHT_FULLY_PARALLEL === "true";
}

export default defineConfig({
  testDir: "./e2e",
  fullyParallel: parseFullyParallel(),
  workers: parseWorkers(),
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  reporter: [["list"]],
  timeout: 60_000,
  expect: { timeout: 15_000 },
  use: {
    baseURL,
    trace: "on-first-retry",
    screenshot: "only-on-failure",
    video: "retain-on-failure",
  },
  projects: [{ name: "chromium", use: { ...devices["Desktop Chrome"] } }],
});
