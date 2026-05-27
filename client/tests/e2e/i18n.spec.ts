import { test, expect, openUserMenu } from "./helpers/test-base";

test.describe("i18n", () => {
  test("switches to Japanese, persists across reload, and switches back", async ({
    page,
    signup,
  }) => {
    await signup();
    await expect(page.getByRole("heading", { name: "Home" })).toBeVisible();

    // EN → JA
    await openUserMenu(page);
    await page.getByRole("menuitem", { name: "日本語", exact: true }).click();
    await expect(page.getByRole("heading", { name: "ホーム" })).toBeVisible();
    // Sidebar reflects the new language too.
    await expect(
      page.getByRole("link", { name: "シリーズ", exact: true }).first(),
    ).toBeVisible();

    // Reload preserves the choice via localStorage.
    await page.reload();
    await expect(page.getByRole("heading", { name: "ホーム" })).toBeVisible();
    const stored = await page.evaluate(() =>
      window.localStorage.getItem("bookwall-language"),
    );
    expect(stored).toBe("ja");

    // JA → EN
    await openUserMenu(page);
    await page.getByRole("menuitem", { name: "English", exact: true }).click();
    await expect(page.getByRole("heading", { name: "Home" })).toBeVisible();
  });

  test("login page localizes when language is preset to ja", async ({
    page,
    setLanguage,
  }) => {
    await setLanguage("ja");
    await page.goto("/ui/login");
    // CardTitle is a div so match by text rather than heading role.
    await expect(page.getByText("Bookwall にログイン")).toBeVisible();
    await expect(
      page.getByRole("button", { name: "ログイン", exact: true }),
    ).toBeVisible();
  });
});
