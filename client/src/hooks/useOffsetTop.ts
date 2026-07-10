import { useLayoutEffect, useState, type RefObject } from "react";

// Tracks an element's document offsetTop so content above it appearing or
// disappearing (BulkActionBar, descriptions) keeps a window virtualizer's
// scrollMargin honest. Intentionally runs after every commit; the equality
// guard inside setState prevents update loops.
export function useOffsetTop<T extends HTMLElement>(ref: RefObject<T | null>) {
  const [offsetTop, setOffsetTop] = useState(0);
  // eslint-disable-next-line react-hooks/exhaustive-deps -- per-commit check by design, guarded against loops
  useLayoutEffect(() => {
    setOffsetTop((prev) => {
      const next = ref.current?.offsetTop ?? 0;
      return prev === next ? prev : next;
    });
  });
  return offsetTop;
}
