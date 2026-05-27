import { useEffect, useState, type FormEvent } from "react";
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
  const update = useUpdateBook();
  const [title, setTitle] = useState(book.title);
  const [volume, setVolume] = useState<string>(book.volume?.toString() ?? "");
  const [publishedAt, setPublishedAt] = useState<string>(book.published_at ?? "");
  const [authorNames, setAuthorNames] = useState(book.authors.map((a) => a.name).join(", "));
  const [tagNames, setTagNames] = useState(book.tags.map((t) => t.name).join(", "));

  useEffect(() => {
    if (!open) return;
    setTitle(book.title);
    setVolume(book.volume?.toString() ?? "");
    setPublishedAt(book.published_at ?? "");
    setAuthorNames(book.authors.map((a) => a.name).join(", "));
    setTagNames(book.tags.map((t) => t.name).join(", "));
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
          <DialogTitle>書籍メタデータを編集</DialogTitle>
          <DialogDescription>
            このメタは Bookwall 内のものだけが変更されます。元のファイルは触りません。
          </DialogDescription>
        </DialogHeader>
        <form onSubmit={handleSubmit} className="grid gap-4">
          <div className="grid gap-2">
            <Label htmlFor="book-title">タイトル</Label>
            <Input
              id="book-title"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              required
            />
          </div>
          <div className="grid gap-2 sm:grid-cols-2">
            <div className="grid gap-2">
              <Label htmlFor="book-volume">巻数</Label>
              <Input
                id="book-volume"
                type="number"
                inputMode="numeric"
                value={volume}
                onChange={(e) => setVolume(e.target.value)}
              />
            </div>
            <div className="grid gap-2">
              <Label htmlFor="book-published-at">出版日</Label>
              <Input
                id="book-published-at"
                type="date"
                value={publishedAt}
                onChange={(e) => setPublishedAt(e.target.value)}
              />
            </div>
          </div>
          <div className="grid gap-2">
            <Label htmlFor="book-authors">著者 (カンマ区切り)</Label>
            <Input
              id="book-authors"
              value={authorNames}
              onChange={(e) => setAuthorNames(e.target.value)}
              placeholder="夏目漱石, 芥川龍之介"
            />
          </div>
          <div className="grid gap-2">
            <Label htmlFor="book-tags">タグ (カンマ区切り)</Label>
            <Input
              id="book-tags"
              value={tagNames}
              onChange={(e) => setTagNames(e.target.value)}
              placeholder="近代文学, 短編"
            />
          </div>
          {update.error ? (
            <p className="text-sm text-destructive">{formatError(update.error)}</p>
          ) : null}
          <DialogFooter className="gap-2">
            <Button
              type="button"
              variant="outline"
              onClick={() => onOpenChange(false)}
              disabled={update.isPending}
            >
              キャンセル
            </Button>
            <Button type="submit" disabled={update.isPending}>
              {update.isPending ? "保存中…" : "保存"}
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

function formatError(error: unknown) {
  if (error instanceof ApiError) {
    const body = error.body as { errors?: string[] } | undefined;
    if (body?.errors?.length) return body.errors.join(" / ");
  }
  return "保存に失敗しました。";
}
