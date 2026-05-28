import { useState, type FormEvent } from "react";
import { useTranslation } from "react-i18next";
import { FolderSearch, ScanLine, Trash2, Pencil, Plus, X } from "lucide-react";
import { PathBrowserDialog } from "@/components/settings/PathBrowserDialog";
import { cn } from "@/lib/utils";
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
import { Toggle } from "@/components/ui/toggle";
import { ToggleGroup, ToggleGroupItem } from "@/components/ui/toggle-group";
import {
  useLibraries,
  useCreateLibrary,
  useUpdateLibrary,
  useDeleteLibrary,
  useScanLibrary,
  useLibraryScans,
} from "@/hooks/useLibraries";
import {
  useUpdateUserPreferences,
  useUserPreferences,
} from "@/hooks/useUserPreferences";
import { ApiError } from "@/lib/api";
import {
  READER_FONT_SIZE_DEFAULT,
  READER_FONT_SIZE_MAX,
  READER_FONT_SIZE_MIN,
  READER_FONT_SIZE_STEP,
  READER_PRELOAD_AHEAD_DEFAULT,
  READER_PRELOAD_AHEAD_OPTIONS,
  READER_SCALE_VALUES,
  READER_THEME_VALUES,
  READER_WRITING_MODE_VALUES,
} from "@/types/api";
import type {
  Library,
  ReaderScale,
  ReaderSettings,
  ReaderTheme,
  ReaderWritingMode,
  ScanLog,
} from "@/types/api";

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

      <ReaderDefaultsSection />
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
  const scans = useLibraryScans(library.id);
  const latest = scans.data?.scans?.[0];
  const running = latest?.status === "running";

  const handleScan = () => {
    scan.mutate(library.id);
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
        <div className="flex flex-col gap-1">
          <span>
            {library.last_scanned_at
              ? library.last_scanned_at.slice(0, 16).replace("T", " ")
              : t("common.never")}
          </span>
          {latest ? <ScanStatusBadge log={latest} /> : null}
        </div>
      </TableCell>
      <TableCell>
        <div className="flex justify-end gap-1">
          <Button
            size="sm"
            variant="outline"
            onClick={handleScan}
            disabled={scan.isPending || running}
            className="gap-1"
          >
            <ScanLine className={cn("size-4", running && "animate-pulse")} />
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

function ScanStatusBadge({ log }: { log: ScanLog }) {
  const { t } = useTranslation();
  if (log.status === "running") {
    const total = (log.added_count ?? 0) + (log.updated_count ?? 0);
    const processed = log.processed_count ?? 0;
    return (
      <span className="inline-flex items-center gap-1 rounded bg-blue-500/10 px-1.5 py-0.5 font-mono text-[11px] text-blue-700 dark:text-blue-300">
        <span className="size-1.5 animate-pulse rounded-full bg-blue-500" aria-hidden />
        {total > 0
          ? t("settings.libraries.scanStatus.runningProgress", { processed, total })
          : t("settings.libraries.scanStatus.runningIndeterminate")}
      </span>
    );
  }
  if (log.status === "failed") {
    return (
      <span
        className="inline-flex items-center rounded bg-destructive/10 px-1.5 py-0.5 text-[11px] text-destructive"
        title={log.error_message ?? undefined}
      >
        {t("settings.libraries.scanStatus.failed")}
      </span>
    );
  }
  if (log.status === "succeeded") {
    return (
      <span className="text-[11px] text-muted-foreground">
        {t("settings.libraries.scanStatus.succeeded", {
          added: log.added_count,
          updated: log.updated_count,
        })}
      </span>
    );
  }
  return null;
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
  const [browserOpen, setBrowserOpen] = useState(false);

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
            <div className="flex items-center gap-2">
              <Input
                id="lib-path"
                value={path}
                onChange={(e) => setPath(e.target.value)}
                required
                placeholder={t("settings.libraries.dialog.pathPlaceholder")}
                className="flex-1 font-mono text-xs"
              />
              <Button
                type="button"
                variant="outline"
                size="icon"
                aria-label={t("settings.libraries.browser.open")}
                onClick={() => setBrowserOpen(true)}
                className="size-10"
              >
                <FolderSearch className="size-4" />
              </Button>
            </div>
          </div>

          <PathBrowserDialog
            open={browserOpen}
            onOpenChange={setBrowserOpen}
            initialPath={path || undefined}
            onSelect={setPath}
          />
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

function ReaderDefaultsSection() {
  const { t } = useTranslation();
  const preferences = useUserPreferences();
  const update = useUpdateUserPreferences();

  const defaults = preferences.data?.reader_defaults ?? {};
  const spread = defaults.spread ?? false;
  const direction = (defaults.direction ?? "ltr") as "ltr" | "rtl";
  const scale = (defaults.scale ?? "fit") as ReaderScale;
  const preloadAhead = defaults.preload_ahead ?? READER_PRELOAD_AHEAD_DEFAULT;
  const fontSize = defaults.font_size ?? READER_FONT_SIZE_DEFAULT;
  const theme = (defaults.theme ?? "light") as ReaderTheme;
  const writingMode = (defaults.writing_mode ?? "auto") as ReaderWritingMode;

  const save = (patch: ReaderSettings) => {
    update.mutate({
      reader_defaults: {
        spread,
        direction,
        scale,
        preload_ahead: preloadAhead,
        font_size: fontSize,
        theme,
        writing_mode: writingMode,
        ...patch,
      },
    });
  };

  return (
    <section className="grid gap-4 rounded-lg border border-border bg-card p-4">
      <header className="flex flex-col gap-1">
        <h2 className="text-lg font-semibold tracking-tight">
          {t("settings.readerDefaults.title")}
        </h2>
        <p className="text-sm text-muted-foreground">
          {t("settings.readerDefaults.description")}
        </p>
      </header>

      {preferences.isPending ? (
        <p className="text-sm text-muted-foreground">{t("common.loading")}</p>
      ) : preferences.isError ? (
        <p className="text-sm text-destructive">{t("common.fetchFailed")}</p>
      ) : (
        <div className="grid gap-6">
          <div className="grid gap-4">
            <h3 className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">
              {t("settings.readerDefaults.cbzGroup")}
            </h3>
          <div className="flex items-center justify-between gap-3">
            <Label htmlFor="reader-default-spread">{t("reader.spread")}</Label>
            <Toggle
              id="reader-default-spread"
              pressed={spread}
              onPressedChange={(v) => save({ spread: v })}
              variant="outline"
              size="sm"
              aria-label={t("reader.spread")}
              disabled={update.isPending}
            >
              {spread ? t("reader.on") : t("reader.off")}
            </Toggle>
          </div>

          <div className="grid gap-2">
            <Label>{t("reader.direction")}</Label>
            <ToggleGroup
              type="single"
              value={direction}
              onValueChange={(v) => {
                if (v === "ltr" || v === "rtl") save({ direction: v });
              }}
              variant="outline"
              className="justify-start"
              disabled={update.isPending}
            >
              <ToggleGroupItem value="ltr" aria-label={t("reader.directionLtr")}>
                {t("reader.directionLtr")}
              </ToggleGroupItem>
              <ToggleGroupItem value="rtl" aria-label={t("reader.directionRtl")}>
                {t("reader.directionRtl")}
              </ToggleGroupItem>
            </ToggleGroup>
          </div>

          <div className="grid gap-2">
            <Label>{t("reader.scale")}</Label>
            <ToggleGroup
              type="single"
              value={scale}
              onValueChange={(v) => {
                if (READER_SCALE_VALUES.includes(v as ReaderScale)) {
                  save({ scale: v as ReaderScale });
                }
              }}
              variant="outline"
              className="flex-wrap justify-start"
              disabled={update.isPending}
            >
              {READER_SCALE_VALUES.map((value) => (
                <ToggleGroupItem
                  key={value}
                  value={value}
                  aria-label={t(`reader.scaleMode.${value}`)}
                >
                  {t(`reader.scaleMode.${value}`)}
                </ToggleGroupItem>
              ))}
            </ToggleGroup>
          </div>

          <div className="grid gap-2">
            <Label>{t("settings.readerDefaults.preloadAhead")}</Label>
            <ToggleGroup
              type="single"
              value={String(preloadAhead)}
              onValueChange={(v) => {
                if (!v) return;
                const n = Number(v);
                if (Number.isInteger(n) && READER_PRELOAD_AHEAD_OPTIONS.includes(n as 0 | 2 | 4 | 8)) {
                  save({ preload_ahead: n });
                }
              }}
              variant="outline"
              className="flex-wrap justify-start"
              disabled={update.isPending}
            >
              {READER_PRELOAD_AHEAD_OPTIONS.map((value) => (
                <ToggleGroupItem
                  key={value}
                  value={String(value)}
                  aria-label={t("settings.readerDefaults.preloadAheadValue", { count: value })}
                >
                  {value}
                </ToggleGroupItem>
              ))}
            </ToggleGroup>
            <p className="text-xs text-muted-foreground">
              {t("settings.readerDefaults.preloadAheadHint")}
            </p>
          </div>
          </div>

          <div className="grid gap-4 border-t border-border pt-4">
            <h3 className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">
              {t("settings.readerDefaults.epubGroup")}
            </h3>
          <div className="grid gap-2">
            <Label>{t("reader.epubFontSize")}</Label>
            <div className="flex items-center gap-2">
              <Button
                type="button"
                variant="outline"
                size="sm"
                onClick={() => save({ font_size: Math.max(READER_FONT_SIZE_MIN, fontSize - READER_FONT_SIZE_STEP) })}
                disabled={update.isPending || fontSize <= READER_FONT_SIZE_MIN}
              >
                -
              </Button>
              <span className="min-w-12 text-center text-sm tabular-nums">
                {fontSize}%
              </span>
              <Button
                type="button"
                variant="outline"
                size="sm"
                onClick={() => save({ font_size: Math.min(READER_FONT_SIZE_MAX, fontSize + READER_FONT_SIZE_STEP) })}
                disabled={update.isPending || fontSize >= READER_FONT_SIZE_MAX}
              >
                +
              </Button>
            </div>
          </div>

          <div className="grid gap-2">
            <Label>{t("reader.theme.label")}</Label>
            <ToggleGroup
              type="single"
              value={theme}
              onValueChange={(v) => {
                if (READER_THEME_VALUES.includes(v as ReaderTheme)) {
                  save({ theme: v as ReaderTheme });
                }
              }}
              variant="outline"
              className="flex-wrap justify-start"
              disabled={update.isPending}
            >
              {READER_THEME_VALUES.map((value) => (
                <ToggleGroupItem
                  key={value}
                  value={value}
                  aria-label={t(`reader.theme.${value}`)}
                >
                  {t(`reader.theme.${value}`)}
                </ToggleGroupItem>
              ))}
            </ToggleGroup>
          </div>

          <div className="grid gap-2">
            <Label>{t("reader.writingMode.label")}</Label>
            <ToggleGroup
              type="single"
              value={writingMode}
              onValueChange={(v) => {
                if (READER_WRITING_MODE_VALUES.includes(v as ReaderWritingMode)) {
                  save({ writing_mode: v as ReaderWritingMode });
                }
              }}
              variant="outline"
              className="flex-wrap justify-start"
              disabled={update.isPending}
            >
              {READER_WRITING_MODE_VALUES.map((value) => (
                <ToggleGroupItem
                  key={value}
                  value={value}
                  aria-label={t(`reader.writingMode.${value}`)}
                >
                  {t(`reader.writingMode.${value}`)}
                </ToggleGroupItem>
              ))}
            </ToggleGroup>
          </div>
          </div>
        </div>
      )}
    </section>
  );
}
