import { test, expect } from "./helpers/test-base";

test.describe("library sidebar", () => {
  test("shows empty hint when no libraries are registered", async ({ page, signup }) => {
    await signup();
    await expect(page.getByText("No libraries yet")).toBeVisible();
  });

  test("a library created from settings appears in the sidebar and navigates to its detail page", async ({
    page,
    signup,
  }) => {
    await signup();

    await page.goto("/ui/settings/libraries");
    await page.getByRole("button", { name: "Add", exact: true }).click();
    const dialog = page.getByRole("dialog");
    await expect(dialog).toBeVisible();
    await dialog.locator("#lib-name").fill("Home NAS");
    await dialog.locator("#lib-path").fill("/tmp/bookwall-sidebar-lib");
    await dialog.getByRole("button", { name: "Save", exact: true }).click();
    await expect(dialog).not.toBeVisible();

    // Sidebar refreshes via TanStack Query invalidation
    const sidebarLink = page
      .locator("nav")
      .getByRole("link", { name: "Home NAS", exact: true });
    await expect(sidebarLink).toBeVisible();

    await sidebarLink.click();
    await expect(page).toHaveURL(/\/ui\/libraries\/\d+(\?.*)?$/);
    await expect(page.getByRole("heading", { name: "Home NAS" })).toBeVisible();
  });

  test("deleting a library shows a deletion-started dialog and removes it from the list", async ({
    page,
    signup,
  }) => {
    await signup();

    await page.goto("/ui/settings/libraries");
    await page.getByRole("button", { name: "Add", exact: true }).click();
    const dialog = page.getByRole("dialog");
    await expect(dialog).toBeVisible();
    await dialog.locator("#lib-name").fill("Trash Lib");
    await dialog.locator("#lib-path").fill("/tmp/bookwall-trash-lib");
    await dialog.getByRole("button", { name: "Save", exact: true }).click();
    await expect(dialog).not.toBeVisible();

    const row = page.getByRole("row", { name: /Trash Lib/ });
    await expect(row).toBeVisible();

    // The delete handler goes through window.confirm; auto-accept it.
    page.once("dialog", (d) => d.accept());
    await row.getByRole("button", { name: "Delete", exact: true }).click();

    await expect(page.getByText("Deletion started")).toBeVisible();
    await page.keyboard.press("Escape");
    await expect(page.getByText("Deletion started")).not.toBeVisible();

    await expect(page.getByRole("row", { name: /Trash Lib/ })).toHaveCount(0);
  });
});
