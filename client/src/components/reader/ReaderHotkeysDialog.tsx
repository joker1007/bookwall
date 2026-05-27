import { Fragment } from "react";
import type { ReactNode } from "react";
import { useTranslation } from "react-i18next";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";

interface ReaderHotkeysDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  // CBZ / PDF / image_dir support a spread mode where one arrow press
  // advances two pages — Shift+Arrow nudges by one to re-pair them.
  // EPUB has no equivalent so we omit the row there.
  showSinglePageNudge?: boolean;
}

export function ReaderHotkeysDialog({
  open,
  onOpenChange,
  showSinglePageNudge = false,
}: ReaderHotkeysDialogProps) {
  const { t } = useTranslation();

  const shortcuts: { keys: ReactNode; action: string }[] = [
    {
      keys: (
        <>
          <Kbd>Space</Kbd> / <Kbd>→</Kbd>
        </>
      ),
      action: t("reader.hotkeys.nextPage"),
    },
    {
      keys: (
        <>
          <Kbd>Backspace</Kbd> / <Kbd>←</Kbd>
        </>
      ),
      action: t("reader.hotkeys.prevPage"),
    },
    ...(showSinglePageNudge
      ? [
          {
            keys: (
              <>
                <Kbd>Shift</Kbd> + <Kbd>←</Kbd> / <Kbd>→</Kbd>
              </>
            ),
            action: t("reader.hotkeys.singlePageNudge"),
          },
          {
            keys: <Kbd>2</Kbd>,
            action: t("reader.hotkeys.toggleSpread"),
          },
        ]
      : []),
    {
      keys: <Kbd>Esc</Kbd>,
      action: t("reader.hotkeys.close"),
    },
    {
      keys: <Kbd>?</Kbd>,
      action: t("reader.hotkeys.toggleHelp"),
    },
    {
      keys: <span className="text-xs text-muted-foreground">{t("reader.hotkeys.clickEdgesKey")}</span>,
      action: t("reader.hotkeys.clickEdges"),
    },
  ];

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t("reader.hotkeys.title")}</DialogTitle>
          <DialogDescription>{t("reader.hotkeys.description")}</DialogDescription>
        </DialogHeader>
        <dl className="grid grid-cols-[auto_1fr] gap-x-6 gap-y-3 text-sm">
          {shortcuts.map((s, i) => (
            <Fragment key={i}>
              <dt className="flex items-center gap-1">{s.keys}</dt>
              <dd className="text-muted-foreground">{s.action}</dd>
            </Fragment>
          ))}
        </dl>
      </DialogContent>
    </Dialog>
  );
}

function Kbd({ children }: { children: ReactNode }) {
  return (
    <kbd className="inline-flex min-w-7 items-center justify-center rounded border border-border bg-muted px-1.5 py-0.5 font-mono text-[11px] font-medium text-foreground">
      {children}
    </kbd>
  );
}
