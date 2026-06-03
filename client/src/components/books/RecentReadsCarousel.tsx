import { Link } from "react-router-dom";
import { useTranslation } from "react-i18next";
import { Skeleton } from "@/components/ui/skeleton";
import { BookCover } from "@/components/books/BookCover";
import { useRecentReads } from "@/hooks/useBooks";

export function RecentReadsCarousel() {
  const { t } = useTranslation();
  const query = useRecentReads();

  if (query.isError) return null;
  if (!query.isPending && (query.data?.books.length ?? 0) === 0) return null;

  return (
    <section className="mx-auto flex w-full max-w-[1920px] flex-col gap-3 px-4 pt-6">
      <h2 className="text-lg font-semibold tracking-tight">
        {t("home.continueReading")}
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
              <article
                key={book.id}
                className="group relative flex w-32 shrink-0 flex-col gap-2 sm:w-36"
              >
                <BookCover
                  book={book}
                  size="thumb"
                  readTo={`/books/${book.id}/read`}
                  className="shadow-sm transition-shadow group-hover:shadow-md"
                />
                <div className="flex flex-col">
                  <span className="line-clamp-2 text-sm font-medium leading-snug">
                    {/* Stretched link: ::after covers the article; the cover's read button stays atop via z-10. */}
                    <Link
                      to={`/books/${book.id}`}
                      className="after:absolute after:inset-0 after:rounded-lg focus-visible:outline-none focus-visible:after:ring-2 focus-visible:after:ring-ring"
                    >
                      {book.title}
                      {book.volume ? (
                        <span className="text-muted-foreground">
                          {t("books.volumeSuffix", { volume: book.volume })}
                        </span>
                      ) : null}
                    </Link>
                  </span>
                  {book.series_name ? (
                    <span className="line-clamp-1 text-xs text-muted-foreground">
                      {book.series_name}
                    </span>
                  ) : null}
                </div>
              </article>
            ))}
      </div>
    </section>
  );
}
