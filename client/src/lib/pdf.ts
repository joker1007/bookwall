import type { PDFDocumentProxy } from "pdfjs-dist";
import type { ReaderScale } from "@/types/api";
// `?url` gives the hashed asset URL so pdfjs spins up its own worker from it;
// a document `destroy()` then never tears down a shared port.
import workerSrc from "pdfjs-dist/build/pdf.worker.min.mjs?url";
import "pdfjs-dist/web/pdf_viewer.css";

type PdfjsModule = typeof import("pdfjs-dist");

let pdfjsPromise: Promise<PdfjsModule> | null = null;

export function loadPdfjs(): Promise<PdfjsModule> {
  if (!pdfjsPromise) {
    pdfjsPromise = import("pdfjs-dist").then((mod) => {
      mod.GlobalWorkerOptions.workerSrc = workerSrc;
      return mod;
    });
  }
  return pdfjsPromise;
}

// Caller must halve the width when laying out a spread.
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

// Resolve each destination up front so TOC clicks are synchronous.
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
