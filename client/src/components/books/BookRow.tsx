import { Link } from "react-router-dom";
import { useTranslation } from "react-i18next";
import { Check } from "lucide-react";
import { cn } from "@/lib/utils";
import { Badge } from "@/components/ui/badge";
import { BookCover } from "./BookCover";
import { BookActions } from "./BookActions";
import type { Book } from "@/types/api";

interface BookRowProps {
  book: Book;
  selectable?: boolean;
  selected?: boolean;
  onToggleSelect?: (id: number) => void;
}

export function BookRow({ book, selectable, selected, onToggleSelect }: BookRowProps) {
  const { t } = useTranslation();
  const volumeSuffix = book.volume ? t("books.volumeSuffix", { volume: book.volume }) : "";
  return (
    <article
      className={cn(
        "group relative flex items-start gap-3 rounded-lg border border-transparent p-2 transition-colors hover:border-border hover:bg-accent/40",
        selected && "border-primary bg-primary/5",
      )}
    >
      {selectable ? (
        <span
          className={cn(
            "mt-1 flex size-6 shrink-0 items-center justify-center rounded-md border",
            selected
              ? "border-primary bg-primary text-primary-foreground"
              : "border-border bg-background",
          )}
        >
          {selected ? <Check className="size-4" aria-hidden /> : null}
        </span>
      ) : null}
      <div className="w-16 shrink-0 sm:w-20">
        <BookCover book={book} />
      </div>
      <div className="flex min-w-0 flex-1 flex-col gap-1">
        <h3 className="line-clamp-2 text-sm font-medium leading-tight">
          {/* Stretched link: ::after covers the article; BookActions stays atop via z-10. */}
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
      {selectable ? (
        <button
          type="button"
          aria-label={book.title}
          aria-pressed={selected}
          onClick={() => onToggleSelect?.(book.id)}
          className="absolute inset-0 z-20 cursor-pointer rounded-lg"
        />
      ) : (
        <BookActions book={book} layout="inline" />
      )}
    </article>
  );
}
