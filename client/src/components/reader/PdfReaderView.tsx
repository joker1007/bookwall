import { useCallback, useEffect, useMemo, useRef, useState } from "react";
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
import type {
  PDFDocumentProxy,
  PDFPageProxy,
  RenderTask,
  TextLayer as TextLayerType,
} from "pdfjs-dist";
import type { PDFLinkService } from "pdfjs-dist/web/pdf_viewer.mjs";
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
  ReaderOptionField,
  ReaderSpreadField,
} from "@/components/reader/ReaderSettingsFields";
import { TocList } from "@/components/reader/TocList";
import { useNextSeriesBook } from "@/hooks/useBooks";
import { useFullscreen } from "@/hooks/useFullscreen";
import { useReaderKeyboard } from "@/hooks/useReaderKeyboard";
import {
  useReadingProgress,
  useUpdateReadingProgress,
} from "@/hooks/useReadingProgress";
import { useResolvedReaderSettings } from "@/hooks/useResolvedReaderSettings";
import {
  useUpdateUserPreferences,
  useUserPreferences,
} from "@/hooks/useUserPreferences";
import { cn } from "@/lib/utils";
import {
  computePdfScale,
  loadPdfjs,
  resolveOutline,
  type PdfTocItem,
} from "@/lib/pdf";
import {
  READER_PRELOAD_AHEAD_DEFAULT,
  READER_PROGRESS_DEBOUNCE_MS,
  READER_SCALE_VALUES,
} from "@/types/api";
import type { Book, ReaderScale, ReaderSettings } from "@/types/api";

type PdfjsModule = Awaited<ReturnType<typeof loadPdfjs>>;

// Clamp render scale above this so a huge page can't allocate a giant bitmap.
const MAX_CANVAS_PIXELS = 16_777_216;

// Minimal PDFLinkService: the full one drags the whole pdfjs viewer component
// into the bundle. Handles internal GoTo links and external URL links only.
class ReaderLinkService {
  externalLinkEnabled = true;
  externalLinkTarget = 2; // LinkTarget.BLANK
  externalLinkRel = "noopener noreferrer nofollow";
  #doc: PDFDocumentProxy;
  #navigate: (pageIndex: number) => void;

  constructor(doc: PDFDocumentProxy, navigate: (pageIndex: number) => void) {
    this.#doc = doc;
    this.#navigate = navigate;
  }

  get pagesCount(): number {
    return this.#doc.numPages;
  }
  get page(): number {
    return 1;
  }
  set page(_value: number) {}
  get rotation(): number {
    return 0;
  }
  set rotation(_value: number) {}
  get isInPresentationMode(): boolean {
    return false;
  }

  async goToDestination(dest: string | unknown[]): Promise<void> {
    try {
      const explicit =
        typeof dest === "string" ? await this.#doc.getDestination(dest) : dest;
      if (!Array.isArray(explicit) || explicit.length === 0) return;
      const ref = explicit[0];
      let pageIndex: number | null = null;
      if (ref && typeof ref === "object") {
        pageIndex = await this.#doc.getPageIndex(ref as { num: number; gen: number });
      } else if (typeof ref === "number") {
        pageIndex = ref;
      }
      if (pageIndex !== null) this.#navigate(pageIndex);
    } catch {
      // Unresolvable destination — ignore.
    }
  }

  goToPage(val: number | string): void {
    const n = typeof val === "string" ? parseInt(val, 10) : val;
    if (Number.isFinite(n)) this.#navigate(n - 1);
  }

  addLinkAttributes(link: HTMLAnchorElement, url: string, newWindow?: boolean): void {
    link.href = url || "";
    link.rel = this.externalLinkRel;
    if (newWindow || this.externalLinkTarget === 2) link.target = "_blank";
  }

  getDestinationHash(): string {
    return "#";
  }
  getAnchorUrl(): string {
    return "#";
  }
  setHash(): void {}
  executeNamedAction(): void {}
  async executeSetOCGState(): Promise<void> {}
}

interface PdfReaderViewProps {
  book: Book;
}

