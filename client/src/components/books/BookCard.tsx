import { Link } from "react-router-dom";
import { BookCover } from "./BookCover";
import type { Book } from "@/types/api";

interface BookCardProps {
  book: Book;
}

export function BookCard({ book }: BookCardProps) {
  const volumeSuffix = book.volume ? ` 第 ${book.volume} 巻` : "";
  return (
    <Link
      to={`/books/${book.id}`}
      className="group flex flex-col gap-2 rounded-lg border border-transparent p-2 transition-colors hover:border-border hover:bg-accent/40"
    >
      <BookCover book={book} />
      <div className="flex flex-col gap-0.5">
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
      </div>
    </Link>
  );
}
