import { useState } from "react";
import { useTranslation } from "react-i18next";
import { Heart, HeartOff, FolderPlus, FolderMinus, Trash2, X } from "lucide-react";
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
} from "@/hooks/useBulkBookActions";
import { useRemoveBookFromCollection } from "@/hooks/useCollections";

interface BulkActionBarProps {
  selectedIds: number[];
  allSelected: boolean;
  onSelectAll: () => void;
  onClear: () => void;
  // When viewing a single collection, expose "remove from this collection".
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
  const removeFromCollection = useRemoveBookFromCollection();
  const [assignOpen, setAssignOpen] = useState(false);
  const [deleteOpen, setDeleteOpen] = useState(false);

  const count = selectedIds.length;
  const busy =
    favorite.isPending ||
    unfavorite.isPending ||
    destroy.isPending ||
    removeFromCollection.isPending;

  const runAndClear = (mutate: Promise<unknown>) => {
    mutate.then(() => onClear()).catch(() => {});
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
      <div className="sticky bottom-0 z-20 -mx-3 mt-2 flex flex-wrap items-center gap-2 border-t border-border bg-background/95 px-3 py-2 backdrop-blur">
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
      </div>

      <CollectionAssignDialog
        open={assignOpen}
        onOpenChange={setAssignOpen}
        bookIds={selectedIds}
        onAssigned={onClear}
      />

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
