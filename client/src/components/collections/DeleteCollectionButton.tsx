import { useState } from "react";
import { useTranslation } from "react-i18next";
import { useNavigate } from "react-router-dom";
import { Trash2 } from "lucide-react";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
  AlertDialogTrigger,
} from "@/components/ui/alert-dialog";
import { Button } from "@/components/ui/button";
import { useDeleteCollection } from "@/hooks/useCollections";
import type { Collection } from "@/types/api";

interface DeleteCollectionButtonProps {
  collection: Collection;
}

export function DeleteCollectionButton({ collection }: DeleteCollectionButtonProps) {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const remove = useDeleteCollection();
  const [open, setOpen] = useState(false);

  const handleConfirm = () => {
    remove.mutate(collection.id, {
      onSuccess: () => {
        setOpen(false);
        navigate("/collections", { replace: true });
      },
    });
  };

  return (
    <AlertDialog open={open} onOpenChange={setOpen}>
      <AlertDialogTrigger asChild>
        <Button
          variant="outline"
          size="sm"
          className="gap-2 text-destructive hover:text-destructive"
        >
          <Trash2 className="size-4" aria-hidden />
          {t("collections.delete")}
        </Button>
      </AlertDialogTrigger>
      <AlertDialogContent>
        <AlertDialogHeader>
          <AlertDialogTitle>
            {t("collections.deleteConfirmTitle", { name: collection.name })}
          </AlertDialogTitle>
          <AlertDialogDescription>
            {t("collections.deleteConfirmDescription")}
          </AlertDialogDescription>
        </AlertDialogHeader>
        <AlertDialogFooter>
          <AlertDialogCancel disabled={remove.isPending}>
            {t("common.cancel")}
          </AlertDialogCancel>
          <AlertDialogAction
            onClick={handleConfirm}
            disabled={remove.isPending}
            className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
          >
            {remove.isPending ? t("common.deleting") : t("common.delete")}
          </AlertDialogAction>
        </AlertDialogFooter>
      </AlertDialogContent>
    </AlertDialog>
  );
}
