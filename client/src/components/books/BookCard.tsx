import { Link } from "react-router-dom";
import { useTranslation } from "react-i18next";
import { Check } from "lucide-react";
import { cn } from "@/lib/utils";
import { BookCover } from "./BookCover";
import { BookActions } from "./BookActions";
import type { Book } from "@/types/api";

interface BookCardProps {
  book: Book;
  selectable?: boolean;
  selected?: boolean;
  onToggleSelect?: (id: number) => void;
}

export function BookCard({ book, selectable, selected, onToggleSelect }: BookCardProps) {
  const { t } = useTranslation();
  const volumeSuffix = book.volume ? t("books.volumeSuffix", { volume: book.volume }) : "";
  return (
    <article
      className={cn(
        "group relative flex flex-col gap-2 rounded-lg border border-transparent p-2 transition-colors hover:border-border hover:bg-accent/40",
        selected && "border-primary bg-primary/5",
      )}
    >
      <div className="relative">
        <BookCover book={book} readTo={selectable ? undefined : `/books/${book.id}/read`} />
        {selectable ? (
          <span
            className={cn(
              "pointer-events-none absolute left-1.5 top-1.5 z-30 flex size-6 items-center justify-center rounded-md border shadow-sm",
              selected
                ? "border-primary bg-primary text-primary-foreground"
                : "border-border bg-background/95",
            )}
          >
            {selected ? <Check className="size-4" aria-hidden /> : null}
          </span>
        ) : (
          <BookActions book={book} layout="overlay" />
        )}
      </div>
      <div className="flex flex-col gap-0.5">
        <h3 className="line-clamp-2 text-sm font-medium leading-tight">
          {/* Stretched link: ::after covers the article so clicks outside BookActions navigate. */}
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
      {selectable ? (
        <button
          type="button"
          aria-label={book.title}
          aria-pressed={selected}
          onClick={() => onToggleSelect?.(book.id)}
          className="absolute inset-0 z-20 cursor-pointer rounded-lg"
        />
      ) : null}
    </article>
  );
}
