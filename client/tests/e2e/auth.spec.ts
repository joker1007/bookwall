import { test, expect, openUserMenu } from "./helpers/test-base";

test.describe("authentication", () => {
  test("signup lands on home and survives a reload", async ({ page, signup }) => {
    await signup();
    await expect(page.getByRole("heading", { name: "Home" })).toBeVisible();

    await page.reload();
    await expect(page).toHaveURL(/\/ui\/?(\?.*)?$/);
    await expect(page.getByRole("heading", { name: "Home" })).toBeVisible();
  });

  test("logout returns to /login and the same credentials log back in", async ({
    page,
    signup,
    login,
  }) => {
    const creds = await signup();

    await openUserMenu(page);
    await page.getByRole("menuitem", { name: "Log out" }).click();
    await expect(page).toHaveURL(/\/ui\/login(\?.*)?$/);

    await login(creds);
    await expect(page.getByRole("heading", { name: "Home" })).toBeVisible();
  });

  test("invalid login surfaces an inline error", async ({ page }) => {
    await page.goto("/ui/login");
    await page.locator("#email").fill("nobody@example.com");
    await page.locator("#password").fill("wrongpassword");
    await page.getByRole("button", { name: "Log in", exact: true }).click();

    await expect(
      page.getByText("Incorrect email or password."),
    ).toBeVisible();
    await expect(page).toHaveURL(/\/ui\/login(\?.*)?$/);
  });
});

test.describe("public registration", () => {
  test("signup closes after the first account and reopens from settings", async ({
    page,
    signup,
    login,
  }) => {
    await page.goto("/ui/login");
    await expect(page.getByRole("link", { name: "Sign up" })).toBeVisible();

    const creds = await signup();

    await openUserMenu(page);
    await page.getByRole("menuitem", { name: "Log out" }).click();
    await expect(page).toHaveURL(/\/ui\/login(\?.*)?$/);
    await expect(page.getByRole("button", { name: "Log in", exact: true })).toBeVisible();
    await expect(page.getByRole("link", { name: "Sign up" })).toHaveCount(0);

    await page.goto("/ui/signup");
    await expect(page).toHaveURL(/\/ui\/login(\?.*)?$/);

    const closed = await page.request.post("/api/registrations", {
      data: {
        email_address: "intruder@example.com",
        password: "password1234",
        password_confirmation: "password1234",
      },
    });
    expect(closed.status()).toBe(403);

    await login(creds);
    await page.goto("/ui/settings/libraries");
    const toggle = page.getByRole("button", { name: "Public registration" });
    await expect(toggle).toHaveAttribute("aria-pressed", "false");
    await toggle.click();
    await expect(toggle).toHaveAttribute("aria-pressed", "true");

    await openUserMenu(page);
    await page.getByRole("menuitem", { name: "Log out" }).click();
    await expect(page).toHaveURL(/\/ui\/login(\?.*)?$/);
    await expect(page.getByRole("link", { name: "Sign up" })).toBeVisible();

    await signup();
    await expect(page.getByRole("heading", { name: "Home" })).toBeVisible();
  });
});
