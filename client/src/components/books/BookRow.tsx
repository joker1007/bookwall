import { Link } from "react-router-dom";
import { useTranslation } from "react-i18next";
import { Badge } from "@/components/ui/badge";
import { BookCover } from "./BookCover";
import { BookActions } from "./BookActions";
import type { Book } from "@/types/api";

interface BookRowProps {
  book: Book;
}

export function BookRow({ book }: BookRowProps) {
  const { t } = useTranslation();
  const volumeSuffix = book.volume ? t("books.volumeSuffix", { volume: book.volume }) : "";
  return (
    <article className="group relative flex items-start gap-3 rounded-lg border border-transparent p-2 transition-colors hover:border-border hover:bg-accent/40">
      <div className="w-16 shrink-0 sm:w-20">
        <BookCover book={book} />
      </div>
      <div className="flex min-w-0 flex-1 flex-col gap-1">
        <h3 className="line-clamp-2 text-sm font-medium leading-tight">
          {/* Stretched link: ::after covers the whole article so the row is
              clickable, while BookActions stays on top via z-10. */}
          <Link
            to={`/books/${book.id}`}
            className="after:absolute after:inset-0 after:rounded-lg focus-visible:outline-none focus-visible:after:ring-2 focus-visible:after:ring-ring"
          >
            {book.title}
            {volumeSuffix}
          </Link>
        </h3>
        {book.series_name ? (
          <p className="line-clamp-1 text-xs text-muted-foreground">
            {book.series_name}
          </p>
        ) : null}
        {book.authors.length > 0 ? (
          <p className="line-clamp-1 text-xs text-muted-foreground">
            {book.authors.map((a) => a.name).join(", ")}
          </p>
        ) : null}
        {book.tags.length > 0 ? (
          <div className="mt-1 flex flex-wrap gap-1">
            {book.tags.slice(0, 4).map((tag) => (
              <Badge key={tag.id} variant="secondary" className="text-[10px]">
                {tag.name}
              </Badge>
            ))}
          </div>
        ) : null}
      </div>
      <BookActions book={book} layout="inline" />
    </article>
  );
}
