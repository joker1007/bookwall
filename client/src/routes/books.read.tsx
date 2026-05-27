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
import type { ReaderScale, ReaderSettings } from "@/types/api";

const SCALE_VALUES = ["fit", "fit_height", "fit_width", "original"] as const;

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
  const [scale, setScale] = useState<ReaderScale>("fit");
  const [settingsOpen, setSettingsOpen] = useState(false);
  const [initialized, setInitialized] = useState(false);

  // Restore once the progress fetch resolves
  useEffect(() => {
    if (initialized || !progress.data) return;
    setPage(progress.data.current_page);
    setSpread(progress.data.settings.spread ?? false);
    setDirection(progress.data.settings.direction ?? "ltr");
    setScale(progress.data.settings.scale ?? "fit");
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
    saveSettings({ spread: value, direction, scale });
  };
  const handleDirectionChange = (value: "ltr" | "rtl") => {
    setDirection(value);
    saveSettings({ spread, direction: value, scale });
  };
  const handleScaleChange = (value: ReaderScale) => {
    setScale(value);
    saveSettings({ spread, direction, scale: value });
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

  // Tailwind classes per scale mode. Spread layouts apply the same scale to
  // the **pair** of pages as a single unit — `fit` shrinks both side-by-side
  // until either edge hits the viewport; `fit_width` splits the viewport
  // width 50/50 between the two pages; etc.
  const viewportClass = useMemo(() => {
    // No gap between pages: in spread mode the two pages must butt up
    // against each other so they read as a single canvas.
    const base = "flex px-2";
    switch (scale) {
      case "fit":
        return `${base} h-full w-full items-center justify-center`;
      case "fit_height":
        return `${base} h-full w-full items-center justify-center overflow-x-auto`;
      case "fit_width":
        return `${base} min-h-full w-full items-start justify-center overflow-y-auto`;
      case "original":
        return `${base} min-h-full min-w-full items-start justify-center overflow-auto`;
    }
  }, [scale]);

  const imageClass = useMemo(() => {
    switch (scale) {
      case "fit":
        // `h-full w-auto` makes the <img> element take its width from its
        // natural aspect ratio (so no horizontal gap is rendered around
        // the image itself), while still scaling up to fill the height.
        // `max-w-[50%]` in spread mode prevents either page from spilling
        // past the viewport's midline so the two halves meet flush.
        return spread
          ? "h-full w-auto max-w-[50%] object-contain"
          : "h-full w-auto max-w-full object-contain";
      case "fit_height":
        return "h-full max-w-none w-auto";
      case "fit_width":
        // Spread: each page gets half the viewport width so the pair lines
        // up flush. Single: full viewport width.
        return spread ? "w-1/2 max-h-none h-auto" : "w-full max-h-none h-auto";
      case "original":
        return "max-w-none max-h-none";
    }
  }, [scale, spread]);

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
          <div className={viewportClass}>
            {visiblePages.map((p) => (
              <img
                key={p}
                src={`/api/books/${id}/pages/${p}`}
                alt={t("reader.pageIndicator", { current: p + 1, total })}
                className={imageClass}
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
            <div className="grid gap-2">
              <Label>{t("reader.scale")}</Label>
              <ToggleGroup
                type="single"
                value={scale}
                onValueChange={(v) => {
                  if (SCALE_VALUES.includes(v as ReaderScale)) {
                    handleScaleChange(v as ReaderScale);
                  }
                }}
                variant="outline"
                className="flex-wrap justify-start"
              >
                {SCALE_VALUES.map((value) => (
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
          </div>
        </SheetContent>
      </Sheet>
    </div>
  );
}
