import { Link, useSearchParams } from "react-router-dom";
import { useTranslation } from "react-i18next";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";
import { Pagination } from "@/components/common/Pagination";
import { useTagsList } from "@/hooks/useTaxonomy";

export default function TagsIndexPage() {
  const { t } = useTranslation();
  const [searchParams, setSearchParams] = useSearchParams();
  const page = parseInt(searchParams.get("page") ?? "1", 10) || 1;
  const query = useTagsList({ page, limit: 100 });

  const updatePage = (next: number) => {
    const params = new URLSearchParams(searchParams);
    if (next === 1) params.delete("page");
    else params.set("page", String(next));
    setSearchParams(params);
  };

  return (
    <section className="mx-auto flex max-w-[1920px] flex-col gap-4 px-4 py-6">
      <header className="flex flex-col gap-2">
        <h1 className="text-2xl font-semibold tracking-tight md:text-3xl">
          {t("tags.title")}
        </h1>
        <p className="text-sm text-muted-foreground">{t("tags.description")}</p>
      </header>

      {query.isPending ? (
        <div className="flex flex-wrap gap-2">
          {Array.from({ length: 24 }).map((_, i) => (
            <Skeleton key={i} className="h-8 w-24 rounded-full" />
          ))}
        </div>
      ) : query.isError ? (
        <p className="text-sm text-destructive">{t("common.fetchFailed")}</p>
      ) : query.data.tags.length === 0 ? (
        <p className="rounded-lg border border-dashed border-border p-8 text-center text-sm text-muted-foreground">
          {t("tags.empty")}
        </p>
      ) : (
        <>
          <div className="flex flex-wrap gap-2">
            {query.data.tags.map((tag) => (
              <Link key={tag.id} to={`/tags/${tag.id}`}>
                <Badge
                  variant="secondary"
                  className="min-h-9 cursor-pointer gap-2 px-3 text-sm transition-colors hover:bg-accent"
                >
                  <span>{tag.name}</span>
                  <span className="rounded-full bg-background/60 px-2 py-0.5 text-xs text-muted-foreground">
                    {tag.book_count}
                  </span>
                </Badge>
              </Link>
            ))}
          </div>
          <Pagination
            page={query.data.pagination.page}
            pages={query.data.pagination.pages}
            onPageChange={updatePage}
          />
        </>
      )}
    </section>
  );
}
