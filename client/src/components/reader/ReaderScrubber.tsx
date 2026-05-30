import { useCallback, useRef, useState } from "react";
import type {
  ChangeEvent,
  PointerEvent as ReactPointerEvent,
  ReactNode,
} from "react";
import { cn } from "@/lib/utils";

interface ReaderScrubberProps {
  value: number;
  min: number;
  max: number;
  step?: number;
  direction?: "ltr" | "rtl";
  onSeek: (next: number) => void;
  onCommit?: (next: number) => void;
  renderPreview: (hoverValue: number) => ReactNode;
  formatLabel: (value: number) => string;
  ariaLabel: string;
}

// Pointer events throughout, not mouse events: once a finger lands on the
// slider iOS / Android stop firing mousemove, but pointermove still arrives.
export function ReaderScrubber({
  value,
  min,
  max,
  step = 1,
  direction = "ltr",
  onSeek,
  onCommit,
  renderPreview,
  formatLabel,
  ariaLabel,
}: ReaderScrubberProps) {
  const trackRef = useRef<HTMLDivElement | null>(null);
  const draggingRef = useRef(false);
  const [hoverState, setHoverState] = useState<{
    value: number;
    clientX: number;
    offset: number;
  } | null>(null);
  // Touch has no hover; without this the panel stays at 30% opacity while sliding.
  const [touchActive, setTouchActive] = useState(false);

  const range = Math.max(0, max - min);
  const filledPercent = range === 0 ? 0 : ((value - min) / range) * 100;

  const updateHoverFromPointer = useCallback(
    (clientX: number) => {
      const track = trackRef.current;
      if (!track) return;
      const rect = track.getBoundingClientRect();
      if (rect.width === 0) return;
      let ratio = (clientX - rect.left) / rect.width;
      ratio = Math.min(1, Math.max(0, ratio));
      if (direction === "rtl") ratio = 1 - ratio;
      const raw = min + ratio * range;
      const snapped = Math.round(raw / step) * step;
      const clamped = Math.min(max, Math.max(min, snapped));
      const offset = Math.min(rect.width, Math.max(0, clientX - rect.left));
      setHoverState({ value: clamped, clientX, offset });
    },
    [direction, min, max, range, step],
  );

  const handlePointerMove = (e: ReactPointerEvent<HTMLElement>) => {
    updateHoverFromPointer(e.clientX);
  };

  const handlePointerLeave = (e: ReactPointerEvent<HTMLElement>) => {
    if (e.pointerType === "touch") return;
    if (draggingRef.current) return;
    setHoverState(null);
  };

  const handleChange = (e: ChangeEvent<HTMLInputElement>) => {
    const next = Number(e.target.value);
    if (Number.isNaN(next)) return;
    onSeek(next);
  };

  const handlePointerDown = (e: ReactPointerEvent<HTMLInputElement>) => {
    draggingRef.current = true;
    if (e.pointerType === "touch") setTouchActive(true);
    updateHoverFromPointer(e.clientX);
  };

  const handlePointerUp = (e: ReactPointerEvent<HTMLInputElement>) => {
    draggingRef.current = false;
    onCommit?.(value);
    if (e.pointerType === "touch") {
      setHoverState(null);
      setTouchActive(false);
    }
  };

  const handlePointerCancel = () => {
    draggingRef.current = false;
    setHoverState(null);
    setTouchActive(false);
  };

  const previewStyle = hoverState
    ? ({ left: `${hoverState.offset}px` } as const)
    : undefined;

  return (
    <div className="group pointer-events-none absolute inset-x-0 bottom-0 z-20 flex flex-col items-stretch">
      <div className="pointer-events-auto h-12" aria-hidden />

      <div
        className={cn(
          "pointer-events-auto bg-gradient-to-t from-black/80 via-black/60 to-transparent px-4 pb-3 pt-6 transition-opacity duration-150",
          touchActive
            ? "opacity-100"
            : "opacity-30 group-hover:opacity-100 focus-within:opacity-100",
        )}
      >
        <div className="relative">
          {hoverState ? (
            <div
              role="presentation"
              className="pointer-events-none absolute bottom-full mb-3 -translate-x-1/2 select-none"
              style={previewStyle}
            >
              {renderPreview(hoverState.value)}
            </div>
          ) : null}

          <div
            ref={trackRef}
            className="relative h-2 w-full overflow-hidden rounded-full bg-white/15"
            onPointerMove={handlePointerMove}
            onPointerLeave={handlePointerLeave}
          >
            <div
              className="absolute inset-y-0 bg-white/80"
              style={
                direction === "rtl"
                  ? { right: 0, width: `${filledPercent}%` }
                  : { left: 0, width: `${filledPercent}%` }
              }
            />
            <input
              type="range"
              aria-label={ariaLabel}
              min={min}
              max={max}
              step={step}
              value={value}
              dir={direction}
              onChange={handleChange}
              onPointerDown={handlePointerDown}
              onPointerMove={handlePointerMove}
              onPointerUp={handlePointerUp}
              onPointerCancel={handlePointerCancel}
              // touchAction none: stop the browser treating horizontal touch as scroll.
              style={{ touchAction: "none" }}
              className="absolute inset-0 h-full w-full cursor-pointer appearance-none bg-transparent
                [&::-webkit-slider-thumb]:h-4 [&::-webkit-slider-thumb]:w-4 [&::-webkit-slider-thumb]:appearance-none
                [&::-webkit-slider-thumb]:rounded-full [&::-webkit-slider-thumb]:border [&::-webkit-slider-thumb]:border-white
                [&::-webkit-slider-thumb]:bg-white [&::-webkit-slider-thumb]:shadow-md
                [&::-moz-range-thumb]:h-4 [&::-moz-range-thumb]:w-4 [&::-moz-range-thumb]:rounded-full
                [&::-moz-range-thumb]:border [&::-moz-range-thumb]:border-white [&::-moz-range-thumb]:bg-white"
            />
          </div>

          <div className="mt-2 flex items-center justify-between text-xs tabular-nums text-white/80">
            <span>{formatLabel(value)}</span>
            {hoverState && hoverState.value !== value ? (
              <span className="text-white/60">→ {formatLabel(hoverState.value)}</span>
            ) : null}
          </div>
        </div>
      </div>
    </div>
  );
}
