import { test, expect } from "./helpers/test-base";

test.describe("UI state persistence", () => {
  test("display mode toggle persists across reload via localStorage", async ({
    page,
    signup,
  }) => {
    await signup();
    await expect(page.getByRole("heading", { name: "Home" })).toBeVisible();

    const gridBtn = page.getByRole("radio", { name: "Grid view" });
    const listBtn = page.getByRole("radio", { name: "List view" });

    // Default is grid (uiStore initial state).
    await expect(gridBtn).toHaveAttribute("data-state", "on");

    await listBtn.click();
    await expect(listBtn).toHaveAttribute("data-state", "on");
    await expect(gridBtn).toHaveAttribute("data-state", "off");

    await page.reload();
    await expect(
      page.getByRole("radio", { name: "List view" }),
    ).toHaveAttribute("data-state", "on");

    // Persisted Zustand store payload is visible in localStorage.
    const persisted = await page.evaluate(() =>
      window.localStorage.getItem("bookwall-ui"),
    );
    expect(persisted).toContain('"displayMode":"list"');
  });
});
