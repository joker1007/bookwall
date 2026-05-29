import type { PDFDocumentProxy } from "pdfjs-dist";
import type { ReaderScale } from "@/types/api";
// `?url` hands us the hashed asset URL (base "/ui/" aware) without pulling
// the worker code into the importing chunk. pdfjs spins up its own module
// worker from this URL, so a document `destroy()` never tears down a shared
// port (which would break the next open).
import workerSrc from "pdfjs-dist/build/pdf.worker.min.mjs?url";
// Text- and annotation-layer styles. Small, and only ships in whatever chunk
// the PDF reader lands in.
import "pdfjs-dist/web/pdf_viewer.css";

type PdfjsModule = typeof import("pdfjs-dist");

let pdfjsPromise: Promise<PdfjsModule> | null = null;

// Load the (heavy) pdfjs runtime lazily and wire the worker exactly once.
// Callers get the module back so they can reach getDocument / TextLayer /
// AnnotationLayer without a second import.
export function loadPdfjs(): Promise<PdfjsModule> {
  if (!pdfjsPromise) {
    pdfjsPromise = import("pdfjs-dist").then((mod) => {
      mod.GlobalWorkerOptions.workerSrc = workerSrc;
      return mod;
    });
  }
  return pdfjsPromise;
}

// Scale a single page's natural (scale-1) dimensions into the available slot.
// The caller is responsible for halving the width when laying out a spread.
export function computePdfScale(
  mode: ReaderScale,
  pageWidth: number,
  pageHeight: number,
  availWidth: number,
  availHeight: number,
): number {
  if (pageWidth <= 0 || pageHeight <= 0) return 1;
  switch (mode) {
    case "fit":
      return Math.min(availWidth / pageWidth, availHeight / pageHeight);
    case "fit_height":
      return availHeight / pageHeight;
    case "fit_width":
      return availWidth / pageWidth;
    case "original":
      return 1;
  }
}

// Minimal shape of one `PDFDocumentProxy.getOutline()` entry that we read.
interface RawOutlineItem {
  title: string;
  dest: string | unknown[] | null;
  url: string | null;
  items?: RawOutlineItem[];
}

export interface PdfTocItem {
  label: string;
  // null for external-URL bookmarks or unresolvable destinations.
  pageIndex: number | null;
  url: string | null;
  subitems: PdfTocItem[];
}

// Resolve a PDF destination (named string or explicit array) to a 0-based
// page index. Returns null when the destination can't be resolved.
export async function resolveDestToPageIndex(
  doc: PDFDocumentProxy,
  dest: string | unknown[] | null | undefined,
): Promise<number | null> {
  if (!dest) return null;
  try {
    const explicit =
      typeof dest === "string" ? await doc.getDestination(dest) : dest;
    if (!Array.isArray(explicit) || explicit.length === 0) return null;
    const ref = explicit[0];
    if (ref && typeof ref === "object") {
      return await doc.getPageIndex(ref as { num: number; gen: number });
    }
    if (typeof ref === "number") return ref;
    return null;
  } catch {
    return null;
  }
}

// Flatten the PDF outline tree into our TOC shape, resolving each entry's
// destination to a page index up front so clicks are synchronous.
export async function resolveOutline(
  doc: PDFDocumentProxy,
  items: RawOutlineItem[] | null | undefined,
): Promise<PdfTocItem[]> {
  if (!items || items.length === 0) return [];
  return Promise.all(
    items.map(async (it) => ({
      label: it.title,
      url: it.url ?? null,
      pageIndex: it.url ? null : await resolveDestToPageIndex(doc, it.dest),
      subitems: it.items?.length ? await resolveOutline(doc, it.items) : [],
    })),
  );
}
