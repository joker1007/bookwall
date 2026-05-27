import { test, expect } from "./helpers/test-base";

test.describe("taxonomy index pages", () => {
  test("series index renders heading and empty state", async ({ page, signup }) => {
    await signup();
    await page.goto("/ui/series");

    await expect(page.getByRole("heading", { name: "Series" })).toBeVisible();
    await expect(
      page.getByText("No series yet. Add a library and run a scan."),
    ).toBeVisible();
  });

  test("authors index renders heading and empty state", async ({ page, signup }) => {
    await signup();
    await page.goto("/ui/authors");

    await expect(page.getByRole("heading", { name: "Authors" })).toBeVisible();
    await expect(page.getByText("No authors yet.")).toBeVisible();
  });

  test("tags index renders heading and empty state", async ({ page, signup }) => {
    await signup();
    await page.goto("/ui/tags");

    await expect(page.getByRole("heading", { name: "Tags" })).toBeVisible();
    await expect(page.getByText("No tags yet.")).toBeVisible();
  });

  test("sidebar links navigate to the index pages from home", async ({ page, signup }) => {
    await signup();

    await page.getByRole("link", { name: "Series", exact: true }).first().click();
    await expect(page).toHaveURL(/\/ui\/series(\?.*)?$/);
    await expect(page.getByRole("heading", { name: "Series" })).toBeVisible();

    await page.getByRole("link", { name: "Authors", exact: true }).first().click();
    await expect(page).toHaveURL(/\/ui\/authors(\?.*)?$/);
    await expect(page.getByRole("heading", { name: "Authors" })).toBeVisible();

    await page.getByRole("link", { name: "Tags", exact: true }).first().click();
    await expect(page).toHaveURL(/\/ui\/tags(\?.*)?$/);
    await expect(page.getByRole("heading", { name: "Tags" })).toBeVisible();
  });
});
