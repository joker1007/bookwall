import { useTranslation } from "react-i18next";
import { ImageOff } from "lucide-react";
import { cn } from "@/lib/utils";
import type { Book } from "@/types/api";

interface BookCoverProps {
  book: Book;
  size?: "thumb" | "full";
  className?: string;
}

export function BookCover({ book, size = "thumb", className }: BookCoverProps) {
  const { t } = useTranslation();
  const url = book.cover?.[size === "full" ? "url" : "thumb_url"];

  if (!url) {
    return (
      <div
        className={cn(
          "flex aspect-[2/3] items-center justify-center rounded-md bg-muted text-muted-foreground",
          className
        )}
        aria-label={t("books.coverMissing", { title: book.title })}
      >
        <ImageOff className="size-6" aria-hidden />
      </div>
    );
  }

  return (
    <img
      src={url}
      alt={t("books.coverAlt", { title: book.title })}
      loading="lazy"
      className={cn("aspect-[2/3] w-full rounded-md object-cover", className)}
    />
  );
}
