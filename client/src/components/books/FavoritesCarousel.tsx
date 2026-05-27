import { Link } from "react-router-dom";
import { useTranslation } from "react-i18next";
import { Skeleton } from "@/components/ui/skeleton";
import { BookCover } from "@/components/books/BookCover";
import { useRecentFavorites } from "@/hooks/useBooks";

export function FavoritesCarousel() {
  const { t } = useTranslation();
  const query = useRecentFavorites();

  if (query.isError) return null;
  if (!query.isPending && (query.data?.books.length ?? 0) === 0) return null;

  return (
    <section className="mx-auto flex w-full max-w-[1920px] flex-col gap-3 px-4 pt-6">
      <h2 className="text-lg font-semibold tracking-tight">
        {t("home.favorites")}
      </h2>
      <div className="-mx-1 flex gap-3 overflow-x-auto px-1 pb-2 [scrollbar-width:thin]">
        {query.isPending
          ? Array.from({ length: 6 }).map((_, i) => (
              <div key={i} className="w-32 shrink-0 sm:w-36">
                <Skeleton className="aspect-[2/3] w-full rounded-md" />
                <Skeleton className="mt-2 h-3 w-3/4" />
                <Skeleton className="mt-1 h-3 w-1/2" />
              </div>
            ))
          : query.data?.books.map((book) => (
              <Link
                key={book.id}
                to={`/books/${book.id}`}
                className="group flex w-32 shrink-0 flex-col gap-2 sm:w-36"
              >
                <BookCover book={book} size="thumb" className="shadow-sm transition-transform group-hover:scale-[1.02]" />
                <div className="flex flex-col">
                  <span className="line-clamp-2 text-sm font-medium leading-snug">
                    {book.title}
                    {book.volume ? (
                      <span className="text-muted-foreground">
                        {t("books.volumeSuffix", { volume: book.volume })}
                      </span>
                    ) : null}
                  </span>
                  {book.series_name ? (
                    <span className="line-clamp-1 text-xs text-muted-foreground">
                      {book.series_name}
                    </span>
                  ) : null}
                </div>
              </Link>
            ))}
      </div>
    </section>
  );
}
