import { useEffect, useState } from "react";
import { useTranslation } from "react-i18next";
import { ChevronUp, Folder, FolderOpen } from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Skeleton } from "@/components/ui/skeleton";
import { useFilesystemBrowse } from "@/hooks/useFilesystem";

interface PathBrowserDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  initialPath?: string;
  onSelect: (path: string) => void;
}

export function PathBrowserDialog({
  open,
  onOpenChange,
  initialPath,
  onSelect,
}: PathBrowserDialogProps) {
  const { t } = useTranslation();
  // Track which path the API is currently being queried for. Drives the
  // breadcrumb at the top and resets to the caller's hint each time the
  // dialog re-opens.
  const [current, setCurrent] = useState<string | null>(initialPath ?? null);

  useEffect(() => {
    if (open) setCurrent(initialPath ?? null);
  }, [open, initialPath]);

  const query = useFilesystemBrowse(current, open);
  const data = query.data;

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-lg">
        <DialogHeader>
          <DialogTitle>{t("settings.libraries.browser.title")}</DialogTitle>
          <DialogDescription>
            {t("settings.libraries.browser.description")}
          </DialogDescription>
        </DialogHeader>

        <div className="flex items-center gap-2">
          <Button
            type="button"
            variant="outline"
            size="icon"
            aria-label={t("settings.libraries.browser.up")}
            disabled={!data?.parent}
            onClick={() => data?.parent && setCurrent(data.parent)}
            className="size-10"
          >
            <ChevronUp className="size-4" />
          </Button>
          <Input
            value={data?.path ?? current ?? ""}
            onChange={(e) => setCurrent(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === "Enter") {
                e.preventDefault();
                // Force a refetch of the same path; the query key already
                // reflects the latest input via setCurrent on change.
                query.refetch();
              }
            }}
            className="font-mono text-xs"
            placeholder="/"
          />
        </div>

        <div className="max-h-72 overflow-y-auto rounded-md border border-border">
          {query.isPending ? (
            <ul className="divide-y divide-border">
              {Array.from({ length: 6 }).map((_, i) => (
                <li key={i} className="flex items-center gap-2 px-3 py-2">
                  <Skeleton className="size-4" />
                  <Skeleton className="h-3 flex-1" />
                </li>
              ))}
            </ul>
          ) : !data?.exists ? (
            <p className="px-3 py-6 text-center text-sm text-muted-foreground">
              {t("settings.libraries.browser.notFound")}
            </p>
          ) : !data.readable ? (
            <p className="px-3 py-6 text-center text-sm text-muted-foreground">
              {t("settings.libraries.browser.permissionDenied")}
            </p>
          ) : data.entries.length === 0 ? (
            <p className="px-3 py-6 text-center text-sm text-muted-foreground">
              {t("settings.libraries.browser.empty")}
            </p>
          ) : (
            <ul className="divide-y divide-border">
              {data.entries.map((entry) => (
                <li key={entry.path}>
                  <button
                    type="button"
                    onClick={() => setCurrent(entry.path)}
                    className="flex w-full items-center gap-2 px-3 py-2 text-left text-sm hover:bg-accent/40 focus-visible:bg-accent/40 focus-visible:outline-none"
                  >
                    <Folder className="size-4 shrink-0 text-muted-foreground" />
                    <span className="truncate">{entry.name}</span>
                  </button>
                </li>
              ))}
            </ul>
          )}
        </div>

        <DialogFooter className="gap-2">
          <Button
            type="button"
            variant="outline"
            onClick={() => onOpenChange(false)}
          >
            {t("common.cancel")}
          </Button>
          <Button
            type="button"
            disabled={!data?.exists || !data?.readable}
            onClick={() => {
              if (data?.path) onSelect(data.path);
              onOpenChange(false);
            }}
          >
            <FolderOpen className="size-4" />
            {t("settings.libraries.browser.select")}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
