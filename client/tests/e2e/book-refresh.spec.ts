import { fileURLToPath } from "node:url";
import { test, expect } from "./helpers/test-base";

const FIXTURES_PATH = fileURLToPath(
  new URL("../../../server/spec/fixtures/files", import.meta.url),
);

type BookJson = { id: number; title: string; file_path: string; cover: { url: string } | null };

test.describe("book refresh", () => {
  test("reloads metadata from the file and regenerates the cover", async ({ page, signup }) => {
    await signup();
    const libRes = await page.request.post("/api/libraries", {
      data: { name: "Refresh Fixtures", path: FIXTURES_PATH },
    });
    const lib = (await libRes.json()) as { id: number };
    expect((await page.request.post(`/api/libraries/${lib.id}/scans`)).status()).toBe(202);

    const listRes = await page.request.get("/api/books", { params: { library_id: lib.id } });
    const { books } = (await listRes.json()) as { books: BookJson[] };
    const book = books.find((b) => b.file_path === "sample.cbz")!;
    const originalTitle = book.title;
    await page.request.patch(`/api/books/${book.id}`, { data: { title: "Edited Title" } });

    await page.goto(`/ui/books/${book.id}`);
    await expect(page.getByRole("heading", { level: 1 })).toContainText("Edited Title");

    page.once("dialog", (d) => d.accept());
    await page.getByRole("button", { name: "Reload metadata" }).click();
    await expect(page.getByRole("heading", { level: 1 })).toContainText(originalTitle);

    const cover = page.locator("img").first();
    const before = await cover.getAttribute("src");
    await page.getByRole("button", { name: "Regenerate thumbnail" }).click();
    await expect(cover).not.toHaveAttribute("src", before ?? "");
    await expect(cover).toBeVisible();
  });
});
