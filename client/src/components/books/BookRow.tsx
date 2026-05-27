import { Link } from "react-router-dom";
import { Badge } from "@/components/ui/badge";
import { BookCover } from "./BookCover";
import type { Book } from "@/types/api";

interface BookRowProps {
  book: Book;
}

export function BookRow({ book }: BookRowProps) {
  const volumeSuffix = book.volume ? ` 第 ${book.volume} 巻` : "";
  return (
    <Link
      to={`/books/${book.id}`}
      className="flex items-start gap-3 rounded-lg border border-transparent p-2 transition-colors hover:border-border hover:bg-accent/40"
    >
      <div className="w-16 shrink-0 sm:w-20">
        <BookCover book={book} />
      </div>
      <div className="flex min-w-0 flex-1 flex-col gap-1">
        <h3 className="line-clamp-2 text-sm font-medium leading-tight">
          {book.title}
          {volumeSuffix}
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
            {book.tags.slice(0, 4).map((t) => (
              <Badge key={t.id} variant="secondary" className="text-[10px]">
                {t.name}
              </Badge>
            ))}
          </div>
        ) : null}
      </div>
    </Link>
  );
}
