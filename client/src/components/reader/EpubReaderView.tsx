import {
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
} from "react";
import type { MouseEvent as ReactMouseEvent } from "react";
import { useNavigate, useNavigationType } from "react-router-dom";
import { useTranslation } from "react-i18next";
import { ArrowLeft, ListTree, Settings as SettingsIcon } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetHeader,
  SheetTitle,
} from "@/components/ui/sheet";
import { ToggleGroup, ToggleGroupItem } from "@/components/ui/toggle-group";
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
  READER_FONT_SIZE_STEP,
  READER_THEME_VALUES,
  READER_WRITING_MODE_VALUES,
} from "@/types/api";
import type {
  Book,
  ReaderSettings,
  ReaderTheme,
  ReaderWritingMode,
} from "@/types/api";

const DEBOUNCE_MS = 800;

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
  renderer: HTMLElement & {
    setStyles?: (css: string | string[]) => void;
  };
  book?: {
    toc?: TocItem[];
    // OPF's `<spine page-progression-direction>` — "rtl" for most
    // vertically-typeset Japanese books.
    dir?: string;
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

// foliate-js renders book content inside an iframe that sits inside a
// shadow root (the paginator / scrolled renderer is a custom element).
// Walk the tree, including any open shadow roots, so we can re-apply
// styles to already-mounted sections when settings change.
function collectIframes(
  root: Element | ShadowRoot | null | undefined,
): HTMLIFrameElement[] {
  if (!root) return [];
  const out: HTMLIFrameElement[] = [];
  root.querySelectorAll("iframe").forEach((iframe) => {
    out.push(iframe as HTMLIFrameElement);
  });
  root.querySelectorAll("*").forEach((el) => {
    const sr = (el as HTMLElement).shadowRoot;
    if (sr) out.push(...collectIframes(sr));
  });
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
  const [toc, setToc] = useState<TocItem[]>([]);

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

  // Mount <foliate-view> and stream the book in.
  useEffect(() => {
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
          const detail = (e as CustomEvent<{ cfi: string }>).detail;
          if (detail?.cfi) saveCfi(detail.cfi);
        });

        // Inject per-document styles when each section loads. Routed via
        // a ref so the latest font_size / theme / writing_mode are used,
        // not whatever values were in scope at mount time. We also use
        // this hook to sniff the iframe's computed writing-mode the first
        // time we see a vertical section — some EPUBs have a horizontal
        // cover page followed by vertical body sections, so we wait for
        // "first vertical signal" rather than "first section".
        view.addEventListener("load", (e: Event) => {
          const detail = (e as CustomEvent<{ doc: Document }>).detail;
          applyBookStylesRef.current(detail.doc);
          if (!detectedVerticalRef.current) {
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
        const renderer = view.renderer;
        renderer?.setAttribute?.("max-inline-size", "100%");
        renderer?.setAttribute?.("max-block-size", "100%");
        renderer?.setAttribute?.("max-column-count", "2");
        renderer?.setAttribute?.("margin", "16px");
        renderer?.setAttribute?.("gap", "5%");

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
    // book change is fine.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [book.id]);

  // Debounced CFI save.
  const cfiDebounce = useRef<number | null>(null);
  const saveCfi = useCallback(
    (cfi: string) => {
      if (cfiDebounce.current) window.clearTimeout(cfiDebounce.current);
      cfiDebounce.current = window.setTimeout(() => {
        update.mutate({ epub_cfi: cfi } as unknown as { current_page: number });
      }, DEBOUNCE_MS);
    },
    [update],
  );

  // The "load" event listener on <foliate-view> is registered once at
  // mount time, which would normally capture stale font_size / theme /
  // writing_mode values in a closure. Route the actual style application
  // through a ref so each invocation reads the latest values.
  const applyBookStylesRef = useRef<(doc: Document) => void>(() => {});
  useEffect(() => {
    applyBookStylesRef.current = (doc: Document) => {
      const css = buildBookStyles({ fontSize, theme, writingMode });
      let style = doc.getElementById(
        "__bookwall_reader_style",
      ) as HTMLStyleElement | null;
      if (!style) {
        style = doc.createElement("style");
        style.id = "__bookwall_reader_style";
        doc.head.append(style);
      }
      style.textContent = css;
    };
  }, [fontSize, theme, writingMode]);

  // Whenever the user changes a setting, apply it to the renderer (so
  // foliate-js's outer chrome adopts the theme) AND walk through every
  // iframe that has already been mounted (the load listener will only
  // fire on future section loads). The iframe lives inside the
  // paginator's shadow DOM, so a plain querySelectorAll on our container
  // doesn't reach it — descend into shadow roots manually.
  useEffect(() => {
    if (loadStatus !== "ready") return;
    const renderer = viewRef.current?.renderer;
    const css = buildBookStyles({ fontSize, theme, writingMode });
    renderer?.setStyles?.([css]);

    const iframes = collectIframes(viewRef.current);
    iframes.forEach((iframe) => {
      const doc = iframe.contentDocument;
      if (doc) applyBookStylesRef.current(doc);
    });
  }, [loadStatus, fontSize, theme, writingMode]);

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

  // Keyboard
  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      if (settingsOpen || tocOpen) return;
      const target = e.target as HTMLElement | null;
      if (target?.tagName === "INPUT" || target?.tagName === "TEXTAREA") return;

      // ArrowLeft/Right flip on RTL (vertical Japanese); Space/Backspace
      // stay direction-agnostic — they're "forward" / "back" by convention,
      // matching every other reader app.
      if (e.key === "ArrowRight") {
        e.preventDefault();
        (effectiveDirection === "rtl" ? goPrev : goNext)();
      } else if (e.key === "ArrowLeft") {
        e.preventDefault();
        (effectiveDirection === "rtl" ? goNext : goPrev)();
      } else if (e.key === " " || e.code === "Space") {
        e.preventDefault();
        goNext();
      } else if (e.key === "Backspace") {
        e.preventDefault();
        goPrev();
      } else if (e.key === "Escape") {
        e.preventDefault();
        goBack();
      }
    };
    window.addEventListener("keydown", handler);
    return () => window.removeEventListener("keydown", handler);
  }, [goNext, goPrev, goBack, settingsOpen, tocOpen, effectiveDirection]);

  const handleViewportClick = (e: ReactMouseEvent<HTMLDivElement>) => {
    const rect = e.currentTarget.getBoundingClientRect();
    const isLeftHalf = e.clientX - rect.left < rect.width / 2;
    // LTR: left half = prev / right half = next; RTL inverts.
    const goingPrev = effectiveDirection === "ltr" ? isLeftHalf : !isLeftHalf;
    (goingPrev ? goPrev : goNext)();
  };

  const goToToc = async (href: string) => {
    setTocOpen(false);
    try {
      await viewRef.current?.goTo(href);
    } catch {
      // ignore
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex flex-col bg-black text-white">
      <header className="z-10 flex items-center gap-2 border-b border-white/10 bg-black/80 px-3 py-2 backdrop-blur">
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
        className="relative flex-1 cursor-pointer select-none overflow-hidden bg-white"
      >
        <div ref={containerRef} className="absolute inset-0" />
        {loadStatus === "loading" ? (
          <div className="absolute inset-0 flex items-center justify-center bg-black/80 text-white">
            {t("common.loading")}
          </div>
        ) : null}
        {loadStatus === "error" ? (
          <div className="absolute inset-0 flex flex-col items-center justify-center gap-3 bg-black/90 text-white">
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
            <div className="grid gap-2">
              <Label>{t("reader.epubFontSize")}</Label>
              <div className="flex items-center gap-2">
                <Button
                  type="button"
                  variant="outline"
                  size="sm"
                  onClick={() => onFontSizeChange(fontSize - READER_FONT_SIZE_STEP)}
                  disabled={fontSize <= READER_FONT_SIZE_MIN}
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
                  onClick={() => onFontSizeChange(fontSize + READER_FONT_SIZE_STEP)}
                  disabled={fontSize >= READER_FONT_SIZE_MAX}
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
                    onThemeChange(v as ReaderTheme);
                  }
                }}
                variant="outline"
                className="flex-wrap justify-start"
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
                    onWritingModeChange(v as ReaderWritingMode);
                  }
                }}
                variant="outline"
                className="flex-wrap justify-start"
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
              {writingMode === "auto" ? (
                <p className="text-xs text-muted-foreground">
                  {t("reader.writingMode.autoDetected", {
                    mode: t(`reader.writingMode.${effectiveWritingMode}`),
                  })}
                </p>
              ) : null}
            </div>
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
