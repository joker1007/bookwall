import { useEffect, useMemo, useState, type ReactNode } from "react";
import { useSearchParams } from "react-router-dom";
import { useTranslation } from "react-i18next";
import { LayoutGrid, List, CheckSquare } from "lucide-react";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { ToggleGroup, ToggleGroupItem } from "@/components/ui/toggle-group";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { ItemSizeSlider } from "@/components/common/ItemSizeSlider";
import { GridSkeleton } from "@/components/common/GridSkeleton";
import { BulkActionBar } from "./BulkActionBar";
import { useUiStore } from "@/stores/uiStore";
import { useInfiniteBookList, type BookListParams } from "@/hooks/useBooks";
import { useIntersectionObserver } from "@/hooks/useIntersectionObserver";
import { BookCard } from "./BookCard";
import { BookRow } from "./BookRow";

interface BookListViewProps {
  title: string;
  description?: string;
  baseParams?: Omit<BookListParams, "page" | "sort" | "limit">;
  emptyMessage?: string;
  headerActions?: ReactNode;
}

const BOOK_CHUNK_SIZE = 1000;

const SORT_VALUES = [
  "added_at_desc",
  "added_at_asc",
  "title_asc",
  "title_desc",
  "series_asc",
  "author_asc",
  "author_desc",
] as const;

