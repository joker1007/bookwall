import { defineConfig, devices } from "@playwright/test";

// Dedicated config for recording the "guided tour" demo video.
// Kept separate from playwright.config.ts so the normal e2e suite
// (video: "retain-on-failure", testDir ./tests/e2e) is untouched.
// The whole journey lives in a single test under ./tests/demo, which
// yields one continuous .webm per BrowserContext.

const RAILS_PORT = 3001;
const VITE_PORT = 5174;
// Mirror playwright.config.ts: this machine resolves "localhost" to ::1
// only with IPv6 disabled, so both Falcon's bind and Node's health check
// must use 127.0.0.1 explicitly.
const RAILS_HOST = "127.0.0.1";
const VITE_HOST = "127.0.0.1";
const BASE_URL = `http://${VITE_HOST}:${VITE_PORT}`;

export default defineConfig({
  testDir: "./tests/demo",
  fullyParallel: false,
  workers: 1,
  retries: 0,
  reporter: "list",
  // Long timeout: the tour walks every scenario with deliberate pauses.
  timeout: 300_000,
  expect: { timeout: 15_000 },

  use: {
    baseURL: BASE_URL,
    viewport: { width: 1280, height: 800 },
    // Always record, sized to the viewport so the webm is the demo output.
    video: { mode: "on", size: { width: 1280, height: 800 } },
    trace: "retain-on-failure",
    // Slow every action down so the recording is watchable.
    launchOptions: { slowMo: 400 },
  },

  projects: [
    {
      name: "desktop-chromium",
      use: { ...devices["Desktop Chrome"], viewport: { width: 1280, height: 800 } },
    },
  ],

  webServer: [
    {
      name: "rails",
      command:
        "BOOKWALL_E2E_RESET=1 RAILS_ENV=test_e2e bin/rails db:prepare && " +
        `BOOKWALL_E2E_RESET=1 RAILS_ENV=test_e2e bundle exec falcon serve --bind http://${RAILS_HOST}:${RAILS_PORT} --count 1`,
      cwd: "../server",
      url: `http://${RAILS_HOST}:${RAILS_PORT}/up`,
      reuseExistingServer: !process.env.CI,
      stdout: "pipe",
      stderr: "pipe",
      timeout: 120_000,
    },
    {
      name: "vite",
      command: "npm run dev -- --host 127.0.0.1",
      cwd: ".",
      env: {
        BOOKWALL_API_TARGET: `http://${RAILS_HOST}:${RAILS_PORT}`,
        BOOKWALL_VITE_PORT: String(VITE_PORT),
      },
      url: `${BASE_URL}/ui/`,
      reuseExistingServer: !process.env.CI,
      stdout: "pipe",
      stderr: "pipe",
      timeout: 60_000,
    },
  ],
});
