import type { ReactNode } from "react";
import { useSearchParams } from "react-router-dom";
import { useTranslation } from "react-i18next";
import { LayoutGrid, List, ChevronLeft, ChevronRight } from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { ToggleGroup, ToggleGroupItem } from "@/components/ui/toggle-group";
import { Skeleton } from "@/components/ui/skeleton";
import {
  useUiStore,
  PER_PAGE_OPTIONS,
  ITEM_SIZE_MIN,
  ITEM_SIZE_MAX,
  type PerPage,
} from "@/stores/uiStore";
import { useBookList, type BookListParams } from "@/hooks/useBooks";
import { BookCard } from "./BookCard";
import { BookRow } from "./BookRow";

interface BookListViewProps {
  title: string;
  description?: string;
  baseParams?: Omit<BookListParams, "page" | "sort" | "limit">;
  emptyMessage?: string;
  headerActions?: ReactNode;
}

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
  const perPage = useUiStore((s) => s.perPage);
  const setPerPage = useUiStore((s) => s.setPerPage);

  const page = parseInt(searchParams.get("page") ?? "1", 10) || 1;
  // URL `?sort=` wins so a shared link reproduces the exact view; with
  // nothing in the URL fall through to whatever the user last picked
  // (persisted in localStorage via uiStore).
  const sort = searchParams.get("sort") ?? sortOrder;

  const query = useBookList({
    ...baseParams,
    sort,
    page,
    limit: perPage,
  });

  const updateParam = (key: string, value: string | null) => {
    const next = new URLSearchParams(searchParams);
    if (value === null || value === "") next.delete(key);
    else next.set(key, value);
    setSearchParams(next, { replace: false });
  };

  const handlePerPageChange = (value: string) => {
    const next = Number(value) as PerPage;
    if (!PER_PAGE_OPTIONS.includes(next)) return;
    setPerPage(next);
    // Page-size changes shift what's on each page, so resetting to
    // page 1 keeps the "what am I looking at" anchor stable.
    if (page !== 1) updateParam("page", null);
  };

  const data = query.data;
  const resolvedEmpty = emptyMessage ?? t("books.listEmpty");

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

        <Select value={String(perPage)} onValueChange={handlePerPageChange}>
          <SelectTrigger className="h-10 w-28" aria-label={t("books.perPage.label")}>
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            {PER_PAGE_OPTIONS.map((n) => (
              <SelectItem key={n} value={String(n)}>
                {t("books.perPage.option", { count: n })}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>

        {displayMode === "grid" ? (
          <ItemSizeSlider value={itemSize} onChange={setItemSize} />
        ) : null}

        <ToggleGroup
          type="single"
          value={displayMode}
          onValueChange={(v) => {
            if (v === "grid" || v === "list") setDisplayMode(v);
          }}
          variant="outline"
          className="ml-auto"
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

      {query.isPending ? (
        <BookListSkeleton mode={displayMode} itemSize={itemSize} />
      ) : query.isError ? (
        <p className="text-sm text-destructive">{t("books.detail.loadFailed")}</p>
      ) : data && data.books.length === 0 ? (
        <p className="rounded-lg border border-dashed border-border p-8 text-center text-sm text-muted-foreground">
          {resolvedEmpty}
        </p>
      ) : (
        <>
          {displayMode === "grid" ? (
            <div
              className="grid gap-3"
              style={{
                gridTemplateColumns: `repeat(auto-fill, minmax(${itemSize}px, 1fr))`,
              }}
            >
              {data!.books.map((book) => (
                <BookCard key={book.id} book={book} />
              ))}
            </div>
          ) : (
            <ul className="flex flex-col gap-1">
              {data!.books.map((book) => (
                <li key={book.id}>
                  <BookRow book={book} />
                </li>
              ))}
            </ul>
          )}

          <Pagination
            page={data!.pagination.page}
            pages={data!.pagination.pages}
            onPageChange={(p) => updateParam("page", p === 1 ? null : String(p))}
          />
        </>
      )}
    </section>
  );
}

interface ItemSizeSliderProps {
  value: number;
  onChange: (next: number) => void;
}

function ItemSizeSlider({ value, onChange }: ItemSizeSliderProps) {
  const { t } = useTranslation();
  return (
    <label className="flex h-10 items-center gap-2 rounded-md border border-input bg-background px-3 text-sm">
      <span className="text-muted-foreground">{t("books.itemSize.label")}</span>
      <input
        type="range"
        min={ITEM_SIZE_MIN}
        max={ITEM_SIZE_MAX}
        step={8}
        value={value}
        onChange={(e) => onChange(Number(e.target.value))}
        aria-label={t("books.itemSize.label")}
        className="h-2 w-32 cursor-pointer appearance-none rounded-full bg-muted
          [&::-webkit-slider-thumb]:h-4 [&::-webkit-slider-thumb]:w-4 [&::-webkit-slider-thumb]:appearance-none
          [&::-webkit-slider-thumb]:rounded-full [&::-webkit-slider-thumb]:border [&::-webkit-slider-thumb]:border-foreground/60
          [&::-webkit-slider-thumb]:bg-foreground
          [&::-moz-range-thumb]:h-4 [&::-moz-range-thumb]:w-4 [&::-moz-range-thumb]:rounded-full
          [&::-moz-range-thumb]:border [&::-moz-range-thumb]:border-foreground/60 [&::-moz-range-thumb]:bg-foreground"
      />
      <span className="w-12 text-right tabular-nums text-muted-foreground">{value}px</span>
    </label>
  );
}

interface PaginationProps {
  page: number;
  pages: number;
  onPageChange: (page: number) => void;
}

function Pagination({ page, pages, onPageChange }: PaginationProps) {
  const { t } = useTranslation();
  if (pages <= 1) return null;
  return (
    <nav
      aria-label={t("books.pager.label")}
      className="mt-4 flex items-center justify-center gap-2 text-sm"
    >
      <Button
        variant="outline"
        size="sm"
        disabled={page <= 1}
        onClick={() => onPageChange(page - 1)}
        aria-label={t("books.pager.prev")}
        className="min-h-10"
      >
        <ChevronLeft className="size-4" />
      </Button>
      <span className="text-muted-foreground">
        {t("books.pager.status", { page, pages })}
      </span>
      <Button
        variant="outline"
        size="sm"
        disabled={page >= pages}
        onClick={() => onPageChange(page + 1)}
        aria-label={t("books.pager.next")}
        className="min-h-10"
      >
        <ChevronRight className="size-4" />
      </Button>
    </nav>
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
    return (
      <div
        className="grid gap-3"
        style={{
          gridTemplateColumns: `repeat(auto-fill, minmax(${itemSize}px, 1fr))`,
        }}
      >
        {Array.from({ length: 12 }).map((_, i) => (
          <div key={i} className="flex flex-col gap-2 p-2">
            <Skeleton className="aspect-[2/3] w-full rounded-md" />
            <Skeleton className="h-3 w-3/4" />
            <Skeleton className="h-3 w-1/2" />
          </div>
        ))}
      </div>
    );
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
