import { fileURLToPath } from "node:url";
import type { Page } from "@playwright/test";
import { test, expect } from "./helpers/test-base";

// The Rails test env runs ActiveJob inline, so POST /scans ingests the
// fixture books synchronously — no polling needed.
const FIXTURES_PATH = fileURLToPath(
  new URL("../../../server/spec/fixtures/files", import.meta.url),
);

// Create a library at the fixtures dir and scan it. Uses page.request so the
// calls carry the signed-in session cookie. Returns the library id.
async function seedLibrary(page: Page) {
  const libRes = await page.request.post("/api/libraries", {
    data: { name: "Bulk Fixtures", path: FIXTURES_PATH },
  });
  expect(libRes.ok()).toBeTruthy();
  const lib = (await libRes.json()) as { id: number };
  const scanRes = await page.request.post(`/api/libraries/${lib.id}/scans`);
  expect(scanRes.status()).toBe(202);
  return lib.id;
}

test.describe("bulk book actions", () => {
  test("favorite, add to a new collection, and delete a selection in bulk", async ({
    page,
    signup,
  }) => {
    await signup();
    const libraryId = await seedLibrary(page);

    await page.goto(`/ui/libraries/${libraryId}`);
    // The fixtures scan in 5 books; wait until the grid has rendered.
    await expect(page.locator("article").first()).toBeVisible();
    const bookCount = await page.locator("article").count();
    expect(bookCount).toBeGreaterThan(1);

    // Enter selection mode and select everything on the page.
    await page.getByRole("button", { name: "Select", exact: true }).click();
    await page.getByRole("button", { name: "Select all" }).click();
    await expect(page.getByText(`${bookCount} selected`)).toBeVisible();

    // --- Bulk favorite ----------------------------------------------------
    await page.getByRole("button", { name: "Favorite", exact: true }).click();
    // The action clears the selection on success.
    await expect(page.getByText(`${bookCount} selected`)).toBeHidden();
    await page.goto("/ui/favorites");
    await expect(page.locator("article")).toHaveCount(bookCount);

    // --- Bulk add to a brand-new collection -------------------------------
    await page.goto(`/ui/libraries/${libraryId}`);
    await expect(page.locator("article").first()).toBeVisible();
    await page.getByRole("button", { name: "Select", exact: true }).click();
    await page.getByRole("button", { name: "Select all" }).click();
    await page.getByRole("button", { name: "Add to collection", exact: true }).click();

    const dialog = page.getByRole("dialog", { name: "Add to collection" });
    await dialog.getByLabel("Or create a new one").fill("E2E Collection");
    await dialog.getByRole("button", { name: "Add to collection" }).click();
    await expect(dialog).toBeHidden();

    await page.goto("/ui/collections");
    await expect(page.getByText("E2E Collection")).toBeVisible();
    await page.getByRole("link", { name: "E2E Collection" }).click();
    await expect(page.locator("article")).toHaveCount(bookCount);

    // --- Bulk delete (with confirmation) ----------------------------------
    await page.goto(`/ui/libraries/${libraryId}`);
    await expect(page.locator("article").first()).toBeVisible();
    await page.getByRole("button", { name: "Select", exact: true }).click();
    await page.getByRole("button", { name: "Select all" }).click();
    await page.getByRole("button", { name: "Delete", exact: true }).click();

    const confirm = page.getByRole("alertdialog");
    await expect(confirm).toBeVisible();
    await confirm.getByRole("button", { name: "Delete", exact: true }).click();

    await expect(page.getByText("No books yet.")).toBeVisible();
  });
});
