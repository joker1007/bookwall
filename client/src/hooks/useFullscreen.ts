import { useCallback, useEffect, useState } from "react";
import type { RefObject } from "react";

/**
 * Toggleable fullscreen state for an element, with a graceful CSS-only
 * fallback for browsers (notably iOS Safari) that refuse the Fullscreen
 * API on arbitrary elements.
 *
 * `isFullscreen` is true when EITHER the native API succeeded OR the
 * pseudo-fullscreen flag is on, so consumers can collapse their UI
 * chrome without caring which mode they're in.
 */
export function useFullscreen(targetRef?: RefObject<HTMLElement | null>) {
  const [apiFullscreen, setApiFullscreen] = useState(
    typeof document !== "undefined" && !!document.fullscreenElement,
  );
  const [pseudoFullscreen, setPseudoFullscreen] = useState(false);

  useEffect(() => {
    const sync = () => setApiFullscreen(!!document.fullscreenElement);
    document.addEventListener("fullscreenchange", sync);
    return () => document.removeEventListener("fullscreenchange", sync);
  }, []);

  // Leave fullscreen on unmount so navigating away from the reader
  // doesn't leave the browser stuck in fullscreen.
  useEffect(() => {
    return () => {
      if (document.fullscreenElement) {
        document.exitFullscreen().catch(() => {});
      }
    };
  }, []);

  const enter = useCallback(async () => {
    const target = targetRef?.current ?? document.documentElement;
    if (target && typeof target.requestFullscreen === "function") {
      try {
        await target.requestFullscreen();
        return;
      } catch {
        // permission denied or unsupported on this element/platform
      }
    }
    setPseudoFullscreen(true);
  }, [targetRef]);

  const exit = useCallback(async () => {
    if (document.fullscreenElement) {
      try {
        await document.exitFullscreen();
      } catch {
        // ignore — apiFullscreen will desync but pseudo path still works
      }
    }
    setPseudoFullscreen(false);
  }, []);

  const isFullscreen = apiFullscreen || pseudoFullscreen;

  const toggle = useCallback(() => {
    if (isFullscreen) {
      void exit();
    } else {
      void enter();
    }
  }, [isFullscreen, enter, exit]);

  return { isFullscreen, toggle, enter, exit };
}
