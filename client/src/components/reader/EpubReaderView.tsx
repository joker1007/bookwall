import {
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
} from "react";
import { useNavigate, useNavigationType } from "react-router-dom";
import { useTranslation } from "react-i18next";
import {
  ArrowLeft,
  Keyboard,
  ListTree,
  Maximize,
  Minimize,
  Settings as SettingsIcon,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetHeader,
  SheetTitle,
} from "@/components/ui/sheet";
import { ReaderHotkeysDialog } from "@/components/reader/ReaderHotkeysDialog";
import { ReaderScrubber } from "@/components/reader/ReaderScrubber";
import {
  ReaderFontSizeField,
  ReaderOptionField,
} from "@/components/reader/ReaderSettingsFields";
import { useFullscreen } from "@/hooks/useFullscreen";
import { useReaderKeyboard } from "@/hooks/useReaderKeyboard";
import { cn } from "@/lib/utils";
import {
  useReadingProgress,
  useUpdateReadingProgress,
} from "@/hooks/useReadingProgress";
import {
  useUserPreferences,
  useUpdateUserPreferences,
} from "@/hooks/useUserPreferences";
import {
  READER_FONT_SIZE_DEFAULT,
  READER_FONT_SIZE_MAX,
  READER_FONT_SIZE_MIN,
  READER_PROGRESS_DEBOUNCE_MS,
  READER_THEME_VALUES,
  READER_WRITING_MODE_VALUES,
} from "@/types/api";
import type {
  Book,
  ReaderSettings,
  ReaderTheme,
  ReaderWritingMode,
} from "@/types/api";

// Minimal slice of foliate-js's <foliate-view> custom element that we
// actually call. The library doesn't ship TS types, so we declare the
// surface we use ourselves.
interface FoliateView extends HTMLElement {
  open(file: Blob): Promise<void>;
  init(opts: { lastLocation?: string; showTextStart?: boolean }): Promise<void>;
  close(): void;
  next(): Promise<void>;
  prev(): Promise<void>;
  goTo(target: string | number): Promise<void>;
  goLeft(): Promise<void>;
  goRight(): Promise<void>;
  goToFraction(fraction: number): Promise<void>;
  renderer: HTMLElement & {
    setStyles?: (css: string | string[]) => void;
  };
  book?: {
    toc?: TocItem[];
    // OPF's `<spine page-progression-direction>` — "rtl" for most
    // vertically-typeset Japanese books.
    dir?: string;
    sections?: unknown[];
  };
}

export interface TocItem {
  label: string;
  href: string;
  subitems?: TocItem[];
}

interface EpubReaderViewProps {
  book: Book;
}

// Flatten a TOC tree into a list, preserving the original order so we
// can pick the entry whose section index is closest to (but not past)
// a given section. foliate-js doesn't expose section index → TOC
// directly, so this is a best-effort lookup for the scrubber preview.
function flattenToc(items: TocItem[]): TocItem[] {
  const out: TocItem[] = [];
  const walk = (list: TocItem[]) => {
    for (const item of list) {
      out.push(item);
      if (item.subitems?.length) walk(item.subitems);
    }
  };
  walk(items);
  return out;
}

function themeCss(theme: ReaderTheme): string {
  switch (theme) {
    case "dark":
      return `
        html, body {
          background: #1a1a1a !important;
          color: #e0e0e0 !important;
        }
        a { color: #79b8ff !important; }
      `;
    case "sepia":
      return `
        html, body {
          background: #f4ecd8 !important;
          color: #5b4636 !important;
        }
        a { color: #8b5e3c !important; }
      `;
    default:
      return `
        html, body {
          background: #ffffff !important;
          color: #1a1a1a !important;
        }
      `;
  }
}

function buildBookStyles({
  fontSize,
  theme,
  writingMode,
}: {
  fontSize: number;
  theme: ReaderTheme;
  writingMode: ReaderWritingMode;
}): string {
  // "auto" → don't touch writing-mode so the book's own CSS wins.
  // "horizontal" / "vertical" → force-override with !important.
  const writing =
    writingMode === "vertical"
      ? `html, body { writing-mode: vertical-rl !important; }`
      : writingMode === "horizontal"
        ? `html, body { writing-mode: horizontal-tb !important; }`
        : "";
  return [
    themeCss(theme),
    `html, body { font-size: ${fontSize}% !important; }`,
    writing,
  ]
    .filter(Boolean)
    .join("\n");
}

