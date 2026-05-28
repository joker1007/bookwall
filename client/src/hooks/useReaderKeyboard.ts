import { useEffect } from "react";

interface ReaderKeyboardOptions {
  // RTL flips ArrowLeft/Right so an arrow always advances in the reading
  // direction. Space / Backspace stay direction-agnostic by convention.
  direction: "ltr" | "rtl";
  // Suspended while a settings / TOC / hotkeys overlay is open so the
  // overlay's focus trap can use arrows without paging. "?" still works.
  paused: boolean;
  onNext: () => void;
  onPrev: () => void;
  onToggleHotkeys: () => void;
  onToggleFullscreen: () => void;
  onEscape: () => void;
  // CBZ/PDF only: Shift+Arrow advances by a single page to re-pair an
  // offset spread, and "2" toggles spread mode.
  onNextSingle?: () => void;
  onPrevSingle?: () => void;
  onToggleSpread?: () => void;
}

// Shared keyboard navigation for the page-image (CBZ/PDF) and EPUB readers.
// Both bind the same set of shortcuts; the optional callbacks cover the
// page-image reader's extras.
export function useReaderKeyboard({
  direction,
  paused,
  onNext,
  onPrev,
  onToggleHotkeys,
  onToggleFullscreen,
  onEscape,
  onNextSingle,
  onPrevSingle,
  onToggleSpread,
}: ReaderKeyboardOptions) {
  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      const target = e.target as HTMLElement | null;
      if (target?.tagName === "INPUT" || target?.tagName === "TEXTAREA") return;

      // "?" toggles the cheat sheet from anywhere — never gated by an overlay.
      if (e.key === "?") {
        e.preventDefault();
        onToggleHotkeys();
        return;
      }
      if (paused) return;

      if (e.key === "f" || e.key === "F") {
        e.preventDefault();
        onToggleFullscreen();
        return;
      }

      const rtl = direction === "rtl";
      const canNudge = onNextSingle && onPrevSingle;
      if (e.key === "ArrowRight") {
        e.preventDefault();
        if (e.shiftKey && canNudge) (rtl ? onPrevSingle : onNextSingle)!();
        else (rtl ? onPrev : onNext)();
      } else if (e.key === "ArrowLeft") {
        e.preventDefault();
        if (e.shiftKey && canNudge) (rtl ? onNextSingle : onPrevSingle)!();
        else (rtl ? onNext : onPrev)();
      } else if (e.key === " " || e.code === "Space") {
        e.preventDefault();
        onNext();
      } else if (e.key === "Backspace") {
        e.preventDefault();
        onPrev();
      } else if (e.key === "2" && onToggleSpread) {
        e.preventDefault();
        onToggleSpread();
      } else if (e.key === "Escape") {
        e.preventDefault();
        onEscape();
      }
    };
    window.addEventListener("keydown", handler);
    return () => window.removeEventListener("keydown", handler);
  }, [
    direction,
    paused,
    onNext,
    onPrev,
    onToggleHotkeys,
    onToggleFullscreen,
    onEscape,
    onNextSingle,
    onPrevSingle,
    onToggleSpread,
  ]);
}
