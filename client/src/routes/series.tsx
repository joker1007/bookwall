import { useSearchParams } from "react-router-dom";
import { useTranslation } from "react-i18next";
import { ChevronLeft, ChevronRight } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { TaxonomyCard } from "@/components/taxonomy/TaxonomyCard";
import { useSeriesList } from "@/hooks/useTaxonomy";

export default function SeriesIndexPage() {
  const { t } = useTranslation();
  const [searchParams, setSearchParams] = useSearchParams();
  const page = parseInt(searchParams.get("page") ?? "1", 10) || 1;
  const query = useSeriesList(page);

  const updatePage = (next: number) => {
    const params = new URLSearchParams(searchParams);
    if (next === 1) params.delete("page");
    else params.set("page", String(next));
    setSearchParams(params);
  };

  return (
    <section className="mx-auto flex max-w-screen-2xl flex-col gap-4 px-4 py-6">
      <header className="flex flex-col gap-2">
        <h1 className="text-2xl font-semibold tracking-tight md:text-3xl">
          {t("series.title")}
        </h1>
        <p className="text-sm text-muted-foreground">{t("series.description")}</p>
      </header>

      {query.isPending ? (
        <SeriesSkeleton />
      ) : query.isError ? (
        <p className="text-sm text-destructive">{t("common.fetchFailed")}</p>
      ) : query.data.series.length === 0 ? (
        <p className="rounded-lg border border-dashed border-border p-8 text-center text-sm text-muted-foreground">
          {t("series.empty")}
        </p>
      ) : (
        <>
          <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6">
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

function SeriesSkeleton() {
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
