import { useSearchParams, useParams } from "react-router-dom";
import { useTranslation } from "react-i18next";
import { ChevronLeft, ChevronRight } from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Skeleton } from "@/components/ui/skeleton";
import { ToggleGroup, ToggleGroupItem } from "@/components/ui/toggle-group";
import { BookListView } from "@/components/books/BookListView";
import { TaxonomyCard } from "@/components/taxonomy/TaxonomyCard";
import { useLibrary } from "@/hooks/useLibraries";
import { useSeriesList } from "@/hooks/useTaxonomy";
import {
  useUiStore,
  PER_PAGE_OPTIONS,
  ITEM_SIZE_MIN,
  ITEM_SIZE_MAX,
  type PerPage,
} from "@/stores/uiStore";

type GroupMode = "books" | "series";

export default function LibraryDetailPage() {
  const { t } = useTranslation();
  const { id } = useParams();
  const library = useLibrary(id);
  const [searchParams, setSearchParams] = useSearchParams();
  const groupMode: GroupMode =
    searchParams.get("view") === "series" ? "series" : "books";

  const setGroupMode = (next: GroupMode) => {
    const params = new URLSearchParams(searchParams);
    if (next === "books") params.delete("view");
    else params.set("view", next);
    // Reset paginator when switching modes — book pages and series pages
    // share the `?page` slot but they index different collections.
    params.delete("page");
    setSearchParams(params, { replace: false });
  };

  const groupToggle = (
    <ToggleGroup
      type="single"
      value={groupMode}
      onValueChange={(v) => {
        if (v === "books" || v === "series") setGroupMode(v);
      }}
      variant="outline"
      aria-label={t("books.groupMode.label")}
    >
      <ToggleGroupItem value="books" className="h-10 px-3 text-sm">
        {t("books.groupMode.books")}
      </ToggleGroupItem>
      <ToggleGroupItem value="series" className="h-10 px-3 text-sm">
        {t("books.groupMode.series")}
      </ToggleGroupItem>
    </ToggleGroup>
  );

  if (groupMode === "series") {
    return (
      <LibrarySeriesGrid
        libraryId={id}
        title={library.data?.name ?? t("books.list.byLibrary")}
        description={library.data?.path}
        headerActions={groupToggle}
      />
    );
  }

  return (
    <BookListView
      title={library.data?.name ?? t("books.list.byLibrary")}
      description={library.data?.path}
      baseParams={{ library_id: id }}
      headerActions={groupToggle}
    />
  );
}

interface LibrarySeriesGridProps {
  libraryId: string | undefined;
  title: string;
  description?: string;
  headerActions: React.ReactNode;
}

function LibrarySeriesGrid({
  libraryId,
  title,
  description,
  headerActions,
}: LibrarySeriesGridProps) {
  const { t } = useTranslation();
  const [searchParams, setSearchParams] = useSearchParams();
  const itemSize = useUiStore((s) => s.itemSize);
  const setItemSize = useUiStore((s) => s.setItemSize);
  const perPage = useUiStore((s) => s.perPage);
  const setPerPage = useUiStore((s) => s.setPerPage);
  const page = parseInt(searchParams.get("page") ?? "1", 10) || 1;
  const query = useSeriesList({ page, limit: perPage, library_id: libraryId });

  const updatePage = (next: number) => {
    const params = new URLSearchParams(searchParams);
    if (next === 1) params.delete("page");
    else params.set("page", String(next));
    setSearchParams(params);
  };

  const handlePerPageChange = (value: string) => {
    const next = Number(value) as PerPage;
    if (!PER_PAGE_OPTIONS.includes(next)) return;
    setPerPage(next);
    if (page !== 1) updatePage(1);
  };

  return (
    <section className="flex flex-col gap-4 px-3 py-6">
      <header className="flex flex-wrap items-start justify-between gap-3">
        <div className="flex min-w-0 flex-col gap-2">
          <h1 className="text-2xl font-semibold tracking-tight md:text-3xl">
            {title}
          </h1>
          {description ? (
            <p className="text-sm text-muted-foreground">{description}</p>
          ) : null}
        </div>
        <div className="flex shrink-0 items-center gap-2">{headerActions}</div>
      </header>

      <div className="flex flex-wrap items-center gap-2">
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
        <ItemSizeSlider value={itemSize} onChange={setItemSize} />
      </div>

      {query.isPending ? (
        <SeriesSkeleton itemSize={itemSize} />
      ) : query.isError ? (
        <p className="text-sm text-destructive">{t("common.fetchFailed")}</p>
      ) : query.data.series.length === 0 ? (
        <p className="rounded-lg border border-dashed border-border p-8 text-center text-sm text-muted-foreground">
          {t("series.empty")}
        </p>
      ) : (
        <>
          <div
            className="grid gap-3"
            style={{
              gridTemplateColumns: `repeat(auto-fill, minmax(${itemSize}px, 1fr))`,
            }}
          >
            {query.data.series.map((s) => (
              <TaxonomyCard
                key={s.id}
                to={`/series/${s.id}`}
                name={s.name}
                thumbUrl={s.sample_cover_thumb_url}
                meta={t("series.bookCount", { count: s.book_count })}
              />
            ))}
          </div>
          <Pagination
            page={query.data.pagination.page}
            pages={query.data.pagination.pages}
            onChange={updatePage}
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
  onChange: (page: number) => void;
}

function Pagination({ page, pages, onChange }: PaginationProps) {
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
        onClick={() => onChange(page - 1)}
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
        onClick={() => onChange(page + 1)}
        aria-label={t("books.pager.next")}
        className="min-h-10"
      >
        <ChevronRight className="size-4" />
      </Button>
    </nav>
  );
}

function SeriesSkeleton({ itemSize }: { itemSize: number }) {
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
