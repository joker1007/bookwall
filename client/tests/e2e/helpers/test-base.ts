import {
  test as base,
  expect,
  type APIRequestContext,
  type BrowserContext,
  type Page,
} from "@playwright/test";

type Credentials = { email: string; password: string };

type Fixtures = {
  resetDb: void;
  signup: (creds?: Partial<Credentials>) => Promise<Credentials>;
  login: (creds: Credentials) => Promise<void>;
  setLanguage: (code: "en" | "ja") => Promise<void>;
};

export const test = base.extend<Fixtures>({
  // Reset the Rails DB before every test so we always start from a clean slate.
  // BOOKWALL_E2E_RESET must be set for the Rails server (handled in
  // playwright.config.ts) — otherwise the endpoint 404s and tests fail fast.
  resetDb: [
    async ({ request, context }, use) => {
      await resetServer(request);
      // Default the UI language to English unless a test overrides it.
      // addInitScript fires before any page script, so it beats LanguageDetector.
      await applyLanguage(context, "en");
      await use();
    },
    { auto: true },
  ],

  setLanguage: async ({ context }, use) => {
    await use(async (code) => {
      // Force-set the language regardless of any earlier default. This script
      // is registered AFTER the resetDb fixture's conditional "en" default, so
      // it wins on every page load.
      await context.addInitScript((c) => {
        window.localStorage.setItem("bookwall-language", c);
      }, code);
    });
  },

  signup: async ({ page }, use) => {
    await use(async (overrides) => {
      const creds: Credentials = {
        email: overrides?.email ?? uniqueEmail(),
        password: overrides?.password ?? "password1234",
      };
      await page.goto("/ui/signup");
      await page.locator("#email").fill(creds.email);
      await page.locator("#password").fill(creds.password);
      await page.locator("#password_confirmation").fill(creds.password);
      await page.getByRole("button", { name: /Create account|アカウントを作成/ }).click();
      await page.waitForURL(/\/ui\/?(\?.*)?$/);
      await normalizeHomeUrl(page);
      return creds;
    });
  },

  login: async ({ page }, use) => {
    await use(async (creds) => {
      await page.goto("/ui/login");
      await page.locator("#email").fill(creds.email);
      await page.locator("#password").fill(creds.password);
      await page.getByRole("button", { name: /Log in|ログイン/ }).click();
      await page.waitForURL(/\/ui\/?(\?.*)?$/);
      await normalizeHomeUrl(page);
    });
  },
});

export { expect };

async function resetServer(request: APIRequestContext) {
  const res = await request.post("/api/test_support/reset");
  if (!res.ok()) {
    throw new Error(
      `reset failed: HTTP ${res.status()} — make sure Rails was started with BOOKWALL_E2E_RESET=1 (response: ${await res.text()})`,
    );
  }
}

async function applyLanguage(context: BrowserContext, code: "en" | "ja") {
  // addInitScript runs on every navigation / reload, so we only set the
  // language if nothing has been stored yet. Otherwise UI-driven language
  // changes would be reverted whenever the page reloads in a test.
  await context.addInitScript((c) => {
    if (!window.localStorage.getItem("bookwall-language")) {
      window.localStorage.setItem("bookwall-language", c);
    }
  }, code);
}

function uniqueEmail() {
  return `e2e-${Date.now()}-${Math.floor(Math.random() * 1_000_000)}@example.com`;
}

export async function openUserMenu(page: Page) {
  // Header user menu trigger button has aria-label = t("app.userMenu")
  await page.getByRole("button", { name: /User menu|ユーザーメニュー/ }).click();
}

// React Router under `basename="/ui"` can land us on `/ui` (no trailing slash)
// after navigate("/"), but Vite's dev server only serves the SPA at `/ui/` and
// otherwise shows its "did you mean to visit /ui/?" helper page. Normalize so
// page.reload() works deterministically across tests.
async function normalizeHomeUrl(page: Page) {
  const url = new URL(page.url());
  if (url.pathname === "/ui") {
    url.pathname = "/ui/";
    await page.goto(url.toString());
  }
}
