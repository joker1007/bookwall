import { useCallback, useEffect, useState } from "react";
import type { RefObject } from "react";

// CSS-only pseudo-fullscreen fallback for browsers (iOS Safari) that refuse
// the Fullscreen API on arbitrary elements.
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

  // Leave fullscreen on unmount.
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
        // denied/unsupported: fall through to pseudo-fullscreen
      }
    }
    setPseudoFullscreen(true);
  }, [targetRef]);

  const exit = useCallback(async () => {
    if (document.fullscreenElement) {
      try {
        await document.exitFullscreen();
      } catch {
        // ignore: pseudo path still resets below
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
