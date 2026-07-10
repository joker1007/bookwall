import type { Page } from "@playwright/test";
import { test, expect } from "./helpers/test-base";
import type { Book } from "../../src/types/api";

// The book list fetches every matching book at once and virtualizes the DOM.
// The fixtures scan only yields 5 books, so mock /api/books with a large
// result set to exercise the virtualization.
const TOTAL = 1000;
// Upper bound for mounted articles: visible rows + overscan on any project
// viewport stay far below this.
const DOM_BOUND = 100;

function mockBook(id: number): Book {
  return {
    id,
    title: `Mock Book ${String(id).padStart(4, "0")}`,
    volume: null,
    file_format: "cbz",
    file_path: `/mock/book-${id}.cbz`,
    file_size: 1024,
    page_count: 10,
    published_at: null,
    added_at: "2026-01-01T00:00:00Z",
    scanned_at: null,
    library_id: 1,
    series_id: null,
    series_name: null,
    authors: [],
    tags: [],
    favorited: true,
    cover: null,
    reading_progress: null,
  };
}

// Intercept GET /api/books (list endpoint only; /api/books/:id falls through)
// and serve TOTAL books in a single response. Returns the log of requested
// sort params so tests can assert refetches.
async function mockBookList(page: Page) {
  const requestedSorts: (string | null)[] = [];
  const books = Array.from({ length: TOTAL }, (_, i) => mockBook(i + 1));
  await page.route(
    (url) => url.pathname === "/api/books",
    async (route) => {
      const url = new URL(route.request().url());
      requestedSorts.push(url.searchParams.get("sort"));
      await route.fulfill({ json: { books, count: TOTAL } });
    },
  );
  return requestedSorts;
}

test.describe("virtualized book list", () => {
  test("keeps the DOM bounded while scrolling through all books", async ({
    page,
    signup,
  }) => {
    await mockBookList(page);
    await signup();
    await page.goto("/ui/favorites");

    // All books are fetched at once; the count reflects the full set.
    await expect(page.getByText(`${TOTAL} books`)).toBeVisible();
    await expect(page.getByText("Mock Book 0001")).toBeVisible();

    // Virtualization: only a window of articles is mounted.
    expect(await page.locator("article").count()).toBeLessThan(DOM_BOUND);

    // The scrollbar spans the whole set: the last book is reachable by
    // scrolling to the bottom. Estimated row heights settle as rows get
    // measured, so keep pushing to the (moving) bottom until it shows up.
    await expect(async () => {
      await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight));
      await expect(page.getByText(`Mock Book ${TOTAL}`)).toBeVisible({
        timeout: 500,
      });
    }).toPass({ timeout: 15_000 });

    // Still bounded after traversing the full list.
    expect(await page.locator("article").count()).toBeLessThan(DOM_BOUND);
  });

  test("refetches with the new sort when the sort changes", async ({
    page,
    signup,
  }) => {
    const requestedSorts = await mockBookList(page);
    await signup();
    await page.goto("/ui/favorites");
    await expect(page.getByText("Mock Book 0001")).toBeVisible();

    await page.getByRole("combobox").click();
    await page.getByRole("option", { name: "Oldest first" }).click();

    await expect(page).toHaveURL(/sort=added_at_asc/);
    await expect
      .poll(() => requestedSorts.includes("added_at_asc"))
      .toBeTruthy();
  });
});
