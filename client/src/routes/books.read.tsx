import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import type { MouseEvent as ReactMouseEvent } from "react";
import { useNavigate, useParams } from "react-router-dom";
import { useTranslation } from "react-i18next";
import { ArrowLeft, BookOpen, Settings as SettingsIcon } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
  SheetDescription,
} from "@/components/ui/sheet";
import { Toggle } from "@/components/ui/toggle";
import { ToggleGroup, ToggleGroupItem } from "@/components/ui/toggle-group";
import { useBook } from "@/hooks/useBooks";
import {
  useReadingProgress,
  useUpdateReadingProgress,
} from "@/hooks/useReadingProgress";
import type { ReaderSettings } from "@/types/api";

const DEBOUNCE_MS = 800;

export default function ReaderPage() {
  const { t } = useTranslation();
  const { id } = useParams();
  const navigate = useNavigate();
  const book = useBook(id);
  const progress = useReadingProgress(id);
  const update = useUpdateReadingProgress(id ?? "");

  const [page, setPage] = useState(0);
  const [spread, setSpread] = useState(false);
  const [direction, setDirection] = useState<"ltr" | "rtl">("ltr");
  const [settingsOpen, setSettingsOpen] = useState(false);
  const [initialized, setInitialized] = useState(false);

  // Restore once the progress fetch resolves
  useEffect(() => {
    if (initialized || !progress.data) return;
    setPage(progress.data.current_page);
    setSpread(progress.data.settings.spread ?? false);
    setDirection(progress.data.settings.direction ?? "ltr");
    setInitialized(true);
  }, [progress.data, initialized]);

  const total = book.data?.page_count ?? 0;
  const step = spread ? 2 : 1;
  const lastPage = Math.max(0, total - 1);

  const goNext = useCallback(() => {
    setPage((p) => Math.min(p + step, lastPage));
  }, [step, lastPage]);

  const goPrev = useCallback(() => {
    setPage((p) => Math.max(p - step, 0));
  }, [step]);

  // Debounced progress save (only after we've restored, so we don't clobber
  // the saved value with the initial 0).
  const debounceRef = useRef<number | null>(null);
  useEffect(() => {
    if (!initialized || !id) return;
    if (debounceRef.current) window.clearTimeout(debounceRef.current);
    debounceRef.current = window.setTimeout(() => {
      update.mutate({ current_page: page });
    }, DEBOUNCE_MS);
    return () => {
      if (debounceRef.current) window.clearTimeout(debounceRef.current);
    };
    // update.mutate is stable enough; intentionally only depend on page.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [page, initialized, id]);

  const saveSettings = useCallback(
    (next: ReaderSettings) => {
      if (!id) return;
      update.mutate({ settings: next });
    },
    [id, update],
  );

  const handleSpreadChange = (value: boolean) => {
    setSpread(value);
    saveSettings({ spread: value, direction });
  };
  const handleDirectionChange = (value: "ltr" | "rtl") => {
    setDirection(value);
    saveSettings({ spread, direction: value });
  };

  // Keyboard navigation (suspended while the settings sheet is open so the
  // sheet's own focus trap can use arrows without paging the reader).
  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      if (settingsOpen) return;
      // Avoid interfering with text inputs (none in this view, but defensive)
      const target = e.target as HTMLElement | null;
      if (target?.tagName === "INPUT" || target?.tagName === "TEXTAREA") return;

      if (e.key === "ArrowRight" || e.key === " " || e.code === "Space") {
        e.preventDefault();
        goNext();
      } else if (e.key === "ArrowLeft" || e.key === "Backspace") {
        e.preventDefault();
        goPrev();
      } else if (e.key === "Escape" && id) {
        e.preventDefault();
        navigate(`/books/${id}`);
      }
    };
    window.addEventListener("keydown", handler);
    return () => window.removeEventListener("keydown", handler);
  }, [goNext, goPrev, navigate, id, settingsOpen]);

  const handleViewportClick = (e: ReactMouseEvent<HTMLDivElement>) => {
    const rect = e.currentTarget.getBoundingClientRect();
    const isLeftHalf = e.clientX - rect.left < rect.width / 2;
    // LTR: left → prev, right → next; RTL inverts
    const goingPrev = direction === "ltr" ? isLeftHalf : !isLeftHalf;
    (goingPrev ? goPrev : goNext)();
  };

  const visiblePages = useMemo(() => {
    if (total === 0) return [];
    const base = spread ? [page, page + 1].filter((p) => p < total) : [page];
    return direction === "rtl" ? [...base].reverse() : base;
  }, [page, spread, direction, total]);

  if (!id) return null;

  if (book.isPending) {
    return (
      <div className="fixed inset-0 z-50 flex items-center justify-center bg-black text-white">
        {t("common.loading")}
      </div>
    );
  }

  if (book.isError || !book.data) {
    return (
      <div className="fixed inset-0 z-50 flex flex-col items-center justify-center gap-3 bg-black text-white">
        <p>{t("reader.loadFailed")}</p>
        <Button variant="secondary" onClick={() => navigate(`/books/${id}`)}>
          {t("reader.back")}
        </Button>
      </div>
    );
  }

  if (book.data.file_format === "epub") {
    return (
      <div className="fixed inset-0 z-50 flex flex-col items-center justify-center gap-3 bg-black text-white">
        <BookOpen className="size-12 opacity-50" aria-hidden />
        <p>{t("reader.unsupportedFormat")}</p>
        <Button variant="secondary" onClick={() => navigate(`/books/${id}`)}>
          {t("reader.back")}
        </Button>
      </div>
    );
  }

  return (
    <div className="fixed inset-0 z-50 flex flex-col bg-black text-white">
      <header className="z-10 flex items-center gap-2 border-b border-white/10 bg-black/80 px-3 py-2 backdrop-blur">
        <Button
          variant="ghost"
          size="icon"
          aria-label={t("reader.back")}
          onClick={() => navigate(`/books/${id}`)}
          className="text-white hover:bg-white/10 hover:text-white"
        >
          <ArrowLeft className="size-5" />
        </Button>
        <h1 className="line-clamp-1 min-w-0 flex-1 text-sm font-medium">
          {book.data.title}
        </h1>
        <span className="px-2 text-xs tabular-nums text-white/70">
          {t("reader.pageIndicator", { current: page + 1, total })}
        </span>
        <Button
          variant="ghost"
          size="icon"
          aria-label={t("reader.settings")}
          onClick={() => setSettingsOpen(true)}
          className="text-white hover:bg-white/10 hover:text-white"
        >
          <SettingsIcon className="size-5" />
        </Button>
      </header>

      <div
        role="presentation"
        onClick={handleViewportClick}
        className="relative flex flex-1 cursor-pointer select-none items-center justify-center overflow-hidden"
      >
        {visiblePages.length === 0 ? (
          <p className="text-white/60">{t("reader.loadFailed")}</p>
        ) : (
          <div className="flex h-full w-full items-center justify-center gap-1 px-2">
            {visiblePages.map((p) => (
              <img
                key={p}
                src={`/api/books/${id}/pages/${p}`}
                alt={t("reader.pageIndicator", { current: p + 1, total })}
                className="max-h-full max-w-full object-contain"
                draggable={false}
              />
            ))}
          </div>
        )}
      </div>

      <Sheet open={settingsOpen} onOpenChange={setSettingsOpen}>
        <SheetContent side="right" className="w-80 sm:w-96">
          <SheetHeader>
            <SheetTitle>{t("reader.settings")}</SheetTitle>
            <SheetDescription>{t("reader.settingsDescription")}</SheetDescription>
          </SheetHeader>
          <div className="grid gap-6 px-4 pb-4">
            <div className="flex items-center justify-between gap-3">
              <Label htmlFor="reader-spread">{t("reader.spread")}</Label>
              <Toggle
                id="reader-spread"
                pressed={spread}
                onPressedChange={handleSpreadChange}
                variant="outline"
                size="sm"
                aria-label={t("reader.spread")}
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
                  if (v === "ltr" || v === "rtl") handleDirectionChange(v);
                }}
                variant="outline"
                className="justify-start"
              >
                <ToggleGroupItem value="ltr" aria-label={t("reader.directionLtr")}>
                  {t("reader.directionLtr")}
                </ToggleGroupItem>
                <ToggleGroupItem value="rtl" aria-label={t("reader.directionRtl")}>
                  {t("reader.directionRtl")}
                </ToggleGroupItem>
              </ToggleGroup>
            </div>
          </div>
        </SheetContent>
      </Sheet>
    </div>
  );
}
