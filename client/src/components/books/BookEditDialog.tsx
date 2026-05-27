import { useEffect, useState, type FormEvent } from "react";
import { useTranslation } from "react-i18next";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { useUpdateBook } from "@/hooks/useBookMutation";
import { ApiError } from "@/lib/api";
import type { Book } from "@/types/api";

interface BookEditDialogProps {
  book: Book;
  open: boolean;
  onOpenChange: (open: boolean) => void;
}

export function BookEditDialog({ book, open, onOpenChange }: BookEditDialogProps) {
  const { t } = useTranslation();
  const update = useUpdateBook();
  const [title, setTitle] = useState(book.title);
  const [volume, setVolume] = useState<string>(book.volume?.toString() ?? "");
  const [publishedAt, setPublishedAt] = useState<string>(book.published_at ?? "");
  const [authorNames, setAuthorNames] = useState(book.authors.map((a) => a.name).join(", "));
  const [tagNames, setTagNames] = useState(book.tags.map((tag) => tag.name).join(", "));

  useEffect(() => {
    if (!open) return;
    setTitle(book.title);
    setVolume(book.volume?.toString() ?? "");
    setPublishedAt(book.published_at ?? "");
    setAuthorNames(book.authors.map((a) => a.name).join(", "));
    setTagNames(book.tags.map((tag) => tag.name).join(", "));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open, book.id]);

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    try {
      await update.mutateAsync({
        id: book.id,
        title,
        volume: volume === "" ? null : Number(volume),
        published_at: publishedAt || null,
        author_names: splitCsv(authorNames),
        tag_names: splitCsv(tagNames),
      });
      onOpenChange(false);
    } catch {
      // shown below
    }
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-lg">
        <DialogHeader>
          <DialogTitle>{t("books.edit.title")}</DialogTitle>
          <DialogDescription>{t("books.edit.description")}</DialogDescription>
        </DialogHeader>
        <form onSubmit={handleSubmit} className="grid gap-4">
          <div className="grid gap-2">
            <Label htmlFor="book-title">{t("books.edit.fields.title")}</Label>
            <Input
              id="book-title"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              required
            />
          </div>
          <div className="grid gap-2 sm:grid-cols-2">
            <div className="grid gap-2">
              <Label htmlFor="book-volume">{t("books.edit.fields.volume")}</Label>
              <Input
                id="book-volume"
                type="number"
                inputMode="numeric"
                value={volume}
                onChange={(e) => setVolume(e.target.value)}
              />
            </div>
            <div className="grid gap-2">
              <Label htmlFor="book-published-at">{t("books.edit.fields.publishedAt")}</Label>
              <Input
                id="book-published-at"
                type="date"
                value={publishedAt}
                onChange={(e) => setPublishedAt(e.target.value)}
              />
            </div>
          </div>
          <div className="grid gap-2">
            <Label htmlFor="book-authors">{t("books.edit.fields.authors")}</Label>
            <Input
              id="book-authors"
              value={authorNames}
              onChange={(e) => setAuthorNames(e.target.value)}
              placeholder={t("books.edit.fields.authorsPlaceholder")}
            />
          </div>
          <div className="grid gap-2">
            <Label htmlFor="book-tags">{t("books.edit.fields.tags")}</Label>
            <Input
              id="book-tags"
              value={tagNames}
              onChange={(e) => setTagNames(e.target.value)}
              placeholder={t("books.edit.fields.tagsPlaceholder")}
            />
          </div>
          {update.error ? (
            <p className="text-sm text-destructive">{formatError(update.error, t)}</p>
          ) : null}
          <DialogFooter className="gap-2">
            <Button
              type="button"
              variant="outline"
              onClick={() => onOpenChange(false)}
              disabled={update.isPending}
            >
              {t("common.cancel")}
            </Button>
            <Button type="submit" disabled={update.isPending}>
              {update.isPending ? t("common.saving") : t("common.save")}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}

function splitCsv(raw: string) {
  return raw
    .split(",")
    .map((s) => s.trim())
    .filter((s) => s.length > 0);
}

function formatError(error: unknown, t: (key: string) => string) {
  if (error instanceof ApiError) {
    const body = error.body as { errors?: string[] } | undefined;
    if (body?.errors?.length) return body.errors.join(" / ");
  }
  return t("common.saveFailed");
}
