import { defineConfig, devices } from "@playwright/test";

const RAILS_PORT = 3001;
const VITE_PORT = 5174;
// Use 127.0.0.1 explicitly: this machine's /etc/hosts resolves "localhost"
// to ::1 only and the kernel has IPv6 disabled, which makes both Falcon's
// bind and Node's HTTP health check unable to reach the test server.
const RAILS_HOST = "127.0.0.1";
const VITE_HOST = "127.0.0.1";
const BASE_URL = `http://${VITE_HOST}:${VITE_PORT}`;

export default defineConfig({
  testDir: "./tests/e2e",
  fullyParallel: false,
  workers: 1,
  retries: process.env.CI ? 1 : 0,
  reporter: process.env.CI ? [["github"], ["html", { open: "never" }]] : "list",
  timeout: 30_000,
  expect: { timeout: 7_000 },

  use: {
    baseURL: BASE_URL,
    trace: "retain-on-failure",
    screenshot: "only-on-failure",
    video: "retain-on-failure",
  },

  projects: [
    {
      name: "desktop-chromium",
      use: { ...devices["Desktop Chrome"], viewport: { width: 1280, height: 800 } },
    },
    {
      name: "mobile-chromium",
      // Use iPhone 12 viewport on Chromium (the device entry defaults to
      // webkit, which isn't installed in this env).
      use: {
        viewport: { width: 390, height: 844 },
        deviceScaleFactor: 3,
        isMobile: true,
        hasTouch: true,
        defaultBrowserType: "chromium",
      },
      testMatch: /(smoke|mobile)\.spec\.ts$/,
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