export function BookListView({
  title,
  description,
  baseParams,
  emptyMessage,
  headerActions,
}: BookListViewProps) {
  const { t } = useTranslation();
  const [searchParams, setSearchParams] = useSearchParams();
  const displayMode = useUiStore((s) => s.displayMode);
  const setDisplayMode = useUiStore((s) => s.setDisplayMode);
  const sortOrder = useUiStore((s) => s.sortOrder);
  const setSortOrder = useUiStore((s) => s.setSortOrder);
  const itemSize = useUiStore((s) => s.itemSize);
  const setItemSize = useUiStore((s) => s.setItemSize);

  // URL `?sort=` wins so a shared link reproduces the exact view.
  const sort = searchParams.get("sort") ?? sortOrder;

  const query = useInfiniteBookList({
    ...baseParams,
    sort,
    limit: BOOK_CHUNK_SIZE,
  });

  const updateParam = (key: string, value: string | null) => {
    const next = new URLSearchParams(searchParams);
    if (value === null || value === "") next.delete(key);
    else next.set(key, value);
    setSearchParams(next, { replace: false });
  };

  // Drop the legacy `?page=` param from old shared links.
  useEffect(() => {
    if (!searchParams.has("page")) return;
    const next = new URLSearchParams(searchParams);
    next.delete("page");
    setSearchParams(next, { replace: true });
  }, [searchParams, setSearchParams]);

  // Offset paging can surface the same book on two pages when the list shifts
  // between loads; dedupe by id to keep React keys stable.
  const books = useMemo(() => {
    if (!query.data) return undefined;
    const seen = new Set<number>();
    return query.data.pages
      .flatMap((p) => p.books)
      .filter((b) => !seen.has(b.id) && (seen.add(b.id), true));
  }, [query.data]);
  const totalCount = query.data?.pages[0]?.pagination.count;

  const sentinelRef = useIntersectionObserver({
    onIntersect: () => query.fetchNextPage(),
    enabled: query.hasNextPage && !query.isFetchingNextPage,
  });

  const resolvedEmpty = emptyMessage ?? t("books.listEmpty");

  const [selectionMode, setSelectionMode] = useState(false);
  const [selectedIds, setSelectedIds] = useState<Set<number>>(new Set());

  // Clear selection when list contents change so stale ids never leak into a bulk action.
  const listKey = `${JSON.stringify(baseParams ?? {})}|${sort}`;
  const [prevKey, setPrevKey] = useState(listKey);
  if (listKey !== prevKey) {
    setPrevKey(listKey);
    if (selectedIds.size > 0) setSelectedIds(new Set());
  }

  const toggleSelect = (id: number) => {
    setSelectedIds((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  };
  const clearSelection = () => setSelectedIds(new Set());
  const selectAll = () => {
    if (books) setSelectedIds(new Set(books.map((b) => b.id)));
  };
  const toggleSelectionMode = () => {
    setSelectionMode((on) => !on);
    setSelectedIds(new Set());
  };

  const collectionId = baseParams?.collection_id;
  const allSelected =
    !!books && books.length > 0 && selectedIds.size === books.length;

  return (
    <section className="flex flex-col gap-4 px-3 py-6">
      <header className="flex flex-wrap items-start justify-between gap-3">
        <div className="flex min-w-0 flex-col gap-2">
          <h1 className="text-2xl font-semibold tracking-tight md:text-3xl">{title}</h1>
          {description ? (
            <p className="text-sm text-muted-foreground">{description}</p>
          ) : null}
        </div>
        {headerActions ? (
          <div className="flex shrink-0 items-center gap-2">{headerActions}</div>
        ) : null}
      </header>

      <div className="flex flex-wrap items-center gap-2">
        <Select
          value={sort}
          onValueChange={(v) => {
            setSortOrder(v);
            updateParam("sort", v);
          }}
        >
          <SelectTrigger className="h-10 w-44">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            {SORT_VALUES.map((value) => (
              <SelectItem key={value} value={value}>
                {t(`books.sort.${value}`)}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>

        {displayMode === "grid" ? (
          <ItemSizeSlider value={itemSize} onChange={setItemSize} />
        ) : null}

        <Button
          variant={selectionMode ? "default" : "outline"}
          size="sm"
          className="ml-auto gap-2"
          onClick={toggleSelectionMode}
          aria-pressed={selectionMode}
        >
          <CheckSquare className="size-4" aria-hidden />
          {selectionMode ? t("books.bulk.exit") : t("books.bulk.enter")}
        </Button>

        <ToggleGroup
          type="single"
          value={displayMode}
          onValueChange={(v) => {
            if (v === "grid" || v === "list") setDisplayMode(v);
          }}
          variant="outline"
        >
          <ToggleGroupItem
            value="grid"
            aria-label={t("books.displayMode.grid")}
            className="size-10"
          >
            <LayoutGrid className="size-4" />
          </ToggleGroupItem>
          <ToggleGroupItem
            value="list"
            aria-label={t("books.displayMode.list")}
            className="size-10"
          >
            <List className="size-4" />
          </ToggleGroupItem>
        </ToggleGroup>
      </div>

      {selectionMode ? (
        <BulkActionBar
          selectedIds={[...selectedIds]}
          allSelected={allSelected}
          onSelectAll={selectAll}
          onClear={clearSelection}
          collectionId={collectionId}
        />
      ) : null}

      {query.isPending ? (
        <BookListSkeleton mode={displayMode} itemSize={itemSize} />
      ) : query.isError && !query.isFetchNextPageError ? (
        <p className="text-sm text-destructive">{t("books.detail.loadFailed")}</p>
      ) : books && books.length === 0 ? (
        <p className="rounded-lg border border-dashed border-border p-8 text-center text-sm text-muted-foreground">
          {resolvedEmpty}
        </p>
      ) : (
        <>
          <p className="text-sm text-muted-foreground">
            {t("books.infinite.status", {
              loaded: books!.length,
              total: totalCount,
            })}
          </p>

          {displayMode === "grid" ? (
            <div
              className="grid gap-3"
              style={{
                gridTemplateColumns: `repeat(auto-fill, minmax(${itemSize}px, 1fr))`,
              }}
            >
              {books!.map((book) => (
                <BookCard
                  key={book.id}
                  book={book}
                  selectable={selectionMode}
                  selected={selectedIds.has(book.id)}
                  onToggleSelect={toggleSelect}
                />
              ))}
            </div>
          ) : (
            <ul className="flex flex-col gap-1">
              {books!.map((book) => (
                <li key={book.id}>
                  <BookRow
                    book={book}
                    selectable={selectionMode}
                    selected={selectedIds.has(book.id)}
                    onToggleSelect={toggleSelect}
                  />
                </li>
              ))}
            </ul>
          )}

          {/* Always in the DOM: conditional mounting makes the observer miss
              attach timing between fetches. */}
          <div ref={sentinelRef} data-testid="infinite-scroll-sentinel" aria-hidden />

          {query.isFetchingNextPage ? (
            displayMode === "grid" ? (
              <GridSkeleton itemSize={itemSize} />
            ) : (
              <p role="status" className="p-2 text-sm text-muted-foreground">
                {t("books.infinite.loading")}
              </p>
            )
          ) : null}

          {query.isFetchNextPageError && !query.isFetchingNextPage ? (
            <Button
              variant="outline"
              className="self-center"
              onClick={() => query.fetchNextPage()}
            >
              {t("books.infinite.retry")}
            </Button>
          ) : null}
        </>
      )}
    </section>
  );
}

function BookListSkeleton({
  mode,
  itemSize,
}: {
  mode: "grid" | "list";
  itemSize: number;
}) {
  if (mode === "grid") {
    return <GridSkeleton itemSize={itemSize} />;
  }
  return (
    <ul className="flex flex-col gap-1">
      {Array.from({ length: 8 }).map((_, i) => (
        <li key={i} className="flex items-start gap-3 p-2">
          <Skeleton className="aspect-[2/3] w-16 shrink-0" />
          <div className="flex-1 space-y-2">
            <Skeleton className="h-4 w-3/4" />
            <Skeleton className="h-3 w-1/2" />
          </div>
        </li>
      ))}
    </ul>
  );
}
