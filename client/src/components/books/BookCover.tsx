import { Link } from "react-router-dom";
import { useTranslation } from "react-i18next";
import { BookOpen, ImageOff } from "lucide-react";
import { cn } from "@/lib/utils";
import type { Book } from "@/types/api";

interface BookCoverProps {
  book: Book;
  size?: "thumb" | "full";
  className?: string;
  hideProgress?: boolean;
  /** When set, a centered "read" button appears over the cover on hover. */
  readTo?: string;
}

export function BookCover({
  book,
  size = "thumb",
  className,
  hideProgress = false,
  readTo,
}: BookCoverProps) {
  const { t } = useTranslation();
  const url = book.cover?.[size === "full" ? "url" : "thumb_url"];
  const progress = hideProgress ? null : renderableProgress(book);

  return (
    <div className={cn("relative", className)}>
      {url ? (
        <img
          src={url}
          alt={t("books.coverAlt", { title: book.title })}
          loading="lazy"
          className="aspect-[2/3] w-full rounded-md object-cover"
        />
      ) : (
        <div
          className="flex aspect-[2/3] w-full items-center justify-center rounded-md bg-muted text-muted-foreground"
          aria-label={t("books.coverMissing", { title: book.title })}
        >
          <ImageOff className="size-6" aria-hidden />
        </div>
      )}
      {readTo ? (
        <div className="pointer-events-none absolute inset-0 z-10 flex items-center justify-center rounded-md opacity-0 transition-opacity duration-150 group-hover:opacity-100 group-focus-within:opacity-100">
          <span className="absolute inset-0 rounded-md bg-black/35" aria-hidden />
          <Link
            to={readTo}
            aria-label={t("reader.open")}
            onClick={(e) => e.stopPropagation()}
            className="pointer-events-auto relative flex aspect-square w-2/5 min-w-9 max-w-20 items-center justify-center rounded-full bg-primary text-primary-foreground shadow-lg ring-2 ring-primary-foreground/40 transition-transform hover:scale-105 focus-visible:scale-105 focus-visible:outline-none focus-visible:ring-4"
          >
            <BookOpen className="h-1/2 w-1/2" aria-hidden />
          </Link>
        </div>
      ) : null}
      {progress ? (
        <div
          className="absolute inset-x-0 bottom-0 h-1.5 overflow-hidden rounded-b-md bg-black/40"
          role="progressbar"
          aria-label={t("books.progressLabel", {
            percent: Math.round(progress * 100),
          })}
          aria-valuenow={Math.round(progress * 100)}
          aria-valuemin={0}
          aria-valuemax={100}
        >
          <div
            className="h-full bg-primary"
            style={{ width: `${Math.round(progress * 100)}%` }}
          />
        </div>
      ) : null}
    </div>
  );
}

// Hide the bar at 0% and 100% — both would just be noise on the cover.
function renderableProgress(book: Book): number | null {
  const fraction = book.reading_progress?.fraction;
  if (typeof fraction !== "number") return null;
  if (fraction <= 0 || fraction >= 1) return null;
  return fraction;
}
