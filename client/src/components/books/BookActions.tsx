import type { MouseEvent } from "react";
import { useTranslation } from "react-i18next";
import { Heart, Trash2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";
import { useFavoriteBook } from "@/hooks/useBooks";
import { useDeleteBook } from "@/hooks/useBookMutation";
import type { Book } from "@/types/api";

interface BookActionsProps {
  book: Book;
  layout?: "overlay" | "inline";
}

export function BookActions({ book, layout = "inline" }: BookActionsProps) {
  const { t } = useTranslation();
  const favorite = useFavoriteBook();
  const remove = useDeleteBook();

  const handleFavorite = (e: MouseEvent) => {
    e.preventDefault();
    e.stopPropagation();
    favorite.mutate({ id: book.id, favorited: book.favorited });
  };

  const handleDelete = (e: MouseEvent) => {
    e.preventDefault();
    e.stopPropagation();
    if (!window.confirm(t("books.detail.deleteConfirm", { title: book.title }))) return;
    remove.mutate(book.id);
  };

  const isOverlay = layout === "overlay";

  return (
    <div
      className={cn(
        "relative z-10 flex gap-1",
        isOverlay
          ? "absolute right-1.5 top-1.5 flex-col opacity-0 transition-opacity group-hover:opacity-100 focus-within:opacity-100"
          : "shrink-0 items-center",
      )}
    >
      <Button
        type="button"
        variant="secondary"
        size="icon"
        className={cn(
          "size-9 cursor-pointer border border-border shadow-sm",
          "bg-background/95 backdrop-blur",
          book.favorited
            ? "text-rose-500 hover:bg-rose-500 hover:text-white"
            : "text-foreground hover:bg-accent hover:text-accent-foreground",
        )}
        aria-label={
          book.favorited
            ? t("books.detail.favorited")
            : t("books.detail.favorite")
        }
        aria-pressed={book.favorited}
        onClick={handleFavorite}
        disabled={favorite.isPending}
      >
        <Heart className={cn("size-4", book.favorited && "fill-current")} aria-hidden />
      </Button>
      <Button
        type="button"
        variant="secondary"
        size="icon"
        className={cn(
          "size-9 cursor-pointer border border-border shadow-sm",
          "bg-background/95 backdrop-blur",
          "text-destructive hover:bg-destructive hover:text-destructive-foreground hover:border-destructive",
        )}
        aria-label={t("books.detail.deleteMeta")}
        onClick={handleDelete}
        disabled={remove.isPending}
      >
        <Trash2 className="size-4" aria-hidden />
      </Button>
    </div>
  );
}
