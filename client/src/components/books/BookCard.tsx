import { Link } from "react-router-dom";
import { useTranslation } from "react-i18next";
import { BookCover } from "./BookCover";
import { BookActions } from "./BookActions";
import type { Book } from "@/types/api";

interface BookCardProps {
  book: Book;
}

export function BookCard({ book }: BookCardProps) {
  const { t } = useTranslation();
  const volumeSuffix = book.volume ? t("books.volumeSuffix", { volume: book.volume }) : "";
  return (
    <article className="group relative flex flex-col gap-2 rounded-lg border border-transparent p-2 transition-colors hover:border-border hover:bg-accent/40">
      <div className="relative">
        <BookCover book={book} />
        <BookActions book={book} layout="overlay" />
      </div>
      <div className="flex flex-col gap-0.5">
        <h3 className="line-clamp-2 text-sm font-medium leading-tight">
          {/* Stretched link: the ::after pseudo-element covers the whole
              article so clicking anywhere outside BookActions navigates. */}
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
      </div>
    </article>
  );
}
