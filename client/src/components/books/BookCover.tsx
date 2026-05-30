import { useTranslation } from "react-i18next";
import { ImageOff } from "lucide-react";
import { cn } from "@/lib/utils";
import type { Book } from "@/types/api";

interface BookCoverProps {
  book: Book;
  size?: "thumb" | "full";
  className?: string;
  hideProgress?: boolean;
}

export function BookCover({
  book,
  size = "thumb",
  className,
  hideProgress = false,
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
