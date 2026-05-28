import { test, expect } from "./helpers/test-base";

test.describe("settings — libraries", () => {
  test("create, list, and delete a library", async ({ page, signup }) => {
    await signup();
    await page.goto("/ui/settings/libraries");
    await expect(
      page.getByRole("heading", { name: "Library settings" }),
    ).toBeVisible();

    // Empty state visible up front.
    await expect(page.getByText("No libraries yet.")).toBeVisible();

    await page.getByRole("button", { name: "Add", exact: true }).click();
    const dialog = page.getByRole("dialog");
    await expect(dialog).toBeVisible();
    await dialog.locator("#lib-name").fill("E2E Library");
    await dialog.locator("#lib-path").fill("/tmp/bookwall-e2e-library");
    await dialog.getByRole("button", { name: "Save", exact: true }).click();

    await expect(dialog).not.toBeVisible();
    await expect(page.getByRole("cell", { name: "E2E Library" })).toBeVisible();
    await expect(
      page.getByRole("cell", { name: "/tmp/bookwall-e2e-library" }),
    ).toBeVisible();

    // Auto-accept the window.confirm prompt that the delete button triggers.
    page.once("dialog", (d) => d.accept());
    await page.getByRole("button", { name: "Delete", exact: true }).click();
    await expect(page.getByText("No libraries yet.")).toBeVisible();
  });
});

test.describe("settings — API tokens", () => {
  test("issue a token, see plaintext, dismiss, and re-reveal the same value", async ({
    page,
    signup,
  }) => {
    await signup();
    await page.goto("/ui/settings/api_tokens");
    await expect(
      page.getByRole("heading", { name: "API tokens" }),
    ).toBeVisible();
    await expect(page.getByText("No tokens issued yet.")).toBeVisible();

    // Open the Issue dialog (header button) and submit.
    await page
      .getByRole("button", { name: "Issue", exact: true })
      .first()
      .click();
    const dialog = page.getByRole("dialog");
    await expect(dialog).toBeVisible();
    await dialog.locator("#token-name").fill("E2E Token");
    await dialog.getByRole("button", { name: "Issue", exact: true }).click();
    await expect(dialog).not.toBeVisible();

    // Plain-text reveal panel appears right after issuance.
    await expect(page.getByText("Token issued")).toBeVisible();
    const tokenInput = page.locator('input[readonly]').first();
    const issued = await tokenInput.inputValue();
    expect(issued).toMatch(/^[A-Za-z0-9_-]{20,}$/);

    // Row shows up in the list.
    await expect(page.getByRole("cell", { name: "E2E Token" })).toBeVisible();

    // Dismiss the reveal panel.
    await page.getByRole("button", { name: "Close", exact: true }).click();
    await expect(page.getByText("Token issued")).not.toBeVisible();

    // Re-reveal via the row's "Show token" button — same value (private deployment
    // assumption: tokens are re-displayable).
    await page.getByRole("button", { name: "Show token", exact: true }).click();
    await expect(
      page.getByRole("heading", { name: "Token", exact: true }),
    ).toBeVisible();
    await expect(page.locator('input[readonly]').first()).toHaveValue(issued);
  });
});
