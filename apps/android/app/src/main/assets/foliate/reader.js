// Glue between the native Android host and foliate-js. Exposes window.foliateGlue
// (Kotlin -> JS via evaluateJavascript) and calls window.AndroidBridge (JS -> Kotlin
// via @JavascriptInterface). Mirrors the web reader's foliate usage
// (client/src/components/reader/EpubReaderView.tsx) so CFIs are interoperable.

import { buildBookStyles, pageBackground } from "./reader-styles.js";

const bridge = () => window.AndroidBridge;
const SWIPE_THRESHOLD_PX = 40;

const state = {
  view: null,
  settings: { fontSize: 100, theme: "light", writingMode: "auto" },
  verticalDetected: false,
  ready: false,
  // Last relocated CFI; used to detect that next() did not advance (end of book).
  lastCfi: null,
};

function reportError(message) {
  try {
    bridge()?.onError(String(message));
  } catch (_) {
    // bridge may be absent in a plain browser preview
  }
}

function applyStyles() {
  const renderer = state.view?.renderer;
  renderer?.setStyles?.(buildBookStyles(state.settings));
  document.body.style.background = pageBackground(state.settings.theme);
}

// Match the web reader: 2 columns only on wide (tablet) viewports, 1 below.
// On phone width two columns shrink lines until single CJK characters break
// across them — worst for vertical-writing books.
const wideViewport = window.matchMedia("(min-width: 768px)");

function applyColumnCount() {
  state.view?.renderer?.setAttribute?.("max-column-count", wideViewport.matches ? "2" : "1");
}

async function openBook(epubUrl, initialCfi) {
  try {
    await import("./view.js");
    const root = document.getElementById("root");
    if (!root) throw new Error("no #root");

    const view = document.createElement("foliate-view");
    view.style.display = "block";
    view.style.width = "100%";
    view.style.height = "100%";
    root.append(view);
    state.view = view;

    view.addEventListener("relocate", (e) => {
      const detail = e.detail || {};
      const fraction =
        typeof detail.fraction === "number"
          ? Math.max(0, Math.min(1, detail.fraction))
          : 0;
      if (detail.cfi) {
        state.lastCfi = detail.cfi;
        try {
          bridge()?.onRelocate(detail.cfi, fraction);
        } catch (_) {
          // ignore
        }
      }
    });

    view.addEventListener("load", (e) => {
      if (state.verticalDetected) return;
      try {
        const doc = e.detail?.doc;
        const win = doc?.defaultView;
        if (!win) return;
        const html = win.getComputedStyle(doc.documentElement).writingMode;
        const body = win.getComputedStyle(doc.body).writingMode;
        if (html?.startsWith("vertical") || body?.startsWith("vertical")) {
          state.verticalDetected = true;
          bridge()?.onWritingModeDetected("vertical");
        }
      } catch (_) {
        // sandboxed iframes can throw on cross-origin style access
      }
    });

    const res = await fetch(epubUrl);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const blob = await res.blob();
    // foliate picks its format adapter off file.name, so wrap in a named File.
    const file = new File([blob], "book.epub", {
      type: blob.type || "application/epub+zip",
    });
    await view.open(file);

    if (view.book?.dir === "rtl" && !state.verticalDetected) {
      state.verticalDetected = true;
      bridge()?.onWritingModeDetected("vertical");
    }

    const renderer = view.renderer;
    renderer?.setAttribute?.("max-inline-size", "100%");
    renderer?.setAttribute?.("max-block-size", "100%");
    renderer?.setAttribute?.("margin", "16px");
    renderer?.setAttribute?.("gap", "5%");
    applyColumnCount();
    wideViewport.addEventListener("change", applyColumnCount);
    // Seed styles before init(): foliate replays the last setStyles per section.
    applyStyles();

    const cfi = initialCfi || undefined;
    try {
      if (cfi) {
        await view.init({ lastLocation: cfi });
      } else {
        await view.goTo(0);
      }
    } catch (navErr) {
      console.error("[glue] init/goTo failed", navErr?.message || navErr);
      try {
        await view.goTo(0);
      } catch (fallbackErr) {
        console.error("[glue] goTo(0) fallback failed", fallbackErr?.message || fallbackErr);
      }
    }

    const toc = view.book?.toc ? JSON.stringify(simplifyToc(view.book.toc)) : "[]";
    const dir = view.book?.dir || "ltr";
    const sectionTotal = Array.isArray(view.book?.sections)
      ? view.book.sections.length
      : 0;
    state.ready = true;
    bridge()?.onBookOpened(toc, dir, sectionTotal);
  } catch (err) {
    reportError(err?.message || err);
  }
}

// foliate TOC items carry functions/extra fields; keep only {label, href, subitems}.
function simplifyToc(items) {
  const out = [];
  for (const item of items || []) {
    out.push({
      label: typeof item.label === "string" ? item.label : "",
      href: item.href || null,
      subitems: item.subitems ? simplifyToc(item.subitems) : [],
    });
  }
  return out;
}

function installTapLayer() {
  const layer = document.getElementById("taplayer");
  if (!layer) return;
  let startX = 0;
  let startY = 0;
  let moved = false;
  layer.addEventListener("pointerdown", (e) => {
    startX = e.clientX;
    startY = e.clientY;
    moved = false;
  });
  layer.addEventListener("pointerup", (e) => {
    const dx = e.clientX - startX;
    const dy = e.clientY - startY;
    if (Math.abs(dx) > SWIPE_THRESHOLD_PX && Math.abs(dx) > Math.abs(dy)) {
      // Horizontal swipe: report direction; Kotlin maps to next/prev by RTL.
      bridge()?.onSwipe(dx < 0 ? "left" : "right");
      return;
    }
    if (moved) return;
    const w = layer.clientWidth || window.innerWidth;
    const x = e.clientX;
    const zone = x < w / 3 ? "left" : x > (w * 2) / 3 ? "right" : "center";
    bridge()?.onTap(zone);
  });
  layer.addEventListener("pointermove", (e) => {
    if (Math.abs(e.clientX - startX) > 10 || Math.abs(e.clientY - startY) > 10) {
      moved = true;
    }
  });
}

window.foliateGlue = {
  open: (epubUrl, initialCfi) => openBook(epubUrl, initialCfi),
  next: async () => {
    const view = state.view;
    if (!view?.next) return;
    const prev = state.lastCfi;
    await view.next();
    // A successful page turn fires relocate (updating lastCfi) shortly after; if
    // the position is unchanged we're at the end of the book, so let the host ask
    // whether to roll over to the next book.
    setTimeout(() => {
      if (state.lastCfi === prev) bridge()?.onReachedEnd?.();
    }, 120);
  },
  prev: () => state.view?.prev?.(),
  goTo: (href) => state.view?.goTo?.(href),
  goToCfi: (cfi) => state.view?.init?.({ lastLocation: cfi }),
  goToFraction: (f) => state.view?.goToFraction?.(f),
  setStyles: (json) => {
    try {
      state.settings = { ...state.settings, ...JSON.parse(json) };
    } catch (_) {
      // keep previous settings on bad payload
    }
    if (state.ready) applyStyles();
  },
};

installTapLayer();
bridge()?.onReady();
