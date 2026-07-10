import type { Page } from "@playwright/test";
import { test, expect } from "./helpers/test-base";
import type { Book } from "../../src/types/api";

// BookListView fetches in fixed chunks of 100 (BOOK_CHUNK_SIZE). The fixtures
// scan only yields 5 books, so we mock /api/books to exercise chunk paging.
const CHUNK = 100;
const TOTAL = 110;
const PAGES = Math.ceil(TOTAL / CHUNK);

function mockBook(id: number): Book {
  return {
    id,
    title: `Mock Book ${String(id).padStart(3, "0")}`,
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
// and serve TOTAL books split into CHUNK-sized pages. Returns the log of
// requested page numbers so tests can assert fetch behaviour.
async function mockBookList(page: Page) {
  const requestedPages: number[] = [];
  await page.route(
    (url) => url.pathname === "/api/books",
    async (route) => {
      const url = new URL(route.request().url());
      const pageNum = Number(url.searchParams.get("page") ?? "1");
      requestedPages.push(pageNum);
      const start = (pageNum - 1) * CHUNK;
      const books = Array.from(
        { length: Math.max(0, Math.min(CHUNK, TOTAL - start)) },
        (_, i) => mockBook(start + i + 1),
      );
      await route.fulfill({
        json: { books, pagination: { page: pageNum, pages: PAGES, count: TOTAL } },
      });
    },
  );
  return requestedPages;
}

test.describe("infinite scroll book list", () => {
  test("loads the next chunk when the sentinel scrolls into view", async ({
    page,
    signup,
  }) => {
    const requestedPages = await mockBookList(page);
    await signup();
    await page.goto("/ui/favorites");

    // First chunk renders without any scrolling.
    await expect(page.locator("article")).toHaveCount(CHUNK);
    await expect(page.getByText(`Showing ${CHUNK} of ${TOTAL}`)).toBeVisible();
    expect(requestedPages).toEqual([1]);

    // Scrolling the sentinel into view fetches and appends the second chunk.
    await page.getByTestId("infinite-scroll-sentinel").scrollIntoViewIfNeeded();
    await expect(page.locator("article")).toHaveCount(TOTAL);
    await expect(page.getByText(`Showing ${TOTAL} of ${TOTAL}`)).toBeVisible();
    expect(requestedPages).toEqual([1, 2]);

    // Everything is loaded; further scrolling must not fetch again.
    await page.mouse.wheel(0, 20000);
    await page.waitForTimeout(300);
    expect(requestedPages).toEqual([1, 2]);
  });

  test("restarts from the first chunk when the sort changes", async ({
    page,
    signup,
  }) => {
    const requestedPages = await mockBookList(page);
    await signup();
    await page.goto("/ui/favorites");

    await expect(page.locator("article")).toHaveCount(CHUNK);
    await page.getByTestId("infinite-scroll-sentinel").scrollIntoViewIfNeeded();
    await expect(page.locator("article")).toHaveCount(TOTAL);

    // Changing the sort resets the list to a fresh first chunk.
    await page.getByRole("combobox").click();
    await page.getByRole("option", { name: "Oldest first" }).click();
    await expect(page.locator("article")).toHaveCount(CHUNK);
    await expect(page.getByText(`Showing ${CHUNK} of ${TOTAL}`)).toBeVisible();
    expect(requestedPages).toEqual([1, 2, 1]);
    await expect(page).toHaveURL(/sort=added_at_asc/);
  });
});
