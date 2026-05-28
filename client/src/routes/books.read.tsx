import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { useNavigate, useNavigationType, useParams } from "react-router-dom";
import { useTranslation } from "react-i18next";
import {
  ArrowLeft,
  Keyboard,
  Maximize,
  Minimize,
  Settings as SettingsIcon,
} from "lucide-react";
import { EpubReaderView } from "@/components/reader/EpubReaderView";
import { ReaderHotkeysDialog } from "@/components/reader/ReaderHotkeysDialog";
import { ReaderScrubber } from "@/components/reader/ReaderScrubber";
import {
  ReaderOptionField,
  ReaderSpreadField,
} from "@/components/reader/ReaderSettingsFields";
import { Button } from "@/components/ui/button";
import { useFullscreen } from "@/hooks/useFullscreen";
import { useReaderKeyboard } from "@/hooks/useReaderKeyboard";
import { cn } from "@/lib/utils";
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
  SheetDescription,
} from "@/components/ui/sheet";
import { useBook } from "@/hooks/useBooks";
import { useUpdateReadingProgress } from "@/hooks/useReadingProgress";
import { useResolvedReaderSettings } from "@/hooks/useResolvedReaderSettings";
import {
  useUpdateUserPreferences,
  useUserPreferences,
} from "@/hooks/useUserPreferences";
import {
  READER_PRELOAD_AHEAD_DEFAULT,
  READER_PROGRESS_DEBOUNCE_MS,
  READER_SCALE_VALUES,
} from "@/types/api";
import type { ReaderScale, ReaderSettings } from "@/types/api";

