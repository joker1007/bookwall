import { useState } from "react";
import { Link, useParams, useNavigate } from "react-router-dom";
import { useTranslation } from "react-i18next";
import { BookOpen, Heart, Pencil, Trash2, ArrowLeft } from "lucide-react";
import { useBook, useFavoriteBook } from "@/hooks/useBooks";
import { useDeleteBook } from "@/hooks/useBookMutation";
import { useAuthStore } from "@/stores/authStore";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";
import { BookCover } from "@/components/books/BookCover";
import { BookEditDialog } from "@/components/books/BookEditDialog";

export default function BookDetailPage() {
  const { t } = useTranslation();
  const { id } = useParams();
  const navigate = useNavigate();
  const query = useBook(id);
  const favorite = useFavoriteBook();
  const remove = useDeleteBook();
  const user = useAuthStore((s) => s.user);
  const [editOpen, setEditOpen] = useState(false);

  if (query.isPending) {
    return (
      <div className="mx-auto flex max-w-6xl flex-col gap-6 px-4 py-6">
        <Skeleton className="h-6 w-24" />
        <div className="grid gap-6 md:grid-cols-[240px,1fr]">
          <Skeleton className="aspect-[2/3] w-60" />
          <div className="space-y-3">
            <Skeleton className="h-8 w-3/4" />
            <Skeleton className="h-4 w-1/2" />
            <Skeleton className="h-4 w-1/3" />
          </div>
        </div>
      </div>
    );
  }
  if (query.isError || !query.data) {
    return (
      <section className="mx-auto max-w-3xl px-4 py-6">
        <p className="text-sm text-destructive">{t("books.detail.loadFailed")}</p>
      </section>
    );
  }

  const book = query.data;
  const isFavorited = book.favorited;

  const handleDelete = () => {
    if (!window.confirm(t("books.detail.deleteConfirm", { title: book.title }))) return;
    remove.mutate(book.id, {
      onSuccess: () => navigate("/", { replace: true }),
    });
  };

  return (
    <section className="mx-auto flex max-w-6xl flex-col gap-6 px-4 py-6">
      <div>
        <Button variant="ghost" size="sm" onClick={() => navigate(-1)} className="gap-2 px-2">
          <ArrowLeft className="size-4" aria-hidden /> {t("common.back")}
        </Button>
      </div>

      <div className="grid gap-6 md:grid-cols-[240px,1fr]">
        <div className="w-44 sm:w-52 md:w-60">
          <BookCover book={book} size="full" />
        </div>

        <div className="flex min-w-0 flex-col gap-3">
          <header className="flex flex-col gap-2">
            <h1 className="text-2xl font-semibold tracking-tight md:text-3xl">
              {book.title}
              {book.volume ? (
                <span className="ml-2 text-base text-muted-foreground">
                  {t("books.volumeSuffix", { volume: book.volume })}
                </span>
              ) : null}
            </h1>
            {book.series_name && book.series_id ? (
              <p className="text-sm">
                {t("books.detail.seriesLabel")}{" "}
                <Link
                  to={`/series/${book.series_id}`}
                  className="text-foreground underline-offset-4 hover:underline"
                >
                  {book.series_name}
                </Link>
              </p>
            ) : null}
            {book.authors.length > 0 ? (
              <p className="flex flex-wrap items-baseline gap-x-2 text-sm text-muted-foreground">
                <span>{t("books.detail.authorsLabel")}</span>
                {book.authors.map((a) => (
                  <Link
                    key={a.id}
                    to={`/authors/${a.id}`}
                    className="text-foreground underline-offset-4 hover:underline"
                  >
                    {a.name}
                  </Link>
                ))}
              </p>
            ) : null}
            {book.tags.length > 0 ? (
              <div className="flex flex-wrap gap-1">
                {book.tags.map((tag) => (
                  <Link key={tag.id} to={`/tags/${tag.id}`}>
                    <Badge variant="secondary" className="cursor-pointer">
                      {tag.name}
                    </Badge>
                  </Link>
                ))}
              </div>
            ) : null}
          </header>

          <dl className="grid gap-2 rounded-lg border border-border bg-card p-3 text-sm sm:grid-cols-2">
            <Field label={t("books.detail.formatLabel")} value={t(`books.formats.${book.file_format}`)} />
            <Field
              label={t("books.detail.pageCountLabel")}
              value={book.page_count?.toString() ?? t("common.never")}
            />
            <Field
              label={t("books.detail.publishedAtLabel")}
              value={book.published_at ?? t("common.never")}
            />
            <Field
              label={t("books.detail.addedAtLabel")}
              value={book.added_at?.slice(0, 10) ?? t("common.never")}
            />
            <Field
              label={t("books.detail.fileSizeLabel")}
              value={formatSize(book.file_size, t("common.never"))}
            />
            <Field
              label={t("books.detail.filePathLabel")}
              value={<span className="break-all font-mono text-xs">{book.file_path}</span>}
            />
          </dl>

          <div className="flex flex-wrap items-center gap-2">
            <Button
              variant="default"
              onClick={() => navigate(`/books/${book.id}/read`)}
              className="gap-2"
            >
              <BookOpen className="size-4" aria-hidden />
              {t("reader.open")}
            </Button>
            <Button
              variant={isFavorited ? "default" : "outline"}
              onClick={() =>
                favorite.mutate({ id: book.id, favorited: isFavorited })
              }
              disabled={!user || favorite.isPending}
              className="gap-2"
            >
              <Heart
                className={`size-4 ${isFavorited ? "fill-current" : ""}`}
                aria-hidden
              />
              {isFavorited ? t("books.detail.favorited") : t("books.detail.favorite")}
            </Button>
            <Button variant="outline" onClick={() => setEditOpen(true)} className="gap-2">
              <Pencil className="size-4" aria-hidden />
              {t("books.detail.edit")}
            </Button>
            <Button
              variant="ghost"
              onClick={handleDelete}
              disabled={remove.isPending}
              className="gap-2 text-destructive hover:text-destructive"
            >
              <Trash2 className="size-4" aria-hidden />
              {t("books.detail.deleteMeta")}
            </Button>
          </div>
        </div>
      </div>

      <BookEditDialog book={book} open={editOpen} onOpenChange={setEditOpen} />
    </section>
  );
}

function Field({ label, value }: { label: string; value: React.ReactNode }) {
  return (
    <div className="flex flex-col gap-0.5">
      <dt className="text-xs uppercase tracking-wide text-muted-foreground">{label}</dt>
      <dd className="break-words">{value}</dd>
    </div>
  );
}

function formatSize(bytes: number, emptyLabel: string) {
  if (!bytes) return emptyLabel;
  const units = ["B", "KB", "MB", "GB"];
  let value = bytes;
  let i = 0;
  while (value >= 1024 && i < units.length - 1) {
    value /= 1024;
    i++;
  }
  return `${value.toFixed(value < 10 && i > 0 ? 1 : 0)} ${units[i]}`;
}