export function PdfReaderView({ book }: PdfReaderViewProps) {
  const { t } = useTranslation();
  const navigate = useNavigate();
  // Falls back to the detail page on a deep-link entry with no history to pop.
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
  const resolved = useResolvedReaderSettings(book.id);
  const nextBook = useNextSeriesBook(book);

  const [page, setPage] = useState(0);
  const [spread, setSpread] = useState(false);
  const [direction, setDirection] = useState<"ltr" | "rtl">("ltr");
  const [scale, setScale] = useState<ReaderScale>("fit");
  const [numPages, setNumPages] = useState(book.page_count ?? 0);
  const [outline, setOutline] = useState<PdfTocItem[]>([]);
  const [loadStatus, setLoadStatus] = useState<"loading" | "ready" | "error">(
    "loading",
  );
  const [errorKind, setErrorKind] = useState<"generic" | "encrypted">("generic");
  const [settingsOpen, setSettingsOpen] = useState(false);
  const [tocOpen, setTocOpen] = useState(false);
  const [hotkeysOpen, setHotkeysOpen] = useState(false);
  const [initialized, setInitialized] = useState(false);
  const [viewportSize, setViewportSize] = useState({ width: 0, height: 0 });
  const [pdfjs, setPdfjs] = useState<PdfjsModule | null>(null);
  const [doc, setDoc] = useState<PDFDocumentProxy | null>(null);
  const [linkService, setLinkService] = useState<ReaderLinkService | null>(null);

  const readerContainerRef = useRef<HTMLDivElement | null>(null);
  const viewportRef = useRef<HTMLDivElement | null>(null);
  const navigateRef = useRef<(pageIndex: number) => void>(() => {});
  const thumbCache = useMemo(() => {
    void book.id;
    return new Map<number, string>();
  }, [book.id]);

  const { isFullscreen, toggle: toggleFullscreen, exit: exitFullscreen } =
    useFullscreen(readerContainerRef);

  // Restore during render (not an effect) so it lands before paint — see
  // books.read.tsx for the page-0-flash rationale.
  if (!initialized && resolved.ready) {
    setPage(resolved.currentPage);
    setSpread(resolved.settings.spread ?? false);
    setDirection(resolved.settings.direction ?? "ltr");
    setScale(resolved.settings.scale ?? "fit");
    setInitialized(true);
  }

  // Range-fetched (disableAutoFetch) so a huge scanned PDF streams on demand.
  useEffect(() => {
    if (progress.isPending) return;
    let cancelled = false;
    let task: ReturnType<PdfjsModule["getDocument"]> | null = null;
    let createdDoc: PDFDocumentProxy | null = null;

    (async () => {
      try {
        const pdfjsMod = await loadPdfjs();
        if (cancelled) return;
        task = pdfjsMod.getDocument({
          url: `/api/books/${book.id}/file`,
          withCredentials: true,
          disableAutoFetch: true,
          rangeChunkSize: 65536,
        });
        const openedDoc = await task.promise;
        if (cancelled) {
          openedDoc.destroy();
          return;
        }
        createdDoc = openedDoc;
        setNumPages(openedDoc.numPages);
        const rawOutline = await openedDoc.getOutline();
        if (cancelled) return;
        if (rawOutline) setOutline(await resolveOutline(openedDoc, rawOutline));
        if (cancelled) return;
        setPdfjs(pdfjsMod);
        setLinkService(
          new ReaderLinkService(openedDoc, (idx) => navigateRef.current(idx)),
        );
        setDoc(openedDoc);
        setLoadStatus("ready");
      } catch (err) {
        if (cancelled) return;
        const name = (err as { name?: string } | null)?.name;
        setErrorKind(name === "PasswordException" ? "encrypted" : "generic");
        setLoadStatus("error");
      }
    })();

    return () => {
      cancelled = true;
      try {
        task?.destroy();
      } catch {
        // ignore
      }
      createdDoc?.destroy();
    };
  }, [book.id, progress.isPending]);

  useEffect(() => {
    const el = viewportRef.current;
    if (!el) return;
    const ro = new ResizeObserver((entries) => {
      const rect = entries[0]?.contentRect;
      if (rect) setViewportSize({ width: rect.width, height: rect.height });
    });
    ro.observe(el);
    return () => ro.disconnect();
  }, [loadStatus]);

  const total = numPages;
  const step = spread ? 2 : 1;
  const lastPage = Math.max(0, total - 1);

  const goToPageIndex = useCallback(
    (idx: number) => {
      setPage(Math.min(Math.max(0, idx), Math.max(0, total - 1)));
    },
    [total],
  );

  // Via ref so the link service (bound to already-rendered AnnotationLayers)
  // never needs re-creating when goToPageIndex changes identity.
  useEffect(() => {
    navigateRef.current = goToPageIndex;
  }, [goToPageIndex]);

  // At the last page, advancing rolls over to the next book in the series.
  const goNext = useCallback(() => {
    if (page >= lastPage) {
      const next = nextBook.data;
      if (next) navigate(`/books/${next.id}/read`);
      return;
    }
    setPage((p) => Math.min(p + step, lastPage));
  }, [page, step, lastPage, nextBook.data, navigate]);
  const goPrev = useCallback(() => {
    setPage((p) => Math.max(p - step, 0));
  }, [step]);
  const goNextOne = useCallback(() => {
    setPage((p) => Math.min(p + 1, lastPage));
  }, [lastPage]);
  const goPrevOne = useCallback(() => {
    setPage((p) => Math.max(p - 1, 0));
  }, []);

  // Gated on `initialized` so we never clobber the saved page with the initial 0.
  const debounceRef = useRef<number | null>(null);
  useEffect(() => {
    if (!initialized) return;
    if (debounceRef.current) window.clearTimeout(debounceRef.current);
    debounceRef.current = window.setTimeout(() => {
      update.mutate({ current_page: page });
    }, READER_PROGRESS_DEBOUNCE_MS);
    return () => {
      if (debounceRef.current) window.clearTimeout(debounceRef.current);
    };
    // update.mutate is stable; intentionally only depend on page.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [page, initialized]);

  const saveSettings = useCallback(
    (next: ReaderSettings) => {
      update.mutate({ settings: next });
    },
    [update],
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
  const handleEscape = useCallback(() => {
    if (isFullscreen) exitFullscreen();
    else goBack();
  }, [isFullscreen, exitFullscreen, goBack]);

  useReaderKeyboard({
    direction,
    paused: settingsOpen || tocOpen || hotkeysOpen,
    onNext: goNext,
    onPrev: goPrev,
    onNextSingle: goNextOne,
    onPrevSingle: goPrevOne,
    onToggleSpread: toggleSpread,
    onToggleHotkeys: toggleHotkeys,
    onToggleFullscreen: toggleFullscreen,
    onEscape: handleEscape,
  });

  const onLeftHalfClick = direction === "ltr" ? goPrev : goNext;
  const onRightHalfClick = direction === "ltr" ? goNext : goPrev;

  const visiblePages = useMemo(() => {
    if (total === 0) return [];
    const base = spread ? [page, page + 1].filter((p) => p < total) : [page];
    return direction === "rtl" ? [...base].reverse() : base;
  }, [page, spread, direction, total]);

  // Warm nearby pages so a page-turn doesn't stall on Range byte-range fetches.
  useEffect(() => {
    if (!doc || loadStatus !== "ready" || total === 0) return;
    const ahead =
      preferences.data?.reader_defaults.preload_ahead ??
      READER_PRELOAD_AHEAD_DEFAULT;
    const startAhead = spread ? 2 : 1;
    const targets = new Set<number>();
    if (page - 1 >= 0) targets.add(page - 1);
    for (let i = 0; i < ahead; i++) {
      const p = page + startAhead + i;
      if (p >= total) break;
      targets.add(p);
    }
    let cancelled = false;
    const warm = () => {
      if (cancelled) return;
      for (const p of targets) doc.getPage(p + 1).catch(() => {});
    };
    const idle = window.requestIdleCallback?.(warm) ?? window.setTimeout(warm, 200);
    return () => {
      cancelled = true;
      window.cancelIdleCallback?.(idle as number);
      window.clearTimeout(idle as number);
    };
  }, [page, spread, total, loadStatus, preferences.data, doc]);

  const viewportClass = useMemo(() => {
    const base = "flex h-full w-full px-2";
    switch (scale) {
      case "fit":
        return `${base} items-center justify-center`;
      case "fit_height":
        return `${base} items-center justify-center overflow-x-auto`;
      case "fit_width":
        return `${base} items-start justify-center overflow-y-auto`;
      case "original":
        return `${base} items-start justify-center overflow-auto`;
    }
  }, [scale]);

  const availWidth = spread ? viewportSize.width / 2 : viewportSize.width;

  if (loadStatus === "loading" || !initialized) {
    return (
      <div className="fixed inset-0 z-50 flex items-center justify-center bg-black text-white">
        {t("common.loading")}
      </div>
    );
  }

  if (loadStatus === "error" || !pdfjs || !doc) {
    return (
      <div className="fixed inset-0 z-50 flex flex-col items-center justify-center gap-3 bg-black text-white">
        <p>
          {errorKind === "encrypted"
            ? t("reader.pdf.encrypted")
            : t("reader.loadFailed")}
        </p>
        <Button variant="secondary" onClick={goBack}>
          {t("reader.back")}
        </Button>
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
          {book.title}
        </h1>
        <span className="px-2 text-xs tabular-nums text-white/70">
          {t("reader.pageIndicator", { current: page + 1, total })}
        </span>
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
        className="relative flex flex-1 items-center justify-center overflow-hidden"
      >
        <div ref={viewportRef} className={viewportClass}>
          {visiblePages.map((p, slot) => (
            <PdfPageView
              key={`slot-${slot}`}
              pdfjs={pdfjs}
              doc={doc}
              linkService={linkService}
              pageNumber={p + 1}
              mode={scale}
              availWidth={availWidth}
              availHeight={viewportSize.height}
            />
          ))}
        </div>

        {/* Hot-zones limited to the outer 12% so the middle stays selectable. */}
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

        {total > 1 ? (
          <ReaderScrubber
            value={page}
            min={0}
            max={Math.max(0, total - 1)}
            step={1}
            direction={direction}
            onSeek={(n) => setPage(n)}
            renderPreview={(p) => (
              <PdfThumb doc={doc} pageNumber={p + 1} cache={thumbCache} />
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

      <Sheet open={tocOpen} onOpenChange={setTocOpen}>
        <SheetContent side="left" className="w-80 sm:w-96">
          <SheetHeader>
            <SheetTitle>{t("reader.toc.title")}</SheetTitle>
            <SheetDescription>{t("reader.toc.description")}</SheetDescription>
          </SheetHeader>
          <nav className="overflow-y-auto px-4 pb-4 text-sm">
            {outline.length === 0 ? (
              <p className="text-muted-foreground">{t("reader.toc.empty")}</p>
            ) : (
              <TocList
                items={outline}
                disabled={(item) => item.pageIndex === null}
                onSelect={(item) => {
                  if (item.pageIndex === null) return;
                  setTocOpen(false);
                  goToPageIndex(item.pageIndex);
                }}
              />
            )}
          </nav>
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

interface PdfPageViewProps {
  pdfjs: PdfjsModule;
  doc: PDFDocumentProxy;
  linkService: ReaderLinkService | null;
  pageNumber: number;
  mode: ReaderScale;
  availWidth: number;
  availHeight: number;
}

// Renders off-screen then swaps in, so the previous page stays visible until
// the new one is ready (no blank flash between turns).
function PdfPageView({
  pdfjs,
  doc,
  linkService,
  pageNumber,
  mode,
  availWidth,
  availHeight,
}: PdfPageViewProps) {
  const { t } = useTranslation();
  const containerRef = useRef<HTMLDivElement | null>(null);
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const textLayerRef = useRef<HTMLDivElement | null>(null);
  const annotationLayerRef = useRef<HTMLDivElement | null>(null);
  const renderTaskRef = useRef<RenderTask | null>(null);
  const textLayerObjRef = useRef<TextLayerType | null>(null);
  const pageRef = useRef<PDFPageProxy | null>(null);
  const [failed, setFailed] = useState(false);

  useEffect(() => {
    if (availWidth <= 0 || availHeight <= 0) return;
    let cancelled = false;

    (async () => {
      try {
        const page = await doc.getPage(pageNumber);
        if (cancelled) return;
        pageRef.current = page;
        setFailed(false);

        const base = page.getViewport({ scale: 1 });
        const renderScale = computePdfScale(
          mode,
          base.width,
          base.height,
          availWidth,
          availHeight,
        );
        const viewport = page.getViewport({ scale: renderScale });

        let outputScale = window.devicePixelRatio || 1;
        const area = viewport.width * viewport.height;
        if (area * outputScale * outputScale > MAX_CANVAS_PIXELS) {
          outputScale = Math.sqrt(MAX_CANVAS_PIXELS / area);
        }

        const offscreen = document.createElement("canvas");
        offscreen.width = Math.max(1, Math.floor(viewport.width * outputScale));
        offscreen.height = Math.max(1, Math.floor(viewport.height * outputScale));

        const transform =
          outputScale !== 1
            ? [outputScale, 0, 0, outputScale, 0, 0]
            : undefined;
        const task = page.render({ canvas: offscreen, viewport, transform });
        renderTaskRef.current = task;
        await task.promise;
        if (cancelled) return;

        const cssWidth = Math.floor(viewport.width);
        const cssHeight = Math.floor(viewport.height);
        const container = containerRef.current;
        const canvas = canvasRef.current;
        if (!container || !canvas) return;

        // pdfjs layers size off `--total-scale-factor` (setLayerDimensions
        // reads but never sets it); without it the text layer collapses.
        container.style.setProperty("--scale-factor", String(renderScale));
        container.style.setProperty("--total-scale-factor", String(renderScale));
        container.style.width = `${cssWidth}px`;
        container.style.height = `${cssHeight}px`;

        canvas.width = offscreen.width;
        canvas.height = offscreen.height;
        canvas.style.width = `${cssWidth}px`;
        canvas.style.height = `${cssHeight}px`;
        canvas.getContext("2d")?.drawImage(offscreen, 0, 0);

        const textDiv = textLayerRef.current;
        if (textDiv) {
          textLayerObjRef.current?.cancel();
          textDiv.replaceChildren();
          pdfjs.setLayerDimensions(textDiv, viewport);
          const textLayer = new pdfjs.TextLayer({
            textContentSource: page.streamTextContent(),
            container: textDiv,
            viewport,
          });
          textLayerObjRef.current = textLayer;
          await textLayer.render();
          if (cancelled) return;
        }

        const annotDiv = annotationLayerRef.current;
        if (annotDiv && linkService) {
          annotDiv.replaceChildren();
          pdfjs.setLayerDimensions(annotDiv, viewport);
          const annotationViewport = viewport.clone({ dontFlip: true });
          const annotations = await page.getAnnotations();
          if (cancelled) return;
          const annotationLayer = new pdfjs.AnnotationLayer({
            div: annotDiv,
            accessibilityManager: undefined,
            annotationCanvasMap: undefined,
            annotationEditorUIManager: undefined,
            page,
            viewport: annotationViewport,
            structTreeLayer: undefined,
            commentManager: undefined,
            linkService: linkService as unknown as PDFLinkService,
            annotationStorage: undefined,
          });
          await annotationLayer.render({
            annotations,
            viewport: annotationViewport,
            div: annotDiv,
            page,
            linkService: linkService as unknown as PDFLinkService,
            renderForms: false,
          });
        }
      } catch (err) {
        if (cancelled) return;
        if ((err as { name?: string } | null)?.name === "RenderingCancelledException") {
          return;
        }
        setFailed(true);
      }
    })();

    return () => {
      cancelled = true;
      try {
        renderTaskRef.current?.cancel();
      } catch {
        // ignore
      }
      textLayerObjRef.current?.cancel();
      pageRef.current?.cleanup();
    };
  }, [doc, pdfjs, linkService, pageNumber, mode, availWidth, availHeight]);

  return (
    <div
      ref={containerRef}
      className="pdf-page relative shrink-0 bg-white text-black"
    >
      <canvas ref={canvasRef} className="block" />
      <div
        ref={textLayerRef}
        className="textLayer absolute left-0 top-0 z-10"
      />
      <div
        ref={annotationLayerRef}
        className="annotationLayer absolute left-0 top-0 z-20"
      />
      {failed ? (
        <div className="absolute inset-0 z-30 flex items-center justify-center bg-black/70 text-xs text-white/70">
          {t("reader.loadFailed")}
        </div>
      ) : null}
    </div>
  );
}

interface PdfThumbProps {
  doc: PDFDocumentProxy;
  pageNumber: number;
  cache: Map<number, string>;
}

function PdfThumb({ doc, pageNumber, cache }: PdfThumbProps) {
  const [rendered, setRendered] = useState<{ page: number; src: string } | null>(
    null,
  );

  useEffect(() => {
    if (cache.has(pageNumber)) return;
    let cancelled = false;
    let task: RenderTask | null = null;
    (async () => {
      try {
        const page = await doc.getPage(pageNumber);
        if (cancelled) return;
        const base = page.getViewport({ scale: 1 });
        const targetHeight = 160;
        const viewport = page.getViewport({ scale: targetHeight / base.height });
        const canvas = document.createElement("canvas");
        canvas.width = Math.max(1, Math.floor(viewport.width));
        canvas.height = Math.max(1, Math.floor(viewport.height));
        task = page.render({ canvas, viewport });
        await task.promise;
        if (cancelled) return;
        const url = canvas.toDataURL("image/jpeg", 0.7);
        cache.set(pageNumber, url);
        setRendered({ page: pageNumber, src: url });
      } catch {
        // ignore — placeholder stays
      }
    })();
    return () => {
      cancelled = true;
      try {
        task?.cancel();
      } catch {
        // ignore
      }
    };
  }, [doc, pageNumber, cache]);

  const src =
    cache.get(pageNumber) ??
    (rendered?.page === pageNumber ? rendered.src : null);

  return src ? (
    <img
      src={src}
      alt=""
      className="h-32 w-auto max-w-[40vw] rounded border border-white/20 bg-black object-contain shadow-lg"
    />
  ) : (
    <div className="h-32 w-24 rounded border border-white/20 bg-black/80 shadow-lg" />
  );
}