export function EpubReaderView({ book }: EpubReaderViewProps) {
  const { t } = useTranslation();
  const navigate = useNavigate();
  // Pop the history entry that brought us here so the user lands back
  // on whatever list / search page opened the detail page in the
  // first place. Falls back to the detail page itself on a deep-link
  // entry where there's no in-app history to pop.
  const navType = useNavigationType();
  const goBack = useCallback(() => {
    if (navType === "PUSH" || navType === "REPLACE") {
      navigate(-1);
    } else {
      navigate(`/books/${book.id}`, { replace: true });
    }
  }, [navType, navigate, book.id]);
  const progress = useReadingProgress(book.id);
  const update = useUpdateReadingProgress(book.id);
  const preferences = useUserPreferences();
  const updatePreferences = useUpdateUserPreferences();

  const containerRef = useRef<HTMLDivElement | null>(null);
  const viewRef = useRef<FoliateView | null>(null);

  const [loadStatus, setLoadStatus] = useState<"loading" | "ready" | "error">(
    "loading",
  );
  const [settingsOpen, setSettingsOpen] = useState(false);
  const [tocOpen, setTocOpen] = useState(false);
  const [hotkeysOpen, setHotkeysOpen] = useState(false);
  const readerContainerRef = useRef<HTMLDivElement | null>(null);
  const { isFullscreen, toggle: toggleFullscreen, exit: exitFullscreen } =
    useFullscreen(readerContainerRef);
  const [toc, setToc] = useState<TocItem[]>([]);
  // foliate-js's relocate event exposes a `fraction` (0..1) for the
  // current position. We stash it so the bottom scrubber can show
  // progress and seek via view.goToFraction.
  const [fraction, setFraction] = useState(0);
  const [sectionTotal, setSectionTotal] = useState(0);

  // Resolved settings (per-book ReadingProgress.settings beats user defaults
  // beats hard-coded defaults).
  const resolvedSettings = useMemo(() => {
    const defaults = preferences.data?.reader_defaults ?? {};
    const persisted = progress.data?.settings ?? {};
    const neverRead = progress.data?.last_read_at === null;
    const source: ReaderSettings = neverRead ? defaults : { ...defaults, ...persisted };
    return {
      fontSize: source.font_size ?? READER_FONT_SIZE_DEFAULT,
      theme: (source.theme ?? "light") as ReaderTheme,
      writingMode: (source.writing_mode ?? "auto") as ReaderWritingMode,
    };
  }, [preferences.data, progress.data]);

  const [fontSize, setFontSize] = useState<number>(READER_FONT_SIZE_DEFAULT);
  const [theme, setTheme] = useState<ReaderTheme>("light");
  const [writingMode, setWritingMode] = useState<ReaderWritingMode>("auto");
  // Set once we can answer "is this book vertical?" — driven by
  // view.book.dir at open and the iframe's computed writing-mode on
  // load. Stays "horizontal" if we never spot a vertical signal.
  const [detectedWritingMode, setDetectedWritingMode] = useState<
    "horizontal" | "vertical"
  >("horizontal");
  const detectedVerticalRef = useRef(false);
  const [hydrated, setHydrated] = useState(false);

  // Hydrate UI state from server once on first response.
  useEffect(() => {
    if (hydrated) return;
    if (!preferences.data || !progress.data) return;
    setFontSize(resolvedSettings.fontSize);
    setTheme(resolvedSettings.theme);
    setWritingMode(resolvedSettings.writingMode);
    setHydrated(true);
  }, [preferences.data, progress.data, resolvedSettings, hydrated]);

  // Mount <foliate-view> and stream the book in. We wait for the
  // progress query to settle before kicking foliate off — otherwise
  // `progress.data` is still undefined when `view.init({ lastLocation })`
  // runs, and the user's saved CFI never gets restored.
  useEffect(() => {
    if (progress.isPending) return;
    let cancelled = false;
    let view: FoliateView | null = null;

    (async () => {
      try {
        await import("foliate-js/view.js");
        if (cancelled || !containerRef.current) return;

        view = document.createElement("foliate-view") as FoliateView;
        view.style.width = "100%";
        view.style.height = "100%";
        containerRef.current.append(view);
        viewRef.current = view;

        view.addEventListener("relocate", (e: Event) => {
          const detail = (e as CustomEvent<{
            cfi?: string;
            fraction?: number;
            index?: number;
          }>).detail;
          const clampedFraction = typeof detail?.fraction === "number"
            ? Math.max(0, Math.min(1, detail.fraction))
            : undefined;
          if (typeof clampedFraction === "number") {
            setFraction(clampedFraction);
          }
          if (detail?.cfi) saveLocation(detail.cfi, clampedFraction);
        });

        // Sniff the iframe's computed writing-mode the first time we see
        // a vertical section — some EPUBs have a horizontal cover page
        // followed by vertical body sections, so we wait for "first
        // vertical signal" rather than "first section". The actual user
        // stylesheet (font_size / theme / writing_mode) is applied via
        // foliate's renderer.setStyles in a separate effect — that route
        // is the one foliate's own re-flow path observes, so it survives
        // settings changes against already-rendered sections.
        view.addEventListener("load", (e: Event) => {
          if (!detectedVerticalRef.current) {
            const detail = (e as CustomEvent<{ doc: Document }>).detail;
            try {
              const win = detail.doc.defaultView;
              if (win) {
                const html = win.getComputedStyle(detail.doc.documentElement).writingMode;
                const body = win.getComputedStyle(detail.doc.body).writingMode;
                if (html?.startsWith("vertical") || body?.startsWith("vertical")) {
                  detectedVerticalRef.current = true;
                  setDetectedWritingMode("vertical");
                }
              }
            } catch {
              // sandboxed iframes can throw on cross-origin style access
            }
          }
        });

        const res = await fetch(`/api/books/${book.id}/file`, {
          credentials: "include",
        });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const blob = await res.blob();
        if (cancelled || !view) return;

        // foliate-js inspects `file.name` (string#endsWith) to pick the
        // right format adapter, so a bare Blob (which has no `name`)
        // makes it crash. Wrap with a File and supply an extension that
        // matches the book's actual format.
        const filename = `book.${book.file_format === "image_dir" ? "epub" : book.file_format}`;
        const file = new File([blob], filename, {
          type: blob.type || "application/epub+zip",
        });
        await view.open(file);
        if (cancelled || !view) return;

        // Static signal for "is this a vertically-typeset book?": OPF's
        // `<spine page-progression-direction>` lands on view.book.dir.
        // RTL page progression is the canonical marker for Japanese
        // vertical EPUBs (and is also the marker we need anyway to flip
        // ArrowLeft/Right). The iframe computed-style sniff in the load
        // listener is a fallback for books that omit the OPF attribute.
        if (view.book?.dir === "rtl") {
          detectedVerticalRef.current = true;
          setDetectedWritingMode("vertical");
        }

        // foliate-js's paginator defaults to a narrow column (~720px max
        // inline-size + sizable margins) which leaves a lot of empty
        // space on a typical desktop viewport. Let the content stretch
        // to the actual viewport with only a small margin so the reader
        // looks comfortable on both desktop and mobile.
        //
        // max-column-count switches between 1 (phones) and 2 (tablet+
        // desktop) — a phone-width split into two columns shrinks each
        // line so far that single Japanese characters break across
        // columns, which is unreadable. The matching effect below keeps
        // the attribute in sync on rotation / window resize.
        const renderer = view.renderer;
        renderer?.setAttribute?.("max-inline-size", "100%");
        renderer?.setAttribute?.("max-block-size", "100%");
        renderer?.setAttribute?.(
          "max-column-count",
          window.matchMedia("(min-width: 768px)").matches ? "2" : "1",
        );
        renderer?.setAttribute?.("margin", "16px");
        renderer?.setAttribute?.("gap", "5%");

        // Seed renderer.setStyles with the resolved user stylesheet
        // BEFORE init() so the first section load picks it up — foliate
        // caches the last call to setStyles and replays it on every
        // section transition via its `onLoad` hook. Without this seed,
        // sections load with no font_size / theme applied until the
        // useEffect below catches up, producing a visible re-flow.
        renderer?.setStyles?.(
          buildBookStyles({
            fontSize: resolvedSettings.fontSize,
            theme: resolvedSettings.theme,
            writingMode: resolvedSettings.writingMode,
          }),
        );

        // foliate-js doesn't render the first section until we navigate
        // to it explicitly. If we have a saved CFI, init({ lastLocation })
        // takes us there. With no CFI, init({ showTextStart: true })
        // tries to honour the EPUB's "text-start" landmark — but plenty
        // of books don't expose one, in which case the viewport stays
        // blank until the user manually pages forward. Skip the landmark
        // dance and just `goTo(0)` for a fresh open.
        const cfi = progress.data?.epub_cfi ?? undefined;
        try {
          if (cfi) {
            await view.init({ lastLocation: cfi });
          } else {
            await view.goTo(0);
          }
        } catch (initError) {
          console.warn(
            "[EpubReaderView] init failed, falling back to first section",
            initError,
          );
          try {
            await view.goTo(0);
          } catch {
            // ignore — error UI will surface if the book itself failed
          }
        }

        // Capture the TOC for the sidebar.
        const bookToc = view.book?.toc;
        if (bookToc) setToc(bookToc);
        const sections = view.book?.sections;
        if (Array.isArray(sections)) setSectionTotal(sections.length);

        // The "settings change" effect below picks up loadStatus === "ready"
        // and applies the current font_size / theme / writing_mode to the
        // renderer + any already-loaded iframes, so we don't need to call
        // it explicitly here.
        setLoadStatus("ready");
      } catch (err) {
        console.error("[EpubReaderView] failed to load book", err);
        if (!cancelled) setLoadStatus("error");
      }
    })();

    return () => {
      cancelled = true;
      try {
        view?.close?.();
      } catch {
        // ignore
      }
      view?.remove?.();
      viewRef.current = null;
    };
    // book.id intentionally captures the current book — re-mounting on
    // book change is fine. progress.isPending lets the effect bail out
    // until the saved CFI is in hand, then re-run once it lands.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [book.id, progress.isPending]);

  // Debounced position save. CFI restores the exact reading point on
  // re-open; progress_fraction powers the cover progress bar across the
  // library views.
  const locationDebounce = useRef<number | null>(null);
  const saveLocation = useCallback(
    (cfi: string, fraction: number | undefined) => {
      if (locationDebounce.current) window.clearTimeout(locationDebounce.current);
      locationDebounce.current = window.setTimeout(() => {
        update.mutate({
          epub_cfi: cfi,
          ...(typeof fraction === "number" ? {progress_fraction: fraction} : {}),
        });
      }, READER_PROGRESS_DEBOUNCE_MS);
    },
    [update],
  );

  // Whenever the user changes a setting, push it through foliate's
  // renderer.setStyles, which (a) writes into the high-priority $style
  // slot inside the section iframe, (b) replays the same CSS into every
  // future section the user navigates to, and (c) triggers foliate's
  // internal re-flow (expand + columnize) so font-size changes
  // re-paginate immediately.
  //
  // Earlier this code also walked the iframe tree with `collectIframes`
  // and injected its own <style> as a backup. That walk never actually
  // reached anything — foliate's <foliate-view> and <foliate-paginator>
  // use `attachShadow({ mode: "closed" })`, so `el.shadowRoot` is null
  // and the iframe is unreachable from outside. The leftover stale
  // <style> from the load event also sat at the END of head with
  // `!important` and beat foliate's $style on every settings change,
  // which is why font_size / theme used to refuse to re-apply.
  useEffect(() => {
    if (loadStatus !== "ready") return;
    const renderer = viewRef.current?.renderer;
    const css = buildBookStyles({ fontSize, theme, writingMode });
    renderer?.setStyles?.(css);
  }, [loadStatus, fontSize, theme, writingMode]);

  // Keep the renderer's max-column-count in sync with the viewport.
  // Rotating a phone from portrait to landscape (or resizing the window
  // on desktop) should re-flow between single- and two-column layout
  // without having to reload the reader.
  useEffect(() => {
    if (loadStatus !== "ready") return;
    const mql = window.matchMedia("(min-width: 768px)");
    const apply = () => {
      viewRef.current?.renderer?.setAttribute?.(
        "max-column-count",
        mql.matches ? "2" : "1",
      );
    };
    apply();
    mql.addEventListener("change", apply);
    return () => mql.removeEventListener("change", apply);
  }, [loadStatus]);

  // Save settings (debounced through the same mutation that handles CFI).
  const saveSettings = useCallback(
    (patch: ReaderSettings) => {
      update.mutate({
        settings: {
          font_size: fontSize,
          theme,
          writing_mode: writingMode,
          ...patch,
        },
      });
    },
    [update, fontSize, theme, writingMode],
  );

  const onFontSizeChange = (next: number) => {
    const clamped = Math.max(
      READER_FONT_SIZE_MIN,
      Math.min(READER_FONT_SIZE_MAX, next),
    );
    setFontSize(clamped);
    saveSettings({ font_size: clamped });
  };
  const onThemeChange = (next: ReaderTheme) => {
    setTheme(next);
    saveSettings({ theme: next });
  };
  const onWritingModeChange = (next: ReaderWritingMode) => {
    setWritingMode(next);
    saveSettings({ writing_mode: next });
  };

  // "auto" resolves to whatever we sniffed from the book; explicit
  // horizontal / vertical from the user wins. effectiveDirection
  // governs ArrowLeft/Right flip + tap-zone flip in this reader.
  // (foliate-js itself already flips page-turn direction based on
  // view.book.dir, so we don't need to tell it anything.)
  const effectiveWritingMode = useMemo<"horizontal" | "vertical">(
    () => (writingMode === "auto" ? detectedWritingMode : writingMode),
    [writingMode, detectedWritingMode],
  );
  const effectiveDirection = useMemo<"ltr" | "rtl">(
    () => (effectiveWritingMode === "vertical" ? "rtl" : "ltr"),
    [effectiveWritingMode],
  );

  const goNext = useCallback(() => {
    viewRef.current?.next?.();
  }, []);
  const goPrev = useCallback(() => {
    viewRef.current?.prev?.();
  }, []);

  const toggleHotkeys = useCallback(() => setHotkeysOpen((v) => !v), []);
  // See books.read.tsx for the Esc-in-fullscreen rationale.
  const handleEscape = useCallback(() => {
    if (isFullscreen) exitFullscreen();
    else goBack();
  }, [isFullscreen, exitFullscreen, goBack]);

  useReaderKeyboard({
    direction: effectiveDirection,
    paused: settingsOpen || tocOpen || hotkeysOpen,
    onNext: goNext,
    onPrev: goPrev,
    onToggleHotkeys: toggleHotkeys,
    onToggleFullscreen: toggleFullscreen,
    onEscape: handleEscape,
  });

  // LTR: left half = prev / right half = next. RTL inverts.
  const onLeftHalfClick = effectiveDirection === "ltr" ? goPrev : goNext;
  const onRightHalfClick = effectiveDirection === "ltr" ? goNext : goPrev;

  const goToToc = async (href: string) => {
    setTocOpen(false);
    try {
      await viewRef.current?.goTo(href);
    } catch {
      // ignore
    }
  };

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
          {book.title}
        </h1>
        <Button
          variant="ghost"
          size="icon"
          aria-label={t("reader.toc.title")}
          onClick={() => setTocOpen(true)}
          className="text-white hover:bg-white/10 hover:text-white"
        >
          <ListTree className="size-5" />
        </Button>
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
        className="relative flex-1 select-none overflow-hidden bg-white"
      >
        <div ref={containerRef} className="absolute inset-0" />
        {/* Click hot-zones — limited to the outer ~12% margins on each
            side so the column in the middle stays selectable (text
            copy still works). Direction-aware, so the labels and
            behaviour follow the book's effective writing direction. */}
        <button
          type="button"
          aria-label={t("reader.pager.prev")}
          onClick={onLeftHalfClick}
          className="absolute inset-y-0 left-0 z-10 w-[12%] cursor-pointer bg-transparent transition-colors duration-150 hover:bg-black/[0.06] focus-visible:bg-black/[0.06] focus:outline-none"
        />
        <button
          type="button"
          aria-label={t("reader.pager.next")}
          onClick={onRightHalfClick}
          className="absolute inset-y-0 right-0 z-10 w-[12%] cursor-pointer bg-transparent transition-colors duration-150 hover:bg-black/[0.06] focus-visible:bg-black/[0.06] focus:outline-none"
        />
        {loadStatus === "ready" && sectionTotal > 0 ? (
          <ReaderScrubber
            value={Math.round(fraction * 1000)}
            min={0}
            max={1000}
            step={1}
            direction={effectiveDirection}
            onSeek={(n) => {
              const f = n / 1000;
              setFraction(f);
              try {
                viewRef.current?.goToFraction?.(f);
              } catch {
                // ignore — foliate occasionally rejects out-of-range
              }
            }}
            renderPreview={(n) => {
              const f = n / 1000;
              const idx = Math.min(sectionTotal - 1, Math.floor(f * sectionTotal));
              const flat = flattenToc(toc);
              // Walk the flat TOC backwards looking for the chapter that
              // covers this section. No perfect mapping is possible
              // without rendering, so this is best-effort.
              let label: string | undefined;
              for (let i = Math.min(idx, flat.length - 1); i >= 0; i--) {
                if (flat[i]?.label) {
                  label = flat[i].label;
                  break;
                }
              }
              return (
                <div className="max-w-[40vw] rounded border border-white/20 bg-black/90 px-3 py-2 text-xs text-white shadow-lg">
                  <p className="font-medium">
                    {label ??
                      t("reader.scrubber.epubSection", {
                        current: idx + 1,
                        total: sectionTotal,
                      })}
                  </p>
                  <p className="text-white/60">
                    {t("reader.scrubber.epubPercent", {
                      percent: Math.round(f * 100),
                    })}
                  </p>
                </div>
              );
            }}
            formatLabel={(n) =>
              t("reader.scrubber.epubPercent", {
                percent: Math.round((n / 1000) * 100),
              })
            }
            ariaLabel={t("reader.scrubber.epubAriaLabel")}
          />
        ) : null}
        {loadStatus === "loading" ? (
          <div className="absolute inset-0 z-30 flex items-center justify-center bg-black/80 text-white">
            {t("common.loading")}
          </div>
        ) : null}
        {loadStatus === "error" ? (
          <div className="absolute inset-0 z-30 flex flex-col items-center justify-center gap-3 bg-black/90 text-white">
            <p>{t("reader.loadFailed")}</p>
            <Button variant="secondary" onClick={goBack}>
              {t("reader.back")}
            </Button>
          </div>
        ) : null}
      </div>

      <Sheet open={settingsOpen} onOpenChange={setSettingsOpen}>
        <SheetContent side="right" className="w-80 sm:w-96">
          <SheetHeader>
            <SheetTitle>{t("reader.settings")}</SheetTitle>
            <SheetDescription>{t("reader.settingsDescription")}</SheetDescription>
          </SheetHeader>
          <div className="grid gap-6 px-4 pb-4">
            <ReaderFontSizeField
              label={t("reader.epubFontSize")}
              value={fontSize}
              onChange={onFontSizeChange}
            />
            <ReaderOptionField
              label={t("reader.theme.label")}
              value={theme}
              options={READER_THEME_VALUES}
              optionLabel={(v) => t(`reader.theme.${v}`)}
              onChange={onThemeChange}
            />
            <ReaderOptionField
              label={t("reader.writingMode.label")}
              value={writingMode}
              options={READER_WRITING_MODE_VALUES}
              optionLabel={(v) => t(`reader.writingMode.${v}`)}
              onChange={onWritingModeChange}
              hint={
                writingMode === "auto"
                  ? t("reader.writingMode.autoDetected", {
                      mode: t(`reader.writingMode.${effectiveWritingMode}`),
                    })
                  : undefined
              }
            />
            <div className="grid gap-2 pt-2">
              <Button
                type="button"
                variant="outline"
                size="sm"
                onClick={() =>
                  updatePreferences.mutate({
                    reader_defaults: {
                      font_size: fontSize,
                      theme,
                      writing_mode: writingMode,
                    },
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

      <Sheet open={tocOpen} onOpenChange={setTocOpen}>
        <SheetContent side="left" className="w-80 sm:w-96">
          <SheetHeader>
            <SheetTitle>{t("reader.toc.title")}</SheetTitle>
            <SheetDescription>{t("reader.toc.description")}</SheetDescription>
          </SheetHeader>
          <nav className="overflow-y-auto px-4 pb-4 text-sm">
            {toc.length === 0 ? (
              <p className="text-muted-foreground">{t("reader.toc.empty")}</p>
            ) : (
              <TocList items={toc} onSelect={goToToc} />
            )}
          </nav>
        </SheetContent>
      </Sheet>

      <ReaderHotkeysDialog open={hotkeysOpen} onOpenChange={setHotkeysOpen} />
    </div>
  );
}

function TocList({
  items,
  onSelect,
  depth = 0,
}: {
  items: TocItem[];
  onSelect: (href: string) => void;
  depth?: number;
}) {
  return (
    <ul className="flex flex-col gap-0.5">
      {items.map((item, i) => (
        <li key={`${depth}-${i}`}>
          <button
            type="button"
            onClick={() => onSelect(item.href)}
            className="block w-full rounded px-2 py-1.5 text-left text-sm hover:bg-accent hover:text-accent-foreground"
            style={{ paddingInlineStart: `${depth * 12 + 8}px` }}
          >
            {item.label}
          </button>
          {item.subitems?.length ? (
            <TocList items={item.subitems} onSelect={onSelect} depth={depth + 1} />
          ) : null}
        </li>
      ))}
    </ul>
  );
}
