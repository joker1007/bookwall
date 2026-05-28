import { useState, type FormEvent } from "react";
import { useTranslation } from "react-i18next";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  useCollectionsList,
  useCreateCollection,
  useAddBooksToCollection,
} from "@/hooks/useCollections";

interface CollectionAssignDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  bookIds: number[];
  onAssigned?: () => void;
}

// Adds the selected books to a collection. The user can pick an existing
// collection or type a name to create a new one in the same step.
export function CollectionAssignDialog({
  open,
  onOpenChange,
  bookIds,
  onAssigned,
}: CollectionAssignDialogProps) {
  const { t } = useTranslation();
  const collections = useCollectionsList({ limit: 200 });
  const create = useCreateCollection();
  const addBooks = useAddBooksToCollection();

  const [existingId, setExistingId] = useState<string>("");
  const [newName, setNewName] = useState("");

  // Reset the form whenever the dialog (re)opens (render-time, no effect).
  const [prevOpen, setPrevOpen] = useState(open);
  if (open !== prevOpen) {
    setPrevOpen(open);
    if (open) {
      setExistingId("");
      setNewName("");
    }
  }

  const items = collections.data?.collections ?? [];
  const pending = create.isPending || addBooks.isPending;
  const trimmedNew = newName.trim();
  const canSubmit = bookIds.length > 0 && (trimmedNew !== "" || existingId !== "");

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    if (!canSubmit) return;
    try {
      const collectionId = trimmedNew
        ? (await create.mutateAsync(trimmedNew)).id
        : Number(existingId);
      await addBooks.mutateAsync({ collectionId, bookIds });
      onOpenChange(false);
      onAssigned?.();
    } catch {
      // Errors surface via the mutation state below.
    }
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>{t("books.bulk.addToCollection")}</DialogTitle>
          <DialogDescription>
            {t("books.bulk.assignDescription", { count: bookIds.length })}
          </DialogDescription>
        </DialogHeader>
        <form onSubmit={handleSubmit} className="grid gap-4">
          <div className="grid gap-2">
            <Label>{t("collections.assignExisting")}</Label>
            <Select
              value={existingId}
              onValueChange={(v) => {
                setExistingId(v);
                setNewName("");
              }}
              disabled={items.length === 0}
            >
              <SelectTrigger>
                <SelectValue placeholder={t("collections.assignChoose")} />
              </SelectTrigger>
              <SelectContent>
                {items.map((c) => (
                  <SelectItem key={c.id} value={String(c.id)}>
                    {c.name}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
          <div className="grid gap-2">
            <Label htmlFor="assign-new-name">{t("collections.assignOrCreate")}</Label>
            <Input
              id="assign-new-name"
              value={newName}
              onChange={(e) => {
                setNewName(e.target.value);
                if (e.target.value) setExistingId("");
              }}
              placeholder={t("collections.namePlaceholder")}
            />
          </div>
          {create.error || addBooks.error ? (
            <p className="text-sm text-destructive">{t("common.saveFailed")}</p>
          ) : null}
          <DialogFooter>
            <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
              {t("common.cancel")}
            </Button>
            <Button type="submit" disabled={pending || !canSubmit}>
              {pending ? t("common.saving") : t("books.bulk.addToCollection")}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
