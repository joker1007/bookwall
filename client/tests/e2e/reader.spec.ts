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

    // The saved page must be the first thing painted. Scope to the header —
    // the bottom scrubber also renders a "n / 4" label.
    await expect(
      page.getByRole("banner").getByText(`${SAVED_PAGE + 1} / 4`),
    ).toBeVisible();
    await expect(
      page.locator(`img[src$="/pages/${SAVED_PAGE}"]`),
    ).toBeVisible();

    // Regression guard: page 0 must never have been fetched.
    expect(requestedPages).not.toContain(0);
  });

  // Regression: a book whose progress row exists from a page-progress save
  // (so last_read_at is non-null) but whose reader settings were never
  // touched (settings == {}) must still fall back to the user's
  // reader_defaults on re-open — not to the hard-coded initial values
  // (spread off / ltr / fit). Previously `persisted ?? defaults` kept the
  // empty `{}` and shadowed the defaults.
  test("falls back to reader_defaults when only page progress was saved", async ({
    page,
    signup,
  }) => {
    await signup();

    // Default to spread (two-page) view for every new book.
    const prefRes = await page.request.patch("/api/preferences", {
      data: { reader_defaults: { spread: true } },
    });
    expect(prefRes.ok()).toBeTruthy();

    const libRes = await page.request.post("/api/libraries", {
      data: { name: "Reader Defaults", path: FIXTURES_PATH },
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

    // Save ONLY the page position. The backend stamps last_read_at on every
    // save, so this flips the book out of the "never read" state while
    // leaving settings empty — exactly the condition that used to lose the
    // defaults on reload.
    const progRes = await page.request.patch(`/api/books/${bookId}/progress`, {
      data: { current_page: 0 },
    });
    expect(progRes.ok()).toBeTruthy();

    await page.goto(`/ui/books/${bookId}/read`);

    // Spread from defaults => both page 0 and page 1 render as main images
    // (their alt text carries the page indicator; preload images have empty
    // alt). With the bug, spread is off and only page 0 ("1 / 4") shows.
    await expect(page.getByAltText("1 / 4", { exact: true })).toBeVisible();
    await expect(page.getByAltText("2 / 4", { exact: true })).toBeVisible();
  });
});

test.describe("PDF reader", () => {
  async function openPdf(page: import("@playwright/test").Page) {
    const libRes = await page.request.post("/api/libraries", {
      data: { name: "PDF Fixtures", path: FIXTURES_PATH },
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
    const pdf = books.find((b) => b.file_format === "pdf");
    expect(pdf, "fixtures should contain a PDF book").toBeTruthy();
    return pdf!.id;
  }

  test("renders the page to a canvas with a selectable text layer", async ({
    page,
    signup,
  }) => {
    await signup();
    const bookId = await openPdf(page);

    await page.goto(`/ui/books/${bookId}/read`);

    // sample.pdf has 20 pages. Scope to the header — the scrubber also
    // renders a "1 / 20" label.
    await expect(page.getByRole("banner").getByText("1 / 20")).toBeVisible();
    await expect(page.locator("canvas").first()).toBeVisible();
    // The text layer is what makes selection / copy possible — proving it
    // rendered spans is proof the vector path (not a raster image) is used.
    const firstSpan = page.locator(".textLayer span").first();
    await expect(firstSpan).toBeAttached();
    // Regression guard: a laid-out span must have a real box. If
    // --total-scale-factor isn't set on the page container, pdfjs collapses
    // the glyphs and selection silently breaks.
    const box = await firstSpan.boundingBox();
    expect(box?.width ?? 0).toBeGreaterThan(0);
    expect(box?.height ?? 0).toBeGreaterThan(0);
    // The text is actually selectable.
    await firstSpan.selectText();
    const selected = await page.evaluate(
      () => window.getSelection()?.toString() ?? "",
    );
    expect(selected.trim().length).toBeGreaterThan(0);
  });

  test("opens a PDF at the saved page", async ({ page, signup }) => {
    await signup();
    const bookId = await openPdf(page);

    const SAVED_PAGE = 3;
    const progRes = await page.request.patch(`/api/books/${bookId}/progress`, {
      data: { current_page: SAVED_PAGE },
    });
    expect(progRes.ok()).toBeTruthy();

    await page.goto(`/ui/books/${bookId}/read`);

    await expect(
      page.getByRole("banner").getByText(`${SAVED_PAGE + 1} / 20`),
    ).toBeVisible();
    await expect(page.locator("canvas").first()).toBeVisible();
  });
});
