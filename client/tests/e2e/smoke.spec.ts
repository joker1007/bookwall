import { test, expect } from "./helpers/test-base";

test.describe("smoke", () => {
  test("unauthenticated visit to /ui redirects to /ui/login in dark theme", async ({ page }) => {
    await page.goto("/ui/");
    await expect(page).toHaveURL(/\/ui\/login(\?.*)?$/);

    // shadcn/ui CardTitle renders as <div>, not <h*>, so match by text.
    await expect(page.getByText("Sign in to Bookwall")).toBeVisible();

    // Dark theme is applied via <html class="dark">.
    await expect(page.locator("html")).toHaveClass(/dark/);
  });

  test("server health endpoint is reachable through the vite proxy", async ({ request }) => {
    const res = await request.get("/up");
    expect(res.ok()).toBeTruthy();
  });

  test("login form has accessible email and password inputs", async ({ page }) => {
    await page.goto("/ui/login");
    await expect(page.locator("#email")).toBeVisible();
    await expect(page.locator("#password")).toBeVisible();
    await expect(
      page.getByRole("button", { name: "Log in", exact: true }),
    ).toBeVisible();
  });
});
