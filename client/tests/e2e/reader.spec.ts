import { fileURLToPath } from "node:url";
import { test, expect } from "./helpers/test-base";

// Inline ActiveJob in the test env ingests the fixtures synchronously, so
// the scan POST is enough to make sample.cbz (4 pages) queryable.
const FIXTURES_PATH = fileURLToPath(
  new URL("../../../server/spec/fixtures/files", import.meta.url),
);

test.describe("image reader progress restore", () => {
  test("opens a CBZ at the saved page without flashing page 1", async ({
    page,
    signup,
  }) => {
    await signup();

    const libRes = await page.request.post("/api/libraries", {
      data: { name: "Reader Fixtures", path: FIXTURES_PATH },
    });
    expect(libRes.ok()).toBeTruthy();
    const lib = (await libRes.json()) as { id: number };
    const scanRes = await page.request.post(`/api/libraries/${lib.id}/scans`);
    expect(scanRes.status()).toBe(202);

    const listRes = await page.request.get(`/api/books?library_id=${lib.id}`);
    expect(listRes.ok()).toBeTruthy();
    const { books } = (await listRes.json()) as {
      books: { id: number; file_format: string }[];
    };
    const cbz = books.find((b) => b.file_format === "cbz");
    expect(cbz, "fixtures should contain a CBZ book").toBeTruthy();
    const bookId = cbz!.id;

    // Save progress at page index 2 (the 3rd of 4 pages). From here the
    // reader preloads pages 1 and 3 only — page 0 is never touched, so a
    // request for it would mean the reader painted page 0 before restoring.
    const SAVED_PAGE = 2;
    const progRes = await page.request.patch(`/api/books/${bookId}/progress`, {
      data: { current_page: SAVED_PAGE },
    });
    expect(progRes.ok()).toBeTruthy();

    const requestedPages: number[] = [];
    await page.route(`**/api/books/${bookId}/pages/*`, async (route) => {
      const m = route.request().url().match(/\/pages\/(\d+)/);
      if (m) requestedPages.push(Number(m[1]));
      await route.continue();
    });

    await page.goto(`/ui/books/${bookId}/read`);

    // The saved page must be the first thing painted.
    await expect(page.getByText(`${SAVED_PAGE + 1} / 4`)).toBeVisible();
    await expect(
      page.locator(`img[src$="/pages/${SAVED_PAGE}"]`),
    ).toBeVisible();

    // Regression guard: page 0 must never have been fetched.
    expect(requestedPages).not.toContain(0);
  });
});
