import { useEffect } from "react";

interface ReaderKeyboardOptions {
  // RTL flips ArrowLeft/Right; Space/Backspace stay direction-agnostic.
  direction: "ltr" | "rtl";
  // Suspended while an overlay is open so its focus trap can use arrows.
  paused: boolean;
  onNext: () => void;
  onPrev: () => void;
  onToggleHotkeys: () => void;
  onToggleFullscreen: () => void;
  onEscape: () => void;
  // Shift+Arrow advances a single page to re-pair an offset spread.
  onNextSingle?: () => void;
  onPrevSingle?: () => void;
  onToggleSpread?: () => void;
  onToggleThumbnails?: () => void;
}

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
  onToggleThumbnails,
}: ReaderKeyboardOptions) {
  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      const target = e.target as HTMLElement | null;
      if (target?.tagName === "INPUT" || target?.tagName === "TEXTAREA") return;

      // "?" works from anywhere, never gated by an overlay.
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
      } else if ((e.key === "g" || e.key === "G") && onToggleThumbnails) {
        e.preventDefault();
        onToggleThumbnails();
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
    onToggleThumbnails,
  ]);
}
