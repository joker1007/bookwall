import { useState } from "react";
import { useTranslation } from "react-i18next";
import {
  FolderMinus,
  FolderPlus,
  Heart,
  HeartOff,
  ImageUp,
  RefreshCw,
  Trash2,
  X,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog";
import { CollectionAssignDialog } from "./CollectionAssignDialog";
import {
  useBulkFavorite,
  useBulkUnfavorite,
  useBulkDestroy,
  useBulkRefresh,
} from "@/hooks/useBulkBookActions";
import { useRemoveBookFromCollection } from "@/hooks/useCollections";
import type { BookRefreshTarget } from "@/hooks/useBookMutation";

interface BulkActionBarProps {
  selectedIds: number[];
  allSelected: boolean;
  onSelectAll: () => void;
  onClear: () => void;
  collectionId?: number | string;
}

export function BulkActionBar({
  selectedIds,
  allSelected,
  onSelectAll,
  onClear,
  collectionId,
}: BulkActionBarProps) {
  const { t } = useTranslation();
  const favorite = useBulkFavorite();
  const unfavorite = useBulkUnfavorite();
  const destroy = useBulkDestroy();
  const refresh = useBulkRefresh();
  const removeFromCollection = useRemoveBookFromCollection();
  const [assignOpen, setAssignOpen] = useState(false);
  const [deleteOpen, setDeleteOpen] = useState(false);
  const [reloadOpen, setReloadOpen] = useState(false);
  const [queuedCount, setQueuedCount] = useState<number | null>(null);

  const count = selectedIds.length;
  const busy =
    favorite.isPending ||
    unfavorite.isPending ||
    destroy.isPending ||
    refresh.isPending ||
    removeFromCollection.isPending;

  const runAndClear = (mutate: Promise<unknown>) => {
    mutate.then(() => onClear()).catch(() => {});
  };

  const runRefresh = (target: BookRefreshTarget) => {
    setQueuedCount(null);
    refresh
      .mutateAsync({ bookIds: selectedIds, target })
      .then(({ queued }) => {
        setQueuedCount(queued);
        onClear();
      })
      .catch(() => {});
  };

  const handleRemoveFromCollection = () => {
    if (collectionId === undefined) return;
    runAndClear(
      Promise.all(
        selectedIds.map((bookId) =>
          removeFromCollection.mutateAsync({ collectionId, bookId }),
        ),
      ),
    );
  };

  return (
    <>
      <div className="sticky top-14 z-20 -mx-3 flex flex-wrap items-center gap-2 border-b border-border bg-background/95 px-3 py-2 backdrop-blur">
        <span className="text-sm font-medium">
          {t("books.bulk.selected", { count })}
        </span>
        <Button variant="ghost" size="sm" onClick={onSelectAll} disabled={allSelected}>
          {t("books.bulk.selectAll")}
        </Button>
        <div className="ml-auto flex flex-wrap items-center gap-2">
          <Button
            variant="outline"
            size="sm"
            className="gap-2"
            disabled={busy || count === 0}
            onClick={() => runAndClear(favorite.mutateAsync(selectedIds))}
          >
            <Heart className="size-4" aria-hidden />
            {t("books.bulk.favorite")}
          </Button>
          <Button
            variant="outline"
            size="sm"
            className="gap-2"
            disabled={busy || count === 0}
            onClick={() => runAndClear(unfavorite.mutateAsync(selectedIds))}
          >
            <HeartOff className="size-4" aria-hidden />
            {t("books.bulk.unfavorite")}
          </Button>
          <Button
            variant="outline"
            size="sm"
            className="gap-2"
            disabled={busy || count === 0}
            onClick={() => setAssignOpen(true)}
          >
            <FolderPlus className="size-4" aria-hidden />
            {t("books.bulk.addToCollection")}
          </Button>
          {collectionId !== undefined ? (
            <Button
              variant="outline"
              size="sm"
              className="gap-2"
              disabled={busy || count === 0}
              onClick={handleRemoveFromCollection}
            >
              <FolderMinus className="size-4" aria-hidden />
              {t("books.bulk.removeFromCollection")}
            </Button>
          ) : null}
          <Button
            variant="outline"
            size="sm"
            className="gap-2"
            disabled={busy || count === 0}
            onClick={() => setReloadOpen(true)}
          >
            <RefreshCw className="size-4" aria-hidden />
            {t("books.bulk.reloadMetadata")}
          </Button>
          <Button
            variant="outline"
            size="sm"
            className="gap-2"
            disabled={busy || count === 0}
            onClick={() => runRefresh("regenerate_cover")}
          >
            <ImageUp className="size-4" aria-hidden />
            {t("books.bulk.regenerateCover")}
          </Button>
          <Button
            variant="outline"
            size="sm"
            className="gap-2 text-destructive hover:text-destructive"
            disabled={busy || count === 0}
            onClick={() => setDeleteOpen(true)}
          >
            <Trash2 className="size-4" aria-hidden />
            {t("books.bulk.delete")}
          </Button>
          <Button variant="ghost" size="icon" aria-label={t("books.bulk.clear")} onClick={onClear}>
            <X className="size-4" aria-hidden />
          </Button>
        </div>
        {queuedCount !== null ? (
          <p role="status" className="w-full text-sm text-muted-foreground">
            {t("books.bulk.refreshQueued", { count: queuedCount })}
          </p>
        ) : null}
        {refresh.isError ? (
          <p className="w-full text-sm text-destructive">{t("books.bulk.refreshFailed")}</p>
        ) : null}
      </div>

      <CollectionAssignDialog
        open={assignOpen}
        onOpenChange={setAssignOpen}
        bookIds={selectedIds}
        onAssigned={onClear}
      />

      <AlertDialog open={reloadOpen} onOpenChange={setReloadOpen}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>{t("books.bulk.reloadConfirmTitle", { count })}</AlertDialogTitle>
            <AlertDialogDescription>
              {t("books.bulk.reloadConfirmDescription")}
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>{t("common.cancel")}</AlertDialogCancel>
            <AlertDialogAction
              onClick={() => {
                runRefresh("reload_metadata");
                setReloadOpen(false);
              }}
            >
              {t("books.bulk.reload")}
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>

      <AlertDialog open={deleteOpen} onOpenChange={setDeleteOpen}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>{t("books.bulk.deleteConfirmTitle", { count })}</AlertDialogTitle>
            <AlertDialogDescription>
              {t("books.bulk.deleteConfirmDescription")}
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel disabled={destroy.isPending}>
              {t("common.cancel")}
            </AlertDialogCancel>
            <AlertDialogAction
              onClick={() => {
                runAndClear(destroy.mutateAsync(selectedIds));
                setDeleteOpen(false);
              }}
              disabled={destroy.isPending}
              className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
            >
              {destroy.isPending ? t("common.deleting") : t("common.delete")}
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </>
  );
}
