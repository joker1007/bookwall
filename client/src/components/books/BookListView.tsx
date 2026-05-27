import { useSearchParams } from "react-router-dom";
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
import { useUiStore } from "@/stores/uiStore";
import { useBookList, type BookListParams } from "@/hooks/useBooks";
import { BookCard } from "./BookCard";
import { BookRow } from "./BookRow";

interface BookListViewProps {
  title: string;
  description?: string;
  baseParams?: Omit<BookListParams, "page" | "sort">;
  emptyMessage?: string;
}

const SORT_OPTIONS = [
  { value: "added_at_desc", label: "新着順" },
  { value: "added_at_asc", label: "登録日順 (古い順)" },
  { value: "title_asc", label: "タイトル昇順" },
  { value: "title_desc", label: "タイトル降順" },
  { value: "series_asc", label: "シリーズ順" },
] as const;

export function BookListView({
  title,
  description,
  baseParams,
  emptyMessage = "書籍はまだありません。",
}: BookListViewProps) {
  const [searchParams, setSearchParams] = useSearchParams();
  const displayMode = useUiStore((s) => s.displayMode);
  const setDisplayMode = useUiStore((s) => s.setDisplayMode);

  const page = parseInt(searchParams.get("page") ?? "1", 10) || 1;
  const sort = searchParams.get("sort") ?? "added_at_desc";

  const query = useBookList({
    ...baseParams,
    sort,
    page,
  });

  const updateParam = (key: string, value: string | null) => {
    const next = new URLSearchParams(searchParams);
    if (value === null || value === "") next.delete(key);
    else next.set(key, value);
    setSearchParams(next, { replace: false });
  };

  const data = query.data;

  return (
    <section className="mx-auto flex max-w-screen-2xl flex-col gap-4 px-4 py-6">
      <header className="flex flex-col gap-2">
        <h1 className="text-2xl font-semibold tracking-tight md:text-3xl">{title}</h1>
        {description ? (
          <p className="text-sm text-muted-foreground">{description}</p>
        ) : null}
      </header>

      <div className="flex flex-wrap items-center gap-2">
        <Select value={sort} onValueChange={(v) => updateParam("sort", v)}>
          <SelectTrigger className="h-10 w-44">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            {SORT_OPTIONS.map((opt) => (
              <SelectItem key={opt.value} value={opt.value}>
                {opt.label}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>

        <ToggleGroup
          type="single"
          value={displayMode}
          onValueChange={(v) => {
            if (v === "grid" || v === "list") setDisplayMode(v);
          }}
          variant="outline"
          className="ml-auto"
        >
          <ToggleGroupItem value="grid" aria-label="グリッド表示" className="size-10">
            <LayoutGrid className="size-4" />
          </ToggleGroupItem>
          <ToggleGroupItem value="list" aria-label="リスト表示" className="size-10">
            <List className="size-4" />
          </ToggleGroupItem>
        </ToggleGroup>
      </div>

      {query.isPending ? (
        <BookListSkeleton mode={displayMode} />
      ) : query.isError ? (
        <p className="text-sm text-destructive">
          書籍の読み込みに失敗しました。
        </p>
      ) : data && data.books.length === 0 ? (
        <p className="rounded-lg border border-dashed border-border p-8 text-center text-sm text-muted-foreground">
          {emptyMessage}
        </p>
      ) : (
        <>
          {displayMode === "grid" ? (
            <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6">
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

interface PaginationProps {
  page: number;
  pages: number;
  onPageChange: (page: number) => void;
}

function Pagination({ page, pages, onPageChange }: PaginationProps) {
  if (pages <= 1) return null;
  return (
    <nav
      aria-label="ページ送り"
      className="mt-4 flex items-center justify-center gap-2 text-sm"
    >
      <Button
        variant="outline"
        size="sm"
        disabled={page <= 1}
        onClick={() => onPageChange(page - 1)}
        aria-label="前のページ"
        className="min-h-10"
      >
        <ChevronLeft className="size-4" />
      </Button>
      <span className="text-muted-foreground">
        {page} / {pages}
      </span>
      <Button
        variant="outline"
        size="sm"
        disabled={page >= pages}
        onClick={() => onPageChange(page + 1)}
        aria-label="次のページ"
        className="min-h-10"
      >
        <ChevronRight className="size-4" />
      </Button>
    </nav>
  );
}

function BookListSkeleton({ mode }: { mode: "grid" | "list" }) {
  if (mode === "grid") {
    return (
      <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6">
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
