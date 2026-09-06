import { useEffect, useRef, useState } from "react";
import { useTranslation } from "react-i18next";
import { X } from "lucide-react";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";

interface ReaderThumbnailGridProps {
  bookId: string;
  total: number;
  currentPage: number;
  direction: "ltr" | "rtl";
  onSelect: (page: number) => void;
  onClose: () => void;
}

// Overlay listing every page as a thumbnail. Rendered inside the reader
// container (not a portal) so it stays visible under the Fullscreen API.
export function ReaderThumbnailGrid({
  bookId,
  total,
  currentPage,
  direction,
  onSelect,
  onClose,
}: ReaderThumbnailGridProps) {
  const { t } = useTranslation();
  const scrollRef = useRef<HTMLDivElement | null>(null);
  const currentRef = useRef<HTMLButtonElement | null>(null);

  useEffect(() => {
    currentRef.current?.scrollIntoView({ block: "center" });
    currentRef.current?.focus({ preventScroll: true });
  }, []);

  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      if (e.key === "Escape") {
        e.preventDefault();
        e.stopPropagation();
        onClose();
      }
    };
    window.addEventListener("keydown", handler, true);
    return () => window.removeEventListener("keydown", handler, true);
  }, [onClose]);

  return (
    <div
      role="dialog"
      aria-modal="true"
      aria-label={t("reader.thumbnails.title")}
      data-testid="thumbnail-grid"
      className="absolute inset-0 z-30 flex flex-col bg-black text-white"
    >
      <div className="flex items-center gap-2 border-b border-white/10 px-3 py-2">
        <h2 className="min-w-0 flex-1 text-sm font-medium">
          {t("reader.thumbnails.title")}
        </h2>
        <Button
          variant="ghost"
          size="icon"
          aria-label={t("reader.thumbnails.close")}
          onClick={onClose}
          className="text-white hover:bg-white/10 hover:text-white"
        >
          <X className="size-5" />
        </Button>
      </div>
      <div
        ref={scrollRef}
        dir={direction}
        className="grid flex-1 auto-rows-max grid-cols-[repeat(auto-fill,minmax(7rem,1fr))] gap-3 overflow-y-auto p-3 sm:grid-cols-[repeat(auto-fill,minmax(9rem,1fr))]"
      >
        {Array.from({ length: total }, (_, p) => (
          <ThumbnailCell
            key={p}
            ref={p === currentPage ? currentRef : undefined}
            src={`/api/books/${bookId}/pages/${p}`}
            label={t("reader.pager.status", { page: p + 1, pages: total })}
            pageNumber={p + 1}
            current={p === currentPage}
            scrollRoot={scrollRef}
            onClick={() => onSelect(p)}
          />
        ))}
      </div>
    </div>
  );
}

interface ThumbnailCellProps {
  ref?: React.Ref<HTMLButtonElement>;
  src: string;
  label: string;
  pageNumber: number;
  current: boolean;
  scrollRoot: React.RefObject<HTMLDivElement | null>;
  onClick: () => void;
}

// The image src is only assigned once the cell nears the viewport, so
// scrolling past pages never fetches them. Once loaded it stays loaded.
function ThumbnailCell({
  ref,
  src,
  label,
  pageNumber,
  current,
  scrollRoot,
  onClick,
}: ThumbnailCellProps) {
  const cellRef = useRef<HTMLDivElement | null>(null);
  const [visible, setVisible] = useState(false);
  const [loaded, setLoaded] = useState(false);

  useEffect(() => {
    const el = cellRef.current;
    if (!el || visible) return;
    const observer = new IntersectionObserver(
      (entries) => {
        if (entries.some((entry) => entry.isIntersecting)) setVisible(true);
      },
      { root: scrollRoot.current, rootMargin: "200px 0px" },
    );
    observer.observe(el);
    return () => observer.disconnect();
  }, [visible, scrollRoot]);

  return (
    <button
      ref={ref}
      type="button"
      aria-label={label}
      aria-current={current ? "page" : undefined}
      onClick={onClick}
      className={cn(
        "group flex flex-col items-center gap-1 rounded-md p-1 focus:outline-none focus-visible:ring-2 focus-visible:ring-white",
        current ? "bg-white/20" : "hover:bg-white/10",
      )}
    >
      <div
        ref={cellRef}
        className={cn(
          "flex aspect-[3/4] w-full items-center justify-center overflow-hidden rounded bg-white/5",
          !loaded && "animate-pulse",
        )}
      >
        {visible ? (
          <img
            src={src}
            alt=""
            decoding="async"
            fetchPriority="low"
            onLoad={() => setLoaded(true)}
            onError={() => setLoaded(true)}
            className={cn(
              "max-h-full max-w-full object-contain transition-opacity",
              loaded ? "opacity-100" : "opacity-0",
            )}
          />
        ) : null}
      </div>
      <span
        className={cn(
          "text-xs tabular-nums",
          current ? "text-white" : "text-white/70",
        )}
      >
        {pageNumber}
      </span>
    </button>
  );
}
