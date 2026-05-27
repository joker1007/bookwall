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
import { useDeleteSeries } from "@/hooks/useTaxonomy";
import type { Series } from "@/types/api";

interface DeleteSeriesButtonProps {
  series: Series;
}

export function DeleteSeriesButton({ series }: DeleteSeriesButtonProps) {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const remove = useDeleteSeries();
  const [open, setOpen] = useState(false);

  const handleConfirm = () => {
    remove.mutate(series.id, {
      onSuccess: () => {
        setOpen(false);
        navigate("/series", { replace: true });
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
          {t("series.delete")}
        </Button>
      </AlertDialogTrigger>
      <AlertDialogContent>
        <AlertDialogHeader>
          <AlertDialogTitle>
            {t("series.deleteConfirmTitle", { name: series.name })}
          </AlertDialogTitle>
          <AlertDialogDescription>
            {t("series.deleteConfirmDescription", { count: series.book_count })}
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