export default function ReaderPage() {
  const { t } = useTranslation();
  const { id } = useParams();
  const navigate = useNavigate();
  // Pop the entry that brought us here so a deep stack
  // (list → detail → reader) collapses back to the list when the user
  // taps back twice. Falls back to the detail page on a deep link.
  const navType = useNavigationType();
  const goBack = useCallback(() => {
    if (navType === "PUSH" || navType === "REPLACE") {
      navigate(-1);
    } else {
      navigate(`/books/${id}`, { replace: true });
    }
  }, [navType, navigate, id]);
  const book = useBook(id);
  const resolved = useResolvedReaderSettings(id);
  const update = useUpdateReadingProgress(id ?? "");
  const preferences = useUserPreferences();
  const updatePreferences = useUpdateUserPreferences();

  const [page, setPage] = useState(0);
  const [spread, setSpread] = useState(false);
  const [direction, setDirection] = useState<"ltr" | "rtl">("ltr");
  const [scale, setScale] = useState<ReaderScale>("fit");
  const [settingsOpen, setSettingsOpen] = useState(false);
  const [hotkeysOpen, setHotkeysOpen] = useState(false);
  const [initialized, setInitialized] = useState(false);
  const readerContainerRef = useRef<HTMLDivElement | null>(null);
  const { isFullscreen, toggle: toggleFullscreen, exit: exitFullscreen } =
    useFullscreen(readerContainerRef);

  // Restore once useResolvedReaderSettings reports both queries have
  // settled (see that hook for the merge / settled-gate rationale). Done
  // during render (not in an effect) so the restored values land in the
  // same commit, before the reader is allowed to paint (gated on
  // `initialized` below) — otherwise page 0 flashes briefly before
  // jumping to the saved page.
  if (!initialized && resolved.ready) {
    setPage(resolved.currentPage);
    setSpread(resolved.settings.spread ?? false);
    setDirection(resolved.settings.direction ?? "ltr");
    setScale(resolved.settings.scale ?? "fit");
    setInitialized(true);
  }

  const total = book.data?.page_count ?? 0;
  const step = spread ? 2 : 1;
  const lastPage = Math.max(0, total - 1);

  const goNext = useCallback(() => {
    setPage((p) => Math.min(p + step, lastPage));
  }, [step, lastPage]);

  const goPrev = useCallback(() => {
    setPage((p) => Math.max(p - step, 0));
  }, [step]);

  // Single-page nudges (Shift+Arrow). Useful in spread mode when the
  // pages are offset by one and the reader needs to re-pair them.
  const goNextOne = useCallback(() => {
    setPage((p) => Math.min(p + 1, lastPage));
  }, [lastPage]);

  const goPrevOne = useCallback(() => {
    setPage((p) => Math.max(p - 1, 0));
  }, []);

  // Debounced progress save (only after we've restored, so we don't clobber
  // the saved value with the initial 0).
  const debounceRef = useRef<number | null>(null);
  useEffect(() => {
    if (!initialized || !id) return;
    if (debounceRef.current) window.clearTimeout(debounceRef.current);
    debounceRef.current = window.setTimeout(() => {
      update.mutate({ current_page: page });
    }, READER_PROGRESS_DEBOUNCE_MS);
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

  const toggleHotkeys = useCallback(() => setHotkeysOpen((v) => !v), []);
  const toggleSpread = useCallback(() => {
    setSpread((prev) => {
      const next = !prev;
      saveSettings({ spread: next, direction, scale });
      return next;
    });
  }, [saveSettings, direction, scale]);
  // In fullscreen, the browser's own Esc handler exits fullscreen already
  // (apiFullscreen path) but pseudo-fullscreen needs us to clear it
  // explicitly. Either way, don't navigate away on the same Esc press.
  const handleEscape = useCallback(() => {
    if (isFullscreen) exitFullscreen();
    else goBack();
  }, [isFullscreen, exitFullscreen, goBack]);

  useReaderKeyboard({
    direction,
    paused: settingsOpen || hotkeysOpen,
    onNext: goNext,
    onPrev: goPrev,
    onNextSingle: goNextOne,
    onPrevSingle: goPrevOne,
    onToggleSpread: toggleSpread,
    onToggleHotkeys: toggleHotkeys,
    onToggleFullscreen: toggleFullscreen,
    onEscape: handleEscape,
  });

  // LTR: left half = prev / right half = next. RTL inverts.
  const onLeftHalfClick = direction === "ltr" ? goPrev : goNext;
  const onRightHalfClick = direction === "ltr" ? goNext : goPrev;

  const visiblePages = useMemo(() => {
    if (total === 0) return [];
    const base = spread ? [page, page + 1].filter((p) => p < total) : [page];
    return direction === "rtl" ? [...base].reverse() : base;
  }, [page, spread, direction, total]);

  // Pages to preload into the browser cache so the next page-turn
  // doesn't re-download. We always look 1 page behind and N pages
  // ahead, where N is the user preference (default 4).
  const preloadPages = useMemo(() => {
    if (total === 0) return [];
    const ahead =
      preferences.data?.reader_defaults.preload_ahead ?? READER_PRELOAD_AHEAD_DEFAULT;
    const startAhead = spread ? 2 : 1;
    const visible = new Set(visiblePages);
    const ids = new Set<number>();
    const prev = page - 1;
    if (prev >= 0 && !visible.has(prev)) ids.add(prev);
    for (let i = 0; i < ahead; i++) {
      const p = page + startAhead + i;
      if (p >= total) break;
      if (!visible.has(p)) ids.add(p);
    }
    return [...ids];
  }, [page, spread, total, visiblePages, preferences.data]);

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
        <Button variant="secondary" onClick={goBack}>
          {t("reader.back")}
        </Button>
      </div>
    );
  }

  if (book.data.file_format === "epub") {
    return <EpubReaderView book={book.data} />;
  }

  // Hold the image/CBZ/PDF reader on the loading screen until progress has
  // been restored, so the saved page is the first thing painted instead of
  // page 0 flashing before the jump.
  if (!initialized) {
    return (
      <div className="fixed inset-0 z-50 flex items-center justify-center bg-black text-white">
        {t("common.loading")}
      </div>
    );
  }

  return (
    <div
      ref={readerContainerRef}
      className="fixed inset-0 z-50 flex flex-col bg-black text-white"
    >
      <header
        className={cn(
          "z-10 flex items-center gap-2 border-b border-white/10 bg-black/80 px-3 py-2 backdrop-blur",
          isFullscreen && "hidden",
        )}
      >
        <Button
          variant="ghost"
          size="icon"
          aria-label={t("reader.back")}
          onClick={goBack}
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
          aria-label={t("reader.fullscreen.enter")}
          onClick={toggleFullscreen}
          className="text-white hover:bg-white/10 hover:text-white"
        >
          <Maximize className="size-5" />
        </Button>
        <Button
          variant="ghost"
          size="icon"
          aria-label={t("reader.hotkeys.open")}
          onClick={() => setHotkeysOpen(true)}
          className="text-white hover:bg-white/10 hover:text-white"
        >
          <Keyboard className="size-5" />
        </Button>
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

      {isFullscreen ? (
        <Button
          variant="ghost"
          size="icon"
          aria-label={t("reader.fullscreen.exit")}
          onClick={toggleFullscreen}
          // The pill sits above the page area and outside any click-to-page
          // zone so a thumb-tap to exit never doubles as a page advance.
          // pt-[env(safe-area-inset-top)] / pr-[env(safe-area-inset-right)]
          // honors notches on mobile.
          className="fixed right-2 top-2 z-40 size-10 rounded-full bg-black/40 text-white opacity-60 backdrop-blur transition-opacity hover:bg-black/60 hover:opacity-100 focus-visible:opacity-100"
          style={{
            top: "max(0.5rem, env(safe-area-inset-top))",
            right: "max(0.5rem, env(safe-area-inset-right))",
          }}
        >
          <Minimize className="size-5" />
        </Button>
      ) : null}

      <div
        role="presentation"
        className="relative flex flex-1 select-none items-center justify-center overflow-hidden"
      >
        {visiblePages.length === 0 ? (
          <p className="text-white/60">{t("reader.loadFailed")}</p>
        ) : (
          <div className={viewportClass}>
            {visiblePages.map((p, slot) => (
              // Slot-based key keeps the same <img> element across page
              // turns so the browser holds onto the previous image until
              // the new src has decoded — that's the main trick that
              // eliminates the blank-frame flicker.
              <img
                key={`slot-${slot}`}
                src={`/api/books/${id}/pages/${p}`}
                alt={t("reader.pageIndicator", { current: p + 1, total })}
                className={imageClass}
                draggable={false}
                decoding="async"
                fetchPriority="high"
              />
            ))}
          </div>
        )}
        {/* Click hot-zones — limited to the outer ~12% margins on each
            side, leaving the middle of the page free for a future
            zoom / context-menu / overlay UI. RTL inverts the mapping
            (see onLeftHalfClick / onRightHalfClick above). */}
        <button
          type="button"
          aria-label={t("reader.pager.prev")}
          onClick={onLeftHalfClick}
          className="absolute inset-y-0 left-0 z-10 w-[12%] cursor-pointer bg-transparent transition-colors duration-150 hover:bg-white/10 focus-visible:bg-white/10 focus:outline-none"
        />
        <button
          type="button"
          aria-label={t("reader.pager.next")}
          onClick={onRightHalfClick}
          className="absolute inset-y-0 right-0 z-10 w-[12%] cursor-pointer bg-transparent transition-colors duration-150 hover:bg-white/10 focus-visible:bg-white/10 focus:outline-none"
        />

        {/* Hidden preload pool — keeps the next few pages (and the page
            we just left) warm in the browser cache so navigation feels
            instant. position:absolute + size 0 keeps it out of layout
            without `display:none` (which can suppress some fetches). */}
        <div
          aria-hidden
          className="pointer-events-none absolute size-0 overflow-hidden opacity-0"
        >
          {preloadPages.map((p) => (
            <img
              key={p}
              src={`/api/books/${id}/pages/${p}`}
              alt=""
              decoding="async"
              fetchPriority="low"
            />
          ))}
        </div>

        {total > 1 && id ? (
          <ReaderScrubber
            value={page}
            min={0}
            max={Math.max(0, total - 1)}
            // Always advance by one page on the slider, even when spread
            // is on — otherwise the user can never land on an "odd"
            // page to re-pair an offset spread.
            step={1}
            direction={direction}
            onSeek={(n) => setPage(n)}
            renderPreview={(p) => (
              <img
                src={`/api/books/${id}/pages/${p}`}
                alt=""
                loading="lazy"
                decoding="async"
                className="h-32 w-auto max-w-[40vw] rounded border border-white/20 bg-black object-contain shadow-lg"
              />
            )}
            formatLabel={(p) =>
              t("reader.pager.status", { page: p + 1, pages: total })
            }
            ariaLabel={t("reader.scrubber.ariaLabel")}
          />
        ) : null}
      </div>

      <Sheet open={settingsOpen} onOpenChange={setSettingsOpen}>
        <SheetContent side="right" className="w-80 sm:w-96">
          <SheetHeader>
            <SheetTitle>{t("reader.settings")}</SheetTitle>
            <SheetDescription>{t("reader.settingsDescription")}</SheetDescription>
          </SheetHeader>
          <div className="grid gap-6 px-4 pb-4">
            <ReaderSpreadField
              id="reader-spread"
              label={t("reader.spread")}
              value={spread}
              onChange={handleSpreadChange}
              onLabel={t("reader.on")}
              offLabel={t("reader.off")}
            />
            <ReaderOptionField
              label={t("reader.direction")}
              value={direction}
              options={["ltr", "rtl"] as const}
              optionLabel={(v) =>
                v === "ltr" ? t("reader.directionLtr") : t("reader.directionRtl")
              }
              onChange={handleDirectionChange}
              wrap={false}
            />
            <ReaderOptionField
              label={t("reader.scale")}
              value={scale}
              options={READER_SCALE_VALUES}
              optionLabel={(v) => t(`reader.scaleMode.${v}`)}
              onChange={handleScaleChange}
            />
            <div className="grid gap-2 pt-2">
              <Button
                type="button"
                variant="outline"
                size="sm"
                onClick={() =>
                  updatePreferences.mutate({
                    reader_defaults: { spread, direction, scale },
                  })
                }
                disabled={updatePreferences.isPending}
              >
                {updatePreferences.isPending
                  ? t("common.saving")
                  : t("reader.saveAsDefaults")}
              </Button>
              <p className="text-xs text-muted-foreground">
                {t("reader.saveAsDefaultsHint")}
              </p>
            </div>
          </div>
        </SheetContent>
      </Sheet>

      <ReaderHotkeysDialog
        open={hotkeysOpen}
        onOpenChange={setHotkeysOpen}
        showSinglePageNudge
      />
    </div>
  );
}
