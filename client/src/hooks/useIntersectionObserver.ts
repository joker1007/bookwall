import { useEffect, useRef } from "react";

interface UseIntersectionObserverOptions {
  onIntersect: () => void;
  enabled: boolean;
  rootMargin?: string;
}

export function useIntersectionObserver({
  onIntersect,
  enabled,
  rootMargin = "600px 0px",
}: UseIntersectionObserverOptions) {
  const ref = useRef<HTMLDivElement | null>(null);
  // Keep the latest callback without recreating the observer.
  const callbackRef = useRef(onIntersect);
  useEffect(() => {
    callbackRef.current = onIntersect;
  });

  useEffect(() => {
    const el = ref.current;
    if (!el || !enabled) return;
    const observer = new IntersectionObserver(
      (entries) => {
        if (entries.some((entry) => entry.isIntersecting)) callbackRef.current();
      },
      { rootMargin },
    );
    observer.observe(el);
    return () => observer.disconnect();
  }, [enabled, rootMargin]);

  return ref;
}
