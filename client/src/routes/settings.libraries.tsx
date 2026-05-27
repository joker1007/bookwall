import { useState, type FormEvent } from "react";
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
            ライブラリ設定
          </h1>
          <p className="mt-1 text-sm text-muted-foreground">
            スキャン対象のディレクトリを管理します。
          </p>
        </div>
        <Button onClick={openCreate} className="gap-2">
          <Plus className="size-4" aria-hidden />
          追加
        </Button>
      </header>

      {list.isPending ? (
        <p className="text-sm text-muted-foreground">読み込み中…</p>
      ) : list.isError ? (
        <p className="text-sm text-destructive">取得に失敗しました。</p>
      ) : (
        <div className="overflow-hidden rounded-lg border border-border">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead className="w-40">名前</TableHead>
                <TableHead>パス</TableHead>
                <TableHead className="w-44 whitespace-nowrap">最終スキャン</TableHead>
                <TableHead className="w-48 text-right">操作</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {list.data!.libraries.length === 0 ? (
                <TableRow>
                  <TableCell colSpan={4} className="text-center text-sm text-muted-foreground">
                    ライブラリはまだありません。
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
    if (!window.confirm(`「${library.name}」を削除します。書籍メタもまとめて削除されます。よろしいですか?`)) return;
    remove.mutate(library.id);
  };

  return (
    <TableRow>
      <TableCell className="font-medium">{library.name}</TableCell>
      <TableCell className="break-all font-mono text-xs">{library.path}</TableCell>
      <TableCell className="text-xs text-muted-foreground">
        {library.last_scanned_at ? library.last_scanned_at.slice(0, 16).replace("T", " ") : "—"}
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
            スキャン
          </Button>
          <Button size="sm" variant="ghost" onClick={onEdit} aria-label="編集">
            <Pencil className="size-4" />
          </Button>
          <Button
            size="sm"
            variant="ghost"
            onClick={handleDelete}
            disabled={remove.isPending}
            aria-label="削除"
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
  const create = useCreateLibrary();
  const update = useUpdateLibrary();
  const isEdit = !!library;
  const [name, setName] = useState(library?.name ?? "");
  const [path, setPath] = useState(library?.path ?? "");

  // Reset state when the dialog opens for a different target
  if (open && library && (library.name !== name && name === "")) {
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
          <DialogTitle>{isEdit ? "ライブラリを編集" : "ライブラリを追加"}</DialogTitle>
        </DialogHeader>
        <form onSubmit={handleSubmit} className="grid gap-4">
          <div className="grid gap-2">
            <Label htmlFor="lib-name">名前</Label>
            <Input
              id="lib-name"
              value={name}
              onChange={(e) => setName(e.target.value)}
              required
              placeholder="自宅 NAS"
            />
          </div>
          <div className="grid gap-2">
            <Label htmlFor="lib-path">パス (サーバから見える絶対パス)</Label>
            <Input
              id="lib-path"
              value={path}
              onChange={(e) => setPath(e.target.value)}
              required
              placeholder="/mnt/books"
            />
          </div>
          {error ? (
            <p className="text-sm text-destructive">{formatError(error)}</p>
          ) : null}
          <DialogFooter className="gap-2">
            <Button
              type="button"
              variant="outline"
              onClick={() => onOpenChange(false)}
              disabled={pending}
            >
              <X className="size-4" /> キャンセル
            </Button>
            <Button type="submit" disabled={pending}>
              {pending ? "保存中…" : "保存"}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}

function formatError(error: unknown) {
  if (error instanceof ApiError) {
    const body = error.body as { errors?: string[] } | undefined;
    if (body?.errors?.length) return body.errors.join(" / ");
  }
  return "保存に失敗しました。";
}
