import { useState, type FormEvent } from "react";
import { useTranslation } from "react-i18next";
import { ScanLine, Trash2, Pencil, Plus, Check, X } from "lucide-react";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import {
  useLibraries,
  useCreateLibrary,
  useUpdateLibrary,
  useDeleteLibrary,
  useScanLibrary,
} from "@/hooks/useLibraries";
import { ApiError } from "@/lib/api";
import type { Library } from "@/types/api";

export default function LibrariesSettings() {
  const { t } = useTranslation();
  const list = useLibraries();
  const [open, setOpen] = useState(false);
  const [editing, setEditing] = useState<Library | null>(null);

  const openCreate = () => {
    setEditing(null);
    setOpen(true);
  };
  const openEdit = (library: Library) => {
    setEditing(library);
    setOpen(true);
  };

  return (
    <section className="mx-auto flex max-w-6xl flex-col gap-6 px-4 py-6">
      <header className="flex items-start justify-between gap-3">
        <div>
          <h1 className="text-2xl font-semibold tracking-tight md:text-3xl">
            {t("settings.libraries.title")}
          </h1>
          <p className="mt-1 text-sm text-muted-foreground">
            {t("settings.libraries.description")}
          </p>
        </div>
        <Button onClick={openCreate} className="gap-2">
          <Plus className="size-4" aria-hidden />
          {t("settings.libraries.add")}
        </Button>
      </header>

      {list.isPending ? (
        <p className="text-sm text-muted-foreground">{t("common.loading")}</p>
      ) : list.isError ? (
        <p className="text-sm text-destructive">{t("common.fetchFailed")}</p>
      ) : (
        <div className="overflow-hidden rounded-lg border border-border">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead className="w-40">{t("settings.libraries.columns.name")}</TableHead>
                <TableHead>{t("settings.libraries.columns.path")}</TableHead>
                <TableHead className="w-44 whitespace-nowrap">
                  {t("settings.libraries.columns.lastScannedAt")}
                </TableHead>
                <TableHead className="w-48 text-right">
                  {t("settings.libraries.columns.actions")}
                </TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {list.data!.libraries.length === 0 ? (
                <TableRow>
                  <TableCell colSpan={4} className="text-center text-sm text-muted-foreground">
                    {t("settings.libraries.empty")}
                  </TableCell>
                </TableRow>
              ) : (
                list.data!.libraries.map((library) => (
                  <LibraryRow
                    key={library.id}
                    library={library}
                    onEdit={() => openEdit(library)}
                  />
                ))
              )}
            </TableBody>
          </Table>
        </div>
      )}

      <LibraryDialog
        open={open}
        onOpenChange={setOpen}
        library={editing}
      />
    </section>
  );
}

interface LibraryRowProps {
  library: Library;
  onEdit: () => void;
}

function LibraryRow({ library, onEdit }: LibraryRowProps) {
  const { t } = useTranslation();
  const scan = useScanLibrary();
  const remove = useDeleteLibrary();
  const [scanned, setScanned] = useState(false);

  const handleScan = () => {
    setScanned(false);
    scan.mutate(library.id, {
      onSuccess: () => {
        setScanned(true);
        window.setTimeout(() => setScanned(false), 3000);
      },
    });
  };

  const handleDelete = () => {
    if (!window.confirm(t("settings.libraries.deleteConfirm", { name: library.name }))) return;
    remove.mutate(library.id);
  };

  return (
    <TableRow>
      <TableCell className="font-medium">{library.name}</TableCell>
      <TableCell className="break-all font-mono text-xs">{library.path}</TableCell>
      <TableCell className="text-xs text-muted-foreground">
        {library.last_scanned_at
          ? library.last_scanned_at.slice(0, 16).replace("T", " ")
          : t("common.never")}
      </TableCell>
      <TableCell>
        <div className="flex justify-end gap-1">
          <Button
            size="sm"
            variant="outline"
            onClick={handleScan}
            disabled={scan.isPending}
            className="gap-1"
          >
            {scanned ? <Check className="size-4" /> : <ScanLine className="size-4" />}
            {t("common.scanning")}
          </Button>
          <Button size="sm" variant="ghost" onClick={onEdit} aria-label={t("common.edit")}>
            <Pencil className="size-4" />
          </Button>
          <Button
            size="sm"
            variant="ghost"
            onClick={handleDelete}
            disabled={remove.isPending}
            aria-label={t("common.delete")}
            className="text-destructive hover:text-destructive"
          >
            <Trash2 className="size-4" />
          </Button>
        </div>
      </TableCell>
    </TableRow>
  );
}

interface LibraryDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  library: Library | null;
}

function LibraryDialog({ open, onOpenChange, library }: LibraryDialogProps) {
  const { t } = useTranslation();
  const create = useCreateLibrary();
  const update = useUpdateLibrary();
  const isEdit = !!library;
  const [name, setName] = useState(library?.name ?? "");
  const [path, setPath] = useState(library?.path ?? "");

  if (open && library && library.name !== name && name === "") {
    setName(library.name);
    setPath(library.path);
  }

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    try {
      if (isEdit && library) {
        await update.mutateAsync({ id: library.id, name, path });
      } else {
        await create.mutateAsync({ name, path });
        setName("");
        setPath("");
      }
      onOpenChange(false);
    } catch {
      // surfaced below
    }
  };

  const error = isEdit ? update.error : create.error;
  const pending = isEdit ? update.isPending : create.isPending;

  return (
    <Dialog
      open={open}
      onOpenChange={(o) => {
        if (!o) {
          setName(library?.name ?? "");
          setPath(library?.path ?? "");
          create.reset();
          update.reset();
        }
        onOpenChange(o);
      }}
    >
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>
            {isEdit
              ? t("settings.libraries.dialog.editTitle")
              : t("settings.libraries.dialog.createTitle")}
          </DialogTitle>
        </DialogHeader>
        <form onSubmit={handleSubmit} className="grid gap-4">
          <div className="grid gap-2">
            <Label htmlFor="lib-name">{t("settings.libraries.dialog.name")}</Label>
            <Input
              id="lib-name"
              value={name}
              onChange={(e) => setName(e.target.value)}
              required
              placeholder={t("settings.libraries.dialog.namePlaceholder")}
            />
          </div>
          <div className="grid gap-2">
            <Label htmlFor="lib-path">{t("settings.libraries.dialog.path")}</Label>
            <Input
              id="lib-path"
              value={path}
              onChange={(e) => setPath(e.target.value)}
              required
              placeholder={t("settings.libraries.dialog.pathPlaceholder")}
            />
          </div>
          {error ? (
            <p className="text-sm text-destructive">{formatError(error, t)}</p>
          ) : null}
          <DialogFooter className="gap-2">
            <Button
              type="button"
              variant="outline"
              onClick={() => onOpenChange(false)}
              disabled={pending}
            >
              <X className="size-4" /> {t("common.cancel")}
            </Button>
            <Button type="submit" disabled={pending}>
              {pending ? t("common.saving") : t("common.save")}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}

function formatError(error: unknown, t: (key: string) => string) {
  if (error instanceof ApiError) {
    const body = error.body as { errors?: string[] } | undefined;
    if (body?.errors?.length) return body.errors.join(" / ");
  }
  return t("common.saveFailed");
}
